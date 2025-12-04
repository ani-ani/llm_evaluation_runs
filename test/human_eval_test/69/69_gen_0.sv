module frequency_max (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] data [0:7],
  output reg [4:0] result,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    COUNT   = 2'b01,
    COMPARE = 2'b10,
    DONE    = 2'b11
  } state_t;

  state_t state, next_state;

  // Counters for values 1..15
  reg [3:0] freq [1:15];

  // Index for counting input array
  reg [3:0] idx;

  // Current value being compared (1..15)
  reg [4:0] cur_val;

  integer i;

  // Sequential state and data updates
  always @(posedge clk) begin
    if (!rst_n) begin
      state  <= IDLE;
      result <= 5'd0;
      done   <= 1'b0;
      idx    <= 4'd0;
      cur_val <= 5'd0;
      // Clear frequency counters
      for (i = 1; i <= 15; i = i + 1) begin
        freq[i] <= 4'd0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          result <= 5'd0;
          done   <= 1'b0;
          if (start) begin
            // Initialize for COUNT
            idx <= 4'd0;
            for (i = 1; i <= 15; i = i + 1) begin
              freq[i] <= 4'd0;
            end
          end
        end

        COUNT: begin
          done <= 1'b0;
          // Count current data[idx] if non-zero and valid 1..15
          if (data[idx] != 4'd0) begin
            freq[data[idx]] <= freq[data[idx]] + 4'd1;
          end
          // Move to next index
          idx <= idx + 4'd1;
        end

        COMPARE: begin
          done <= 1'b0;
          // Comparison happens combinationally via next_state logic;
          // result may be updated below in this state when condition met.
          if (cur_val >= 5'd1 && cur_val <= 5'd15) begin
            if (freq[cur_val[3:0]] >= cur_val[3:0]) begin
              result <= cur_val;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold result until next start or reset
        end

        default: begin
          // Safety default
          result <= 5'd0;
          done   <= 1'b0;
        end
      endcase
    end
  end

  // Next state and control for cur_val
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COUNT;
        end
      end

      COUNT: begin
        // After processing all 8 entries (idx 0..7), move to COMPARE
        if (idx == 4'd8) begin
          next_state = COMPARE;
        end
      end

      COMPARE: begin
        // cur_val is driven sequentially below; here we decide when done
        // If we've checked down to 1 and still no match, go to DONE (with -1)
        if (cur_val == 5'd0) begin
          next_state = DONE;
        end else begin
          // If a match found (freq >= cur_val), go to DONE immediately
          if (cur_val >= 5'd1 && cur_val <= 5'd15 && freq[cur_val[3:0]] >= cur_val[3:0]) begin
            next_state = DONE;
          end else begin
            // Continue comparing next lower value
            next_state = COMPARE;
          end
        end
      end

      DONE: begin
        // Wait for next start (from IDLE after start pulse) or reset externally
        if (start) begin
          next_state = COUNT; // Allow immediate restart if desired
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // cur_val update: walk down from 15 to 0 during COMPARE phase
  always @(posedge clk) begin
    if (!rst_n) begin
      cur_val <= 5'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            cur_val <= 5'd15;
          end else begin
            cur_val <= 5'd0;
          end
        end

        COUNT: begin
          // Prepare for COMPARE when counting is done
          if (idx == 4'd8) begin
            cur_val <= 5'd15;
          end
        end

        COMPARE: begin
          // If match found, hold cur_val; transition to DONE handled by FSM
          if (!(cur_val >= 5'd1 && cur_val <= 5'd15 && freq[cur_val[3:0]] >= cur_val[3:0])) begin
            // No match at this cur_val, decrement for next check
            if (cur_val > 5'd0)
              cur_val <= cur_val - 5'd1;
          end
        end

        DONE: begin
          // If no value satisfied condition, output -1
          // Detect case when COMPARE ended with cur_val==0 and no match
          if (result == 5'd0) begin
            result <= 5'b11111; // -1
          end
          // Optionally reset cur_val for next operation
          if (start) begin
            cur_val <= 5'd15;
          end
        end

        default: begin
          cur_val <= 5'd0;
        end
      endcase
    end
  end

endmodule