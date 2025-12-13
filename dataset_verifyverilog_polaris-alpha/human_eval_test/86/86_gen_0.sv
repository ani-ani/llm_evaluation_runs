module string_sorter(
  input  logic              clk,
  input  logic              rst_n,       // active-low synchronous reset
  input  logic              start,
  input  logic [63:0][7:0]  char_in,
  output logic [63:0][7:0]  char_out,
  output logic              done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    READ  = 3'd1,
    SORT  = 3'd2,
    WRITE = 3'd3,
    DONE  = 3'd4
  } state_t;

  state_t state, next_state;

  // Registers
  logic [5:0] in_idx;        // 0..63 input index
  logic [5:0] out_idx;       // 0..63 output index
  logic [2:0] word_len;      // 0..8 number of valid chars collected
  logic [2:0] sort_i;        // outer loop index (0..7)
  logic [2:0] sort_j;        // inner loop index (0..6)

  // Word buffer: max 8 chars
  logic [7:0] word_reg   [7:0];

  // Latched start to avoid glitches
  logic start_d;

  // Synchronous state and control registers
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state    <= IDLE;
      in_idx   <= 6'd0;
      out_idx  <= 6'd0;
      word_len <= 3'd0;
      sort_i   <= 3'd0;
      sort_j   <= 3'd0;
      done     <= 1'b0;
      start_d  <= 1'b0;
      char_out <= '{default:8'd0};
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          if (start && !start_d) begin
            in_idx   <= 6'd0;
            out_idx  <= 6'd0;
            word_len <= 3'd0;
            sort_i   <= 3'd0;
            sort_j   <= 3'd0;
          end
        end

        READ: begin
          if (in_idx < 6'd64) begin
            if (char_in[in_idx] == 8'h20) begin
              // Space encountered: if there is a pending word, go sort it;
              // otherwise, directly write space.
              if (word_len != 3'd0) begin
                // Prepare for sort
                sort_i <= 3'd0;
                sort_j <= 3'd0;
              end else begin
                // No pending word, output space directly
                char_out[out_idx] <= 8'h20;
                out_idx           <= out_idx + 6'd1;
              end
            end
          end
        end

        SORT: begin
          // Bubble sort over word_reg[0:word_len-1]
          // Only sort if word_len > 1
          if (word_len > 3'd1) begin
            // Perform one compare-swap per cycle for indices (sort_j, sort_j+1)
            if (sort_j < (word_len - 1)) begin
              if (word_reg[sort_j] > word_reg[sort_j + 1]) begin
                logic [7:0] tmp;
                tmp                  = word_reg[sort_j];
                word_reg[sort_j]     = word_reg[sort_j + 1];
                word_reg[sort_j + 1] = tmp;
              end
              sort_j <= sort_j + 3'd1;
            end else begin
              sort_j <= 3'd0;
              sort_i <= sort_i + 3'd1;
            end
          end else begin
            // word_len 0 or 1: no sort passes required
            sort_i <= word_len; // force exit condition
          end
        end

        WRITE: begin
          // Write out current sorted word or single char if length 1
          if (word_len != 3'd0) begin
            // write all characters of word_reg into output
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
              if (k < word_len) begin
                char_out[out_idx + k[5:0]] <= word_reg[k];
              end
            end
            out_idx  <= out_idx + word_len;
            word_len <= 3'd0;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state and combinational control for reading / buffering
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start && !start_d) begin
          next_state = READ;
        end
      end

      READ: begin
        if (in_idx < 6'd64) begin
          if (char_in[in_idx] == 8'h20) begin
            if (word_len != 3'd0) begin
              // We have a word accumulated, go to SORT
              next_state = SORT;
            end else begin
              // Directly emit the space in sequential block, advance in_idx here
              next_state = READ;
            end
          end else begin
            // Non-space: buffer character if space available
            next_state = READ;
          end
        end else begin
          // End of input
          if (word_len != 3'd0) begin
            next_state = SORT;
          end else begin
            next_state = DONE;
          end
        end
      end

      SORT: begin
        // Continue bubble sort until passes complete
        if ( (word_len <= 3'd1) || (sort_i >= (word_len - 1)) ) begin
          next_state = WRITE;
        end else begin
          next_state = SORT;
        end
      end

      WRITE: begin
        // After writing word, resume READ or transition to DONE
        if (in_idx < 6'd64) begin
          next_state = READ;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Manage input index and word buffering (sequential, aligned with READ state)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      in_idx   <= 6'd0;
      word_len <= 3'd0;
    end else begin
      if (state == READ) begin
        if (in_idx < 6'd64) begin
          if (char_in[in_idx] == 8'h20) begin
            // Space encountered
            if (word_len == 3'd0) begin
              // No pending word; space handled in main seq block
              in_idx <= in_idx + 6'd1;
            end else begin
              // Have word; do not advance in_idx here; SORT will follow
              // (space will be reconsidered after word written)
            end
          end else begin
            // Non-space: collect into word_reg if space available
            if (word_len < 3'd8) begin
              word_reg[word_len] <= char_in[in_idx];
              word_len           <= word_len + 3'd1;
            end
            // Words longer than 8 chars are truncated: still advance in_idx
            in_idx <= in_idx + 6'd1;
          end
        end
      end
      else if (state == WRITE && next_state == READ) begin
        // After finishing a word, if we stopped on a space, now step past it
        if (in_idx < 6'd64 && char_in[in_idx] == 8'h20) begin
          // Output space at current out_idx in main seq (IDLE/READ) path.
          // To maintain position, write space here and advance.
          char_out[out_idx] <= 8'h20;
          out_idx           <= out_idx + 6'd1;
          in_idx            <= in_idx + 6'd1;
        end
      end
    end
  end

endmodule