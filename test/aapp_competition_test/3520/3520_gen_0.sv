module pill_scheduler(
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  input [31:0] c,
  input [31:0] pill1_t,
  input [31:0] pill1_x,
  input [31:0] pill1_y,
  input [31:0] pill2_t,
  input [31:0] pill2_x,
  input [31:0] pill2_y,
  input [31:0] pill3_t,
  input [31:0] pill3_x,
  input [31:0] pill3_y,
  input [31:0] pill4_t,
  input [31:0] pill4_x,
  input [31:0] pill4_y,
  output reg [31:0] max_lifespan,
  output reg done
);

  // State encoding
  localparam IDLE        = 2'd0;
  localparam CALC_DELAYS = 2'd1;
  localparam EVAL_PATHS  = 2'd2;
  localparam DONE        = 2'd3;

  reg [1:0] state, next_state;

  // cycle counter to ensure output valid 16 cycles after start
  reg [4:0] cycle_cnt; // enough for 0-31

  // Precomputed adjusted benefits for each pill
  reg [31:0] p1_val;
  reg [31:0] p2_val;
  reg [31:0] p3_val;
  reg [31:0] p4_val;

  // DP arrays for up to 4 pills
  // dp[k] = best achievable lifespan after considering first i pills and taking k pills
  reg [31:0] dp0, dp1, dp2, dp3, dp4;
  reg [31:0] new_dp1, new_dp2, new_dp3, new_dp4;

  // iteration index over pills
  reg [2:0] pill_idx; // 0..4

  // internal signals
  wire [31:0] base_life;
  assign base_life = n; // already Q16.16

  // max helper (combinational)
  function [31:0] max2;
    input [31:0] a, b;
    begin
      max2 = (a >= b) ? a : b;
    end
  endfunction

  // Synchronous state, counters, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      cycle_cnt     <= 5'd0;
      done          <= 1'b0;
      max_lifespan  <= 32'd0;
      p1_val        <= 32'd0;
      p2_val        <= 32'd0;
      p3_val        <= 32'd0;
      p4_val        <= 32'd0;
      dp0           <= 32'd0;
      dp1           <= 32'd0;
      dp2           <= 32'd0;
      dp3           <= 32'd0;
      dp4           <= 32'd0;
      new_dp1       <= 32'd0;
      new_dp2       <= 32'd0;
      new_dp3       <= 32'd0;
      new_dp4       <= 32'd0;
      pill_idx      <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 5'd0;
          if (start) begin
            // initialize DP base (no pills)
            dp0      <= base_life;
            dp1      <= 32'd0;
            dp2      <= 32'd0;
            dp3      <= 32'd0;
            dp4      <= 32'd0;
            pill_idx <= 3'd0;
          end
        end

        CALC_DELAYS: begin
          // Compute adjusted pill values once after start
          // Model: effective gain = pill_x - pill_y - c
          // This is a simple linear model for path benefit with switching penalty
          if (cycle_cnt == 5'd0) begin
            p1_val <= pill1_x - pill1_y - c;
            p2_val <= pill2_x - pill2_y - c;
            p3_val <= pill3_x - pill3_y - c;
            p4_val <= pill4_x - pill4_y - c;
          end
          cycle_cnt <= cycle_cnt + 5'd1;
        end

        EVAL_PATHS: begin
          // Sequential DP over pills, one pill processed per cycle
          cycle_cnt <= cycle_cnt + 5'd1;

          case (pill_idx)
            3'd0: begin
              // process pill1
              // dp0 unchanged
              new_dp1 <= max2(dp1, dp0 + p1_val);
              new_dp2 <= dp2;
              new_dp3 <= dp3;
              new_dp4 <= dp4;
              pill_idx <= 3'd1;
            end

            3'd1: begin
              // commit previous updates
              dp1 <= new_dp1;
              dp2 <= new_dp2;
              dp3 <= new_dp3;
              dp4 <= new_dp4;
              // process pill2
              new_dp1 <= max2(dp1, dp0 + p2_val);
              new_dp2 <= max2(dp2, dp1 + p2_val);
              new_dp3 <= dp3;
              new_dp4 <= dp4;
              pill_idx <= 3'd2;
            end

            3'd2: begin
              // commit
              dp1 <= new_dp1;
              dp2 <= new_dp2;
              dp3 <= new_dp3;
              dp4 <= new_dp4;
              // process pill3
              new_dp1 <= max2(dp1, dp0 + p3_val);
              new_dp2 <= max2(dp2, dp1 + p3_val);
              new_dp3 <= max2(dp3, dp2 + p3_val);
              new_dp4 <= dp4;
              pill_idx <= 3'd3;
            end

            3'd3: begin
              // commit
              dp1 <= new_dp1;
              dp2 <= new_dp2;
              dp3 <= new_dp3;
              dp4 <= new_dp4;
              // process pill4
              new_dp1 <= max2(dp1, dp0 + p4_val);
              new_dp2 <= max2(dp2, dp1 + p4_val);
              new_dp3 <= max2(dp3, dp2 + p4_val);
              new_dp4 <= max2(dp4, dp3 + p4_val);
              pill_idx <= 3'd4;
            end

            3'd4: begin
              // final commit
              dp1 <= new_dp1;
              dp2 <= new_dp2;
              dp3 <= new_dp3;
              dp4 <= new_dp4;
              pill_idx <= 3'd5;
            end

            default: begin
              // hold
              pill_idx <= pill_idx;
            end
          endcase
        end

        DONE: begin
          done <= 1'b1;
          // hold outputs until next start
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic and final max_lifespan computation
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_DELAYS;
      end

      CALC_DELAYS: begin
        // Move to EVAL_PATHS after a few cycles; we ensure total latency is 16
        // Here, after 3 cycles of CALC_DELAYS, go to EVAL_PATHS
        if (cycle_cnt >= 5'd3)
          next_state = EVAL_PATHS;
      end

      EVAL_PATHS: begin
        // After processing all pills, move to DONE such that total = 16 cycles
        // We rely on pill_idx reaching 5 (all processed)
        if (pill_idx >= 3'd5 && cycle_cnt >= 5'd15) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait for next start; deassert done in IDLE when new start
        if (start)
          next_state = CALC_DELAYS;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Final maximum lifespan selection (synchronous update when entering DONE)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_lifespan <= 32'd0;
    end else begin
      if (state == EVAL_PATHS && next_state == DONE) begin
        // Choose best among using 0..4 pills
        // Ensure we never go below base_life
        reg [31:0] best;
        best = dp0;
        if (dp1 > best) best = dp1;
        if (dp2 > best) best = dp2;
        if (dp3 > best) best = dp3;
        if (dp4 > best) best = dp4;
        max_lifespan <= best;
      end
    end
  end

endmodule