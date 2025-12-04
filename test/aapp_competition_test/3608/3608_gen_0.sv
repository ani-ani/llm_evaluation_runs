module task_selector(
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] a,
  input [6:0][31:0] b,
  output reg [31:0] result,
  output reg done
);

  // Parameters
  localparam MOD       = 32'd1000000007;
  localparam STATE_IDLE  = 2'd0;
  localparam STATE_PROC  = 2'd1;
  localparam STATE_DONE  = 2'd2;

  reg [1:0] state, next_state;
  reg [3:0] i;               // step index 0..8
  reg [31:0] dp_prev2;       // dp[i-2]
  reg [31:0] dp_prev1;       // dp[i-1]
  reg [31:0] dp_curr;        // current dp value

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        if (start)
          next_state = STATE_PROC;
      end
      STATE_PROC: begin
        if (i == 4'd8)
          next_state = STATE_DONE;
      end
      STATE_DONE: begin
        if (!start)
          next_state = STATE_IDLE;
      end
      default: next_state = STATE_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= STATE_IDLE;
      i        <= 4'd0;
      dp_prev2 <= 32'd0;
      dp_prev1 <= 32'd0;
      dp_curr  <= 32'd0;
      result   <= 32'd0;
      done     <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        STATE_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for computation
            // Cycle 0: prepare dp[0] and dp[1]
            dp_prev2 <= 32'd1; // dp[0]
            dp_prev1 <= (a[0] >= MOD) ? (a[0] - MOD) : a[0];
            i        <= 4'd2;
          end
        end

        STATE_PROC: begin
          done <= 1'b0;
          if (i == 4'd2) begin
            // dp[2] = dp[1]*a[1] + dp[0]*b[0]
            dp_curr <= (((dp_prev1 * a[1]) % MOD) + ((dp_prev2 * b[0]) % MOD)) % MOD;
            dp_prev2 <= dp_prev1;
            dp_prev1 <= (((dp_prev1 * a[1]) % MOD) + ((dp_prev2 * b[0]) % MOD)) % MOD;
            i <= 4'd3;
          end else if (i >= 4'd3 && i <= 4'd7) begin
            // dp[i] = dp[i-1]*a[i-1] + dp[i-2]*b[i-2]
            dp_curr <= (((dp_prev1 * a[i-1]) % MOD) + ((dp_prev2 * b[i-2]) % MOD)) % MOD;
            dp_prev2 <= dp_prev1;
            dp_prev1 <= (((dp_prev1 * a[i-1]) % MOD) + ((dp_prev2 * b[i-2]) % MOD)) % MOD;
            i <= i + 1'b1;
          end else if (i == 4'd8) begin
            // Completed dp[8] in previous cycle; move to DONE via next_state
            result <= dp_prev1;
          end else begin
            // i == 4'd7 to compute dp[8]
            if (i == 4'd7) begin
              dp_curr <= (((dp_prev1 * a[7]) % MOD) + ((dp_prev2 * b[6]) % MOD)) % MOD;
              dp_prev2 <= dp_prev1;
              dp_prev1 <= (((dp_prev1 * a[7]) % MOD) + ((dp_prev2 * b[6]) % MOD)) % MOD;
              i <= 4'd8;
            end
          end
        end

        STATE_DONE: begin
          done <= 1'b1;
          // Hold result until start deasserts and we return to IDLE
          if (!start) begin
            i        <= 4'd0;
            dp_prev2 <= 32'd0;
            dp_prev1 <= 32'd0;
            dp_curr  <= 32'd0;
          end
        end

        default: begin
          state <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule