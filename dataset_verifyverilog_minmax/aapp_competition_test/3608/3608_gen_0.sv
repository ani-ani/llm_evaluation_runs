module task_selector (
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] a,
  input [6:0][31:0] b,
  output reg [31:0] result,
  output reg done
);

  // Modulus (1e9+7)
  localparam MOD = 32'h3B9ACA07; // 1_000_000_007 decimal

  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Control and datapath registers
  reg [3:0] step;         // 0..7
  reg [3:0] reset_cnt;    // 0..2 (reset latency = 2 cycles)
  logic [31:0] dp_prev2;  // dp[i-2]
  logic [31:0] dp_prev1;  // dp[i-1]
  logic [31:0] dp_curr;   // dp[i]

  // Compute next state and datapath (sequential)
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      step <= 4'd0;
      reset_cnt <= 4'd0;
      dp_prev2 <= 32'd0;
      dp_prev1 <= 32'd0;
      result <= 32'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          // Allow 2-cycle reset latency before starting
          if (reset_cnt < 4'd2) begin
            reset_cnt <= reset_cnt + 1;
          end else if (start) begin
            // Initialize recurrence
            reset_cnt <= 4'd0;
            step <= 4'd0;
            dp_prev2 <= 32'd1; // dp[0]
            dp_prev1 <= 32'd0; // dp[1] placeholder, updated on first step
          end
        end

        PROCESSING: begin
          // One step per cycle, exactly 8 steps for i = 0..7
          step <= step + 1;
          if (step == 4'd0) begin
            // dp[0] = 1
            dp_curr <= 32'd1;
            dp_prev1 <= 32'd1;
          end else if (step == 4'd1) begin
            // dp[1] = a[0] * dp[0] (mod MOD)
            dp_curr <= (a[0] * dp_prev2) % MOD;
            dp_prev2 <= dp_prev1; // now dp_prev2 = dp[0]
            dp_prev1 <= dp_curr;  // now dp_prev1 = dp[1]
          end else begin
            // i >= 2: dp[i] = dp[i-1] * a[i-1] + dp[i-2] * b[i-2] (mod MOD)
            // a index: i-1 is in [0..6] for i in [2..7]
            // b index: i-2 is in [0..5] for i in [2..7]; b[6] is unused
            dp_curr <= ((dp_prev1 * a[step - 1]) + (dp_prev2 * b[step - 2])) % MOD;
            dp_prev2 <= dp_prev1; // shift window
            dp_prev1 <= dp_curr;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Should never happen, but avoid latches
          state <= IDLE;
          done <= 1'b0;
          step <= 4'd0;
          reset_cnt <= 4'd0;
          dp_prev2 <= 32'd0;
          dp_prev1 <= 32'd0;
          result <= 32'd0;
        end
      endcase

      // Latch result in DONE state (after last step)
      if (next_state == DONE) begin
        result <= dp_curr;
      end
    end
  end

  // Next-state logic (combinational)
  always @(*) begin
    case (state)
      IDLE: begin
        if (!rst_n) next_state = IDLE;
        else if (reset_cnt < 4'd2) next_state = IDLE;
        else if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (!rst_n) next_state = IDLE;
        else if (step == 4'd7) next_state = DONE; // after dp[7]
        else next_state = PROCESSING;
      end
      DONE: begin
        if (!rst_n) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule
