module adverb_finder(
  input  clk,
  input  rst_n,
  input  start,
  input  [511:0] text,
  output reg [5:0]  start_pos,
  output reg [5:0]  end_pos,
  output reg [31:0] found_word,
  output reg        valid,
  output reg        done
);

  // State encoding
  localparam IDLE   = 2'd0;
  localparam SCAN   = 2'd1;
  localparam OUTPUT = 2'd2;

  reg [1:0] state, next_state;
  reg [5:0] idx;               // 0..63 character index

  // Current/previous characters
  reg [7:0] curr_char;
  reg [7:0] prev_char;

  // Word tracking
  reg [5:0] word_start;
  reg       have_word_start;

  // Track potential 'ly' end
  reg [5:0] ly_pos;            // index of 'y' in "ly"
  reg       ly_pending;        // indicates last two letters were 'l','y' at end of word so far

  // First found result latching
  reg       found;
  reg [5:0] found_start_pos;
  reg [5:0] found_end_pos;

  // Combinational helpers
  wire [7:0] t_char = text[511 - idx*8 -: 8];

  function automatic bit is_letter(input [7:0] c);
    begin
      is_letter = ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z"));
    end
  endfunction

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SCAN;
      end
      SCAN: begin
        if (idx == 6'd63) begin
          // After processing last character, move to OUTPUT next cycle
          next_state = OUTPUT;
        end
      end
      OUTPUT: begin
        // Wait for next start to restart
        if (start)
          next_state = SCAN;
        else if (!start)
          next_state = OUTPUT;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      idx             <= 6'd0;
      curr_char       <= 8'd0;
      prev_char       <= 8'd0;
      word_start      <= 6'd0;
      have_word_start <= 1'b0;
      ly_pos          <= 6'd0;
      ly_pending      <= 1'b0;
      found           <= 1'b0;
      found_start_pos <= 6'd0;
      found_end_pos   <= 6'd0;
      start_pos       <= 6'd0;
      end_pos         <= 6'd0;
      found_word      <= 32'd0;
      valid           <= 1'b0;
      done            <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done            <= 1'b0;
          valid           <= 1'b0;
          idx             <= 6'd0;
          curr_char       <= 8'd0;
          prev_char       <= 8'd0;
          word_start      <= 6'd0;
          have_word_start <= 1'b0;
          ly_pos          <= 6'd0;
          ly_pending      <= 1'b0;
          found           <= 1'b0;
          found_start_pos <= 6'd0;
          found_end_pos   <= 6'd0;
          if (start) begin
            // Prepare for scanning
            idx <= 6'd0;
          end
        end

        SCAN: begin
          done  <= 1'b0;
          valid <= 1'b0;

          // Load current character from text
          curr_char <= t_char;

          // Detect letter / non-letter
          if (is_letter(t_char)) begin
            // If starting a new word
            if (!have_word_start) begin
              word_start      <= idx;
              have_word_start <= 1'b1;
            end

            // Sliding window for 'ly'
            if (prev_char == "l" && t_char == "y") begin
              ly_pos     <= idx;       // position of 'y'
              ly_pending <= 1'b1;      // possible 'ly' at end of word (pending confirmation)
            end else begin
              // Any other continuation resets pending 'ly'
              ly_pending <= 1'b0;
            end

          end else begin
            // Non-letter: possible word boundary
            if (have_word_start && ly_pending && !found) begin
              // Confirm word ending with 'ly' at boundary
              found           <= 1'b1;
              found_start_pos <= word_start;
              found_end_pos   <= ly_pos + 6'd1; // end_pos is index+1
            end
            // Reset word tracking on non-letter
            have_word_start <= 1'b0;
            ly_pending      <= 1'b0;
          end

          // Update prev_char for next cycle
          prev_char <= t_char;

          // Increment index or move to OUTPUT next_state handles state
          if (idx != 6'd63) begin
            idx <= idx + 6'd1;
          end else begin
            idx <= idx; // hold; OUTPUT will be next

            // At end of text, also consider word end at text boundary
            if (have_word_start && ly_pending && !found) begin
              found           <= 1'b1;
              found_start_pos <= word_start;
              found_end_pos   <= ly_pos + 6'd1;
            end
          end
        end

        OUTPUT: begin
          // Single-cycle result presentation; remain until new start
          done <= 1'b1;

          if (found) begin
            valid     <= 1'b1;
            start_pos <= found_start_pos;
            end_pos   <= found_end_pos;

            // Build found_word (up to 4 chars) from text using found_start_pos
            // Characters beyond end or 4 chars are ignored; unused bytes are zeroed.
            found_word <= 32'd0;
            for (k = 0; k < 4; k = k + 1) begin
              if ((found_start_pos + k) < found_end_pos && (found_start_pos + k) < 6'd64) begin
                found_word[31 - k*8 -: 8] <= text[511 - (found_start_pos + k)*8 -: 8];
              end else begin
                found_word[31 - k*8 -: 8] <= 8'd0;
              end
            end
          end else begin
            valid      <= 1'b0;
            start_pos  <= 6'd0;
            end_pos    <= 6'd0;
            found_word <= 32'd0;
          end

          // If a new start comes, reinitialize for new scan
          if (start) begin
            done            <= 1'b0;
            valid           <= 1'b0;
            idx             <= 6'd0;
            curr_char       <= 8'd0;
            prev_char       <= 8'd0;
            word_start      <= 6'd0;
            have_word_start <= 1'b0;
            ly_pos          <= 6'd0;
            ly_pending      <= 1'b0;
            found           <= 1'b0;
            found_start_pos <= 6'd0;
            found_end_pos   <= 6'd0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule