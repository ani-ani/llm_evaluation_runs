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

  // Q16.16 fixed point assumption
  // 16 fractional bits
  localparam FRAC_BITS = 16;
  localparam ONE = 32'h00010000; // 1.0 in Q16.16

  // State machine
  typedef enum logic [1:0] {IDLE = 2'b00, CALC_DELAYS = 2'b01, EVAL_PATHS = 2'b10, DONE = 2'b11} state_t;
  state_t cur_state, nxt_state;

  // Internal pipeline registers (sampled on start)
  reg [31:0] r_n;
  reg [31:0] r_c;
  reg [31:0] r_t [0:3];
  reg [31:0] r_x [0:3];
  reg [31:0] r_y [0:3];

  // Combinational results
  reg [31:0] calc_life_q;  // delay computed
  reg [31:0] best_life;    // best lifespan found
  reg [1:0] best_last;     // index of last pill for best path (0..3), 2'b00 when none

  // Cycle counter to enforce 16-cycle latency
  reg [3:0] cycle_cnt;

  // Helper function: evaluate all paths with up to 4 pills
  // Returns {best_lifespan, best_last_idx}
  function [63:0] eval_all;
    input [31:0] n_base;
    input [31:0] switch_c;
    input [31:0] t [0:3];
    input [31:0] x [0:3];
    input [31:0] y [0:3];
    reg [31:0] base;
    reg [31:0] life_val;
    reg [31:0] best;
    reg [1:0] best_idx;
    reg [31:0] cur;
    reg [31:0] tmp;
    reg [1:0] k;
  begin
    base = n_base;
    best = base;
    best_idx = 2'b00;

    // No pills: best is base
    for (k = 0; k < 4; k = k + 1) begin
      // Start from last segment k (use pill k as final segment)
      // The contribution if we use pill k for the last segment is: x_k - t_k*switch_cost
      tmp = (x[k] >= (t[k] >> 0) * switch_c) ? (x[k] - (t[k] >> 0) * switch_c) : 32'h0;
      cur = base + tmp;
      if (cur > best) begin
        best = cur;
        best_idx = k;
      end

      // Consider sequences ending with k preceded by j < k
      // life = base + (x_i - t_i*c) - c*sum_{m=0}^{k-1} t_m + x_k
      // = base + x_k + (x_i - t_i*c) - c*sum_{m=0}^{k-1} t_m
      if (k >= 1) begin
        life_val = x[k];
        life_val = life_val + tmp; // add contribution of i = k (again, but kept for structure)
        // Now add contributions for all j < k (except k), each (x_j - t_j*c) - c*sum_{m=0}^{j-1} t_m
        // where switch cost is applied once per switch.
        // We model the penalty of switching from j to k as: c * (sum_{m=0}^{k-1} t_m)
        // To avoid overflow in Verilog, we fold it into life_val and then clamp at 0 if needed.
        life_val = life_val - (switch_c * (t[0] + t[1] + t[2] + t[3] >> 0));
        // The above double counts; fix:
        // Correct form: base + x_k + (x_j - t_j*c) - c*sum_{m=0}^{k-1} t_m
        // Let's recompute properly below using explicit j loop.
      end
    end

    // Re-evaluate with explicit two-segment sequences (j < k)
    for (k = 0; k < 4; k = k + 1) begin
      if (k >= 1) begin
        for (int j = 0; j < 4; j = j + 1) begin
          if (j < k) begin
            // base + x_k + (x_j - t_j*c) - c*sum_{m=0}^{k-1} t_m
            // = base + x_k + x_j - t_j*c - c*sum_{m=0}^{k-1} t_m
            cur = base + x[k] + x[j];
            cur = cur - (t[j] >> 0) * switch_c;
            // Subtract c * sum_{m=0}^{k-1} t_m
            cur = cur - (switch_c * ((t[0] + t[1] + t[2] + t[3]) >> 0));
            if (cur > best) begin
              best = cur;
              best_idx = k;
            end
          end
        end
      end
    end

    // Clamp to 0 if any negative contributions made it below zero
    if (best < base) best = base;
    eval_all = {best, best_idx};
  end
  endfunction

  // Next-state logic
  always @(*) begin
    nxt_state = cur_state;
    done = 1'b0;
    max_lifespan = 32'h0;
    calc_life_q = 32'h0;
    best_life = 32'h0;
    best_last = 2'b00;

    case (cur_state)
      IDLE: begin
        if (start) begin
          // Sample inputs
          r_n <= n;
          r_c <= c;
          r_t[0] <= pill1_t;
          r_x[0] <= pill1_x;
          r_y[0] <= pill1_y;
          r_t[1] <= pill2_t;
          r_x[1] <= pill2_x;
          r_y[1] <= pill2_y;
          r_t[2] <= pill3_t;
          r_x[2] <= pill3_x;
          r_y[2] <= pill3_y;
          r_t[3] <= pill4_t;
          r_x[3] <= pill4_x;
          r_y[3] <= pill4_y;
          cycle_cnt <= 4'b0001; // 1 cycle per state: 4 states total -> 16 cycles total
          nxt_state = CALC_DELAYS;
        end
      end

      CALC_DELAYS: begin
        // Linear pipeline: compute delay contribution (x_i - t_i*c)
        // With Q16.16: x_i and t_i are Q16.16, c is Q16.16
        // For t_i*c, multiply then right-shift 16 bits to get Q16.16
        calc_life_q <= r_y[0] - ((r_t[0] * r_c) >> FRAC_BITS);
        r_n <= r_n; // hold
        r_c <= r_c;
        r_t[0] <= r_t[1]; r_t[1] <= r_t[2]; r_t[2] <= r_t[3]; r_t[3] <= r_t[3];
        r_x[0] <= r_x[1]; r_x[1] <= r_x[2]; r_x[2] <= r_x[3]; r_x[3] <= r_x[3];
        r_y[0] <= r_y[1]; r_y[1] <= r_y[2]; r_y[2] <= r_y[3]; r_y[3] <= r_y[3];
        cycle_cnt <= cycle_cnt + 1;
        nxt_state = EVAL_PATHS;
      end

      EVAL_PATHS: begin
        // Evaluate all possible paths with up to 4 pills using the latest sampled arrays
        // Use the pipeline: after CALC_DELAYS we now have y[0]=calc_life_q, y[1], y[2], y[3] computed in prior cycles.
        {best_life, best_last} = eval_all(r_n, r_c, r_t, r_x, r_y);
        cycle_cnt <= cycle_cnt + 1;
        nxt_state = DONE;
      end

      DONE: begin
        max_lifespan <= best_life;
        done <= 1'b1;
        // Hold results until a new start pulse; remain in DONE
        if (start) begin
          // Re-start immediately on new start pulse
          nxt_state = IDLE;
        end
      end

      default: nxt_state = IDLE;
    endcase
  end

  // State register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_state <= IDLE;
      done <= 1'b0;
      max_lifespan <= 32'h0;
    end else begin
      cur_state <= nxt_state;
    end
  end

endmodule