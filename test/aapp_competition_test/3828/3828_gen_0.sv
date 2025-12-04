module train_sorter(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] n,
  input  [4:0] car_numbers [0:15],
  output reg [4:0] min_moves,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    LOAD_POS  = 2'b01,
    SCAN_SEQ  = 2'b10,
    DONE      = 2'b11
  } state_t;

  state_t state, next_state;

  // Position array: pos[value] = index
  reg [3:0] pos [0:31];

  // Counters and temporaries
  reg [4:0] load_idx;       // up to 31
  reg [4:0] scan_idx;       // up to 31
  reg [4:0] max_val;        // maximum car value observed (<=31)
  reg [4:0] longest_len;
  reg [4:0] curr_len;
  reg [3:0] i_idx;

  // Previous position for scan
  reg [3:0] prev_pos;
  reg       prev_pos_valid;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD_POS;
      end
      LOAD_POS: begin
        // After initializing pos[0:31] and loading all n entries
        if (load_idx == (5'd31)) begin
          next_state = SCAN_SEQ;
        end
      end
      SCAN_SEQ: begin
        // After scanning all values up to max_val
        if (scan_idx >= max_val)
          next_state = DONE;
      end
      DONE: begin
        // Stay done until next start pulse
        if (start)
          next_state = LOAD_POS;
        else if (!start)
          next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Control of load and scan indices and logic
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done         <= 1'b0;
      min_moves    <= 5'd0;
      load_idx     <= 5'd0;
      scan_idx     <= 5'd0;
      max_val      <= 5'd0;
      longest_len  <= 5'd0;
      curr_len     <= 5'd0;
      prev_pos     <= 4'd0;
      prev_pos_valid <= 1'b0;
      i_idx        <= 4'd0;
      for (k = 0; k < 32; k = k + 1) begin
        pos[k] <= 4'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done         <= 1'b0;
          min_moves    <= 5'd0;
          load_idx     <= 5'd0;
          scan_idx     <= 5'd0;
          max_val      <= 5'd0;
          longest_len  <= 5'd0;
          curr_len     <= 5'd0;
          prev_pos     <= 4'd0;
          prev_pos_valid <= 1'b0;
          i_idx        <= 4'd0;
        end

        LOAD_POS: begin
          done <= 1'b0;
          // Step 1: initialize pos array over several cycles
          if (load_idx < 5'd32) begin
            pos[load_idx] <= 4'd15; // default to large index as 'not seen'
          end

          // After initialization starts, also load car_numbers when in range
          if (load_idx < {1'b0, n}) begin
            // car index = load_idx
            // car value
            if (car_numbers[load_idx] <= 5'd31) begin
              pos[car_numbers[load_idx]] <= load_idx[3:0];
              if (car_numbers[load_idx] > max_val)
                max_val <= car_numbers[load_idx];
            end
          end

          if (load_idx < 5'd31)
            load_idx <= load_idx + 5'd1;
          else begin
            // prepare for SCAN_SEQ
            scan_idx        <= 5'd0;
            longest_len     <= 5'd0;
            curr_len        <= 5'd0;
            prev_pos_valid  <= 1'b0;
          end
        end

        SCAN_SEQ: begin
          done <= 1'b0;

          if (!prev_pos_valid) begin
            // Initialize with first existing value
            // Find first value (scan_idx) that was used
            if (scan_idx <= max_val) begin
              prev_pos        <= pos[scan_idx];
              prev_pos_valid  <= 1'b1;
              curr_len        <= 5'd1;
              longest_len     <= (5'd1 > longest_len) ? 5'd1 : longest_len;
              scan_idx        <= scan_idx + 5'd1;
            end else begin
              // No valid elements
              prev_pos_valid <= 1'b0;
            end
          end else if (scan_idx <= max_val) begin
            // Check consecutive value
            if (pos[scan_idx] > prev_pos) begin
              curr_len <= curr_len + 5'd1;
            end else begin
              curr_len <= 5'd1;
            end
            prev_pos   <= pos[scan_idx];
            if (curr_len > longest_len)
              longest_len <= curr_len;
            scan_idx <= scan_idx + 5'd1;
          end
        end

        DONE: begin
          // Compute min_moves once when entering DONE
          done <= 1'b1;
          // Protect against n < longest_len, though shouldn't happen
          if (longest_len > {1'b0, n})
            min_moves <= 5'd0;
          else
            min_moves <= {1'b0, n} - longest_len;

          // If a new start pulse occurs, reinitialize for next computation
          if (start) begin
            done         <= 1'b0;
            min_moves    <= 5'd0;
            load_idx     <= 5'd0;
            scan_idx     <= 5'd0;
            max_val      <= 5'd0;
            longest_len  <= 5'd0;
            curr_len     <= 5'd0;
            prev_pos     <= 4'd0;
            prev_pos_valid <= 1'b0;
            i_idx        <= 4'd0;
            // pos[] will be re-initialized in LOAD_POS
          end
        end

        default: begin
          // Should not occur
          done      <= 1'b0;
          min_moves <= 5'd0;
        end
      endcase
    end
  end

endmodule