module consecutive_checker(
  input  logic             clk,
  input  logic             rst_n,
  input  logic             start,
  input  logic signed [7:0][7:0] array_in,
  output logic             consecutive,
  output logic             done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    SORT  = 2'b01,
    CHECK = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal storage for sorting
  logic signed [7:0] data [7:0];

  // Bubble sort indices and cycle counter
  logic [5:0] cycle_cnt;    // up to 63
  logic [2:0] i_idx;
  logic [2:0] j_idx;

  // Flags for checking
  logic [7:0] max_val;
  logic [7:0] min_val;
  logic       unique_ok;
  logic       consecutive_ok;

  // State register and main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      consecutive  <= 1'b0;
      done         <= 1'b1;
      cycle_cnt    <= 6'd0;
      i_idx        <= 3'd0;
      j_idx        <= 3'd0;
      data[0]      <= '0;
      data[1]      <= '0;
      data[2]      <= '0;
      data[3]      <= '0;
      data[4]      <= '0;
      data[5]      <= '0;
      data[6]      <= '0;
      data[7]      <= '0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b1;
          consecutive <= 1'b0;
          if (start) begin
            // Load input array into internal storage
            data[0]   <= array_in[0];
            data[1]   <= array_in[1];
            data[2]   <= array_in[2];
            data[3]   <= array_in[3];
            data[4]   <= array_in[4];
            data[5]   <= array_in[5];
            data[6]   <= array_in[6];
            data[7]   <= array_in[7];
            done      <= 1'b0;
            cycle_cnt <= 6'd0;
            i_idx     <= 3'd0;
            j_idx     <= 3'd0;
          end
        end

        SORT: begin
          done <= 1'b0;

          // One compare-swap per cycle: bubble sort style
          if (data[j_idx] > data[j_idx+1]) begin
            logic signed [7:0] tmp;
            tmp              = data[j_idx];
            data[j_idx]      = data[j_idx+1];
            data[j_idx+1]    = tmp;
          end

          // Update indices for next compare
          if (j_idx < (7 - i_idx - 1)) begin
            j_idx <= j_idx + 3'd1;
          end else begin
            j_idx <= 3'd0;
            if (i_idx < 3'd7) begin
              i_idx <= i_idx + 3'd1;
            end
          end

          // Count cycles; after 64 cycles go to CHECK
          if (cycle_cnt < 6'd63) begin
            cycle_cnt <= cycle_cnt + 6'd1;
          end
        end

        CHECK: begin
          // Compute min and max from sorted data
          min_val = data[0];
          max_val = data[7];

          // Condition (i): max_value - min_value + 1 == 8
          // Use 9-bit for safe signed subtraction then evaluate in 8-bit range
          logic signed [8:0] range_val;
          range_val = $signed({1'b0, max_val}) - $signed({1'b0, min_val}) + 9'sd1;
          logic range_ok;
          range_ok = (range_val == 9'sd8);

          // Condition (ii) and (iii): uniqueness and consecutive differences
          unique_ok       = 1'b1;
          consecutive_ok  = 1'b1;

          // Check pairwise differences == 1 and no duplicates
          if ((data[1] - data[0]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[2] - data[1]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[3] - data[2]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[4] - data[3]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[5] - data[4]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[6] - data[5]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end
          if ((data[7] - data[6]) != 8'sd1) begin unique_ok = 1'b0; consecutive_ok = 1'b0; end

          consecutive <= (range_ok && unique_ok && consecutive_ok);
          done        <= 1'b0;
        end

        DONE: begin
          done <= 1'b1;
          // Hold 'consecutive' result until next start or reset
        end

        default: begin
          // Safety fallback
          done        <= 1'b1;
          consecutive <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SORT;
      end

      SORT: begin
        // After fixed 64 cycles, move to CHECK
        if (cycle_cnt == 6'd63)
          next_state = CHECK;
      end

      CHECK: begin
        next_state = DONE;
      end

      DONE: begin
        if (start)
          next_state = SORT;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule