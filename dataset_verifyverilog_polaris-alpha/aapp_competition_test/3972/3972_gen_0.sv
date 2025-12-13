module sequence_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0] n, // 1 <= n <= 8
  output reg [29:0] result, // 30-bit output for modulo 10^9+7
  output reg done // High when computation completes
);

  // Parameters
  localparam MODULO = 32'd1000000007;

  // State encoding
  localparam [1:0]
    IDLE    = 2'b00,
    COMPUTE = 2'b01,
    DONE    = 2'b10;

  // Registers
  reg [1:0] state, next_state;
  reg [3:0] n_reg;           // Latched input n
  reg [3:0] iter_cnt;        // Iteration counter
  reg [29:0] dp_prev;        // dp[i-2]
  reg [29:0] dp_curr;        // dp[i-1]
  reg [29:0] dp_next;        // Next dp value (combinational)
  reg [2:0] cycle_cnt;       // For fixed 8-cycle latency control

  // Combinational next dp value calculation
  always @* begin
    // dp_next = (dp_curr * 2 + dp_prev) % MODULO;
    // Since 30-bit result is always < MODULO, we can compute in 32 bits and reduce.
    // Use 32-bit intermediate to avoid overflow.
    reg [31:0] tmp;
    tmp = (dp_curr << 1) + dp_prev;
    if (tmp >= MODULO)
      dp_next = tmp - MODULO;
    else
      dp_next = tmp[29:0];
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      n_reg     <= 4'd0;
      iter_cnt  <= 4'd0;
      dp_prev   <= 30'd0;
      dp_curr   <= 30'd0;
      result    <= 30'd0;
      done      <= 1'b0;
      cycle_cnt <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_reg     <= n;
            // Initialize DP base cases
            dp_prev   <= 30'd1; // dp[1]
            dp_curr   <= 30'd4; // dp[2]
            iter_cnt  <= 4'd3;  // Start from i=3
            cycle_cnt <= 3'd0;
          end
        end

        COMPUTE: begin
          // Always run for 8 cycles total after start, as required.
          cycle_cnt <= cycle_cnt + 3'd1;

          // For n == 1 or n == 2, no recursive steps needed; result selected later.
          // For n >= 3, perform recurrence steps until iter_cnt reaches n.
          if (n_reg >= 4'd3 && iter_cnt <= n_reg) begin
            // Update DP values for current iteration
            dp_prev  <= dp_curr;
            dp_curr  <= dp_next;
            iter_cnt <= iter_cnt + 4'd1;
          end

          // When fixed latency reached (8 cycles after start), latch result
          if (cycle_cnt == 3'd7) begin
            // Select final result based on n_reg
            if (n_reg == 4'd1) begin
              result <= 30'd1; // dp[1]
            end else if (n_reg == 4'd2) begin
              result <= 30'd4; // dp[2]
            end else begin
              // For n >= 3, dp_curr holds dp[n] once iterations are done
              result <= dp_curr;
            end
            done <= 1'b1;
          end
        end

        DONE: begin
          // Hold result and done high until next start
          if (start) begin
            done      <= 1'b0;
            n_reg     <= n;
            dp_prev   <= 30'd1; // dp[1]
            dp_curr   <= 30'd4; // dp[2]
            iter_cnt  <= 4'd3;
            cycle_cnt <= 3'd0;
          end
        end

        default: begin
          // Safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE;
      end

      COMPUTE: begin
        // Transition to DONE state exactly after 8 cycles from start
        // cycle_cnt counts from 0; when it becomes 7, we have completed 8 cycles.
        if (cycle_cnt == 3'd7)
          next_state = DONE;
      end

      DONE: begin
        if (start)
          next_state = COMPUTE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule