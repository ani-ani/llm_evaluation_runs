module min_subarray_sum(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0][15:0] nums,
  output reg [15:0]  min_sum,
  output reg         done
);

  // State encoding for 10-cycle operation
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    INIT  = 2'b01,
    CALC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  reg [3:0]  cycle_cnt;         // counts total cycles within active operation
  reg [2:0]  index;             // index for nums[1]..nums[7]
  reg [15:0] current_min;
  reg [15:0] global_min;

  // Combinational next-state & control
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // After initialization cycle, move to CALC
        next_state = CALC;
      end

      CALC: begin
        // Total latency from start is 10 cycles.
        // We use cycle_cnt to know when to finish.
        // cycle_cnt counts from 0 at start assertion.
        // DONE is reached when cycle_cnt == 4'd9.
        if (cycle_cnt == 4'd9)
          next_state = DONE;
      end

      DONE: begin
        // Stay DONE one cycle, then go to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      cycle_cnt   <= 4'd0;
      index       <= 3'd0;
      current_min <= 16'sd0;
      global_min  <= 16'sd0;
      min_sum     <= 16'sd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 4'd0;
          index     <= 3'd1; // next to process after nums[0]

          if (start) begin
            // Cycle 0: capture first element into current_min and global_min
            current_min <= nums[0];
            global_min  <= nums[0];
            cycle_cnt   <= 4'd0;
          end
        end

        INIT: begin
          // Cycle 1: no change needed other than advancing cycle_cnt
          cycle_cnt <= cycle_cnt + 4'd1; // becomes 1
          // current_min and global_min already set from IDLE/start cycle
        end

        CALC: begin
          // Cycles 2..9: process elements and count cycles
          // Perform Kadane's for minimum subarray
          if (index <= 3'd7) begin
            // signed operations
            reg signed [15:0] a;
            reg signed [15:0] b;
            reg signed [15:0] next_current;
            reg signed [15:0] next_global;

            a = nums[index];
            b = current_min + nums[index];

            // current_min = min(a, b)
            if (a <= b)
              next_current = a;
            else
              next_current = b;

            // global_min = min(global_min, current_min)
            if (global_min <= next_current)
              next_global = global_min;
            else
              next_global = next_current;

            current_min <= next_current;
            global_min  <= next_global;

            index <= index + 3'd1;
          end

          cycle_cnt <= cycle_cnt + 4'd1;
          done      <= 1'b0;
        end

        DONE: begin
          // Finalize outputs at cycle 10 boundary
          min_sum   <= global_min;
          done      <= 1'b1;
          cycle_cnt <= 4'd0;
          index     <= 3'd1;
        end

        default: begin
          // Should not occur; safe reset-like behavior
          state       <= IDLE;
          cycle_cnt   <= 4'd0;
          index       <= 3'd0;
          current_min <= 16'sd0;
          global_min  <= 16'sd0;
          min_sum     <= 16'sd0;
          done        <= 1'b0;
        end
      endcase
    end
  end

endmodule