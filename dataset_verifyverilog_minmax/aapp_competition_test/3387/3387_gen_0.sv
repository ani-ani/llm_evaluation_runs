module bandwidth_allocator(
  input clk,
  input rst_n,
  input start,
  input [31:0] t_fixed,  // Q16.16 format (total bandwidth)
  input [31:0] a0, a1, a2, a3, // Q16.16 min bandwidth per species
  input [31:0] b0, b1, b2, b3, // Q16.16 max bandwidth per species
  input [31:0] d0, d1, d2, d3, // Q16.16 demand ratios (>=1)
  output reg [31:0] x0, x1, x2, x3, // Q16.16 allocated bandwidths
  output reg done
);

  // State machine states
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    CALC_FAIR  = 3'd1,
    CLAMP      = 3'd2,
    DISTRIBUTE = 3'd3,
    VERIFY     = 3'd4,
    DONE       = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] d [0:3];
  reg [31:0] a [0:3];
  reg [31:0] b [0:3];
  reg [31:0] y [0:3];   // fair shares (Q16.16)
  reg [31:0] x [0:3];   // allocations (Q16.16)
  reg [63:0] sum_d;     // sum of demands (Q16.16)
  reg [63:0] total;     // sum of allocations (Q16.16)
  reg [63:0] residual;  // remaining bandwidth to distribute (Q16.16)
  reg [31:0] denom;     // safe denominator (Q16.16)
  reg [31:0] min_active; // 1 if there exists non-clamped species
  reg [31:0] max_active; // 1 if there exists non-clamped species
  reg [31:0] idx;       // iteration index for distribute
  reg [31:0] iter_cnt;  // iteration count for adjustment loop
  reg [63:0] guard;     // guard for IDLE latch of t_fixed
  reg [31:0] t_latch;   // latched total bandwidth at start

  // Helper functions (Q16.16)
  function [31:0] mul_q16_16;
    input [31:0] a, b;
    reg sign;
    reg [31:0] abs_a, abs_b;
    reg [63:0] prod;
    begin
      sign = (a[31] ^ b[31]);
      abs_a = a[31] ? ~a + 1 : a;
      abs_b = b[31] ? ~b + 1 : b;
      prod = {1'b0, abs_a} * {1'b0, abs_b}; // 64-bit product
      // Round to nearest Q16.16 from 32.32 representation
      prod = prod + (1ull << 15); // add 0.5 in Q32.32
      prod = prod >> 16;          // keep upper 32 bits + rounding
      mul_q16_16 = prod[31:0];
      mul_q16_16[31] = sign ? ~mul_q16_16 + 1 : mul_q16_16;
    end
  endfunction

  function [31:0] div_q16_16;
    input [31:0] a, b;
    reg sign;
    reg [31:0] abs_a, abs_b;
    reg [63:0] num, den, quot;
    begin
      sign = (a[31] ^ b[31]);
      abs_a = a[31] ? ~a + 1 : a;
      abs_b = b[31] ? ~b + 1 : b;
      // Avoid divide-by-zero
      if (abs_b == 0) begin
        div_q16_16 = 32'h7FFFFFFF; // saturate to max positive Q16.16
      end else begin
        // Scale numerator to 48.16 (Q16.16 * 2^16), then divide by 48.16 -> 16.16
        num = {abs_a, 16'h0000}; // 48-bit representation in 64-bit
        den = {abs_b, 16'h0000}; // 48-bit denominator
        quot = num / den;        // integer division
        // Quot is in 32.16; round to 16.16
        quot = quot + (1ull << 15); // add 0.5 LSB for rounding
        div_q16_16 = quot[31:0];
        div_q16_16[31] = sign ? ~div_q16_16 + 1 : div_q16_16;
      end
    end
  endfunction

  function [31:0] clamp_q16;
    input [31:0] val, lo, hi;
    begin
      if (lo > hi) begin
        // Invalid clamp range, saturate to lo
        clamp_q16 = lo;
      end else begin
        if (val < lo) clamp_q16 = lo;
        else if (val > hi) clamp_q16 = hi;
        else clamp_q16 = val;
      end
    end
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      x0 <= 32'h0; x1 <= 32'h0; x2 <= 32'h0; x3 <= 32'h0;
      y0 <= 32'h0; y1 <= 32'h0; y2 <= 32'h0; y3 <= 32'h0; // y arrays not visible outside but cleared
      total <= 64'h0;
      residual <= 64'h0;
      denom <= 32'h0;
      min_active <= 1'b0;
      max_active <= 1'b0;
      idx <= 32'h0;
      iter_cnt <= 32'h0;
      t_latch <= 32'h0;
      guard <= 64'h0;
      d[0] <= 32'h0; d[1] <= 32'h0; d[2] <= 32'h0; d[3] <= 32'h0;
      a[0] <= 32'h0; a[1] <= 32'h0; a[2] <= 32'h0; a[3] <= 32'h0;
      b[0] <= 32'h0; b[1] <= 32'h0; b[2] <= 32'h0; b[3] <= 32'h0;
      y[0] <= 32'h0; y[1] <= 32'h0; y[2] <= 32'h0; y[3] <= 32'h0;
      x[0] <= 32'h0; x[1] <= 32'h0; x[2] <= 32'h0; x[3] <= 32'h0;
    end else begin
      // Next state logic
      case (next_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            t_latch <= t_fixed;
            guard <= 64'h0;
            // Latch parameters
            d[0] <= d0; d[1] <= d1; d[2] <= d2; d[3] <= d3;
            a[0] <= a0; a[1] <= a1; a[2] <= a2; a[3] <= a3;
            b[0] <= b0; b[1] <= b1; b[2] <= b2; b[3] <= b3;
            // Clear state
            y[0] <= 32'h0; y[1] <= 32'h0; y[2] <= 32'h0; y[3] <= 32'h0;
            x[0] <= 32'h0; x[1] <= 32'h0; x[2] <= 32'h0; x[3] <= 32'h0;
            sum_d <= 64'h0;
            total <= 64'h0;
            residual <= 64'h0;
            denom <= 32'h0;
            min_active <= 1'b0;
            max_active <= 1'b0;
            idx <= 32'h0;
            iter_cnt <= 32'h0;
          end
        end
        CALC_FAIR: begin
          // sum_d = d0+d1+d2+d3
          sum_d <= {d[0], 16'h0} + {d[1], 16'h0} + {d[2], 16'h0} + {d[3], 16'h0};
          // y_i = (d_i * t_fixed) / sum_d (Q16.16)
          y[0] <= div_q16_16(mul_q16_16(d[0], t_latch), 32'h0); // placeholder, will be updated
          y[1] <= div_q16_16(mul_q16_16(d[1], t_latch), 32'h0);
          y[2] <= div_q16_16(mul_q16_16(d[2], t_latch), 32'h0);
          y[3] <= div_q16_16(mul_q16_16(d[3], t_latch), 32'h0);
          // denom will be filled in next cycle with sum_d upper 32 bits
          // Clear accumulators
          total <= 64'h0;
          residual <= {t_latch, 16'h0};
          min_active <= 1'b0;
          max_active <= 1'b0;
          idx <= 32'h0;
          iter_cnt <= 32'h0;
        end
        CLAMP: begin
          // x_i = clamp(y_i, a_i, b_i); update total and residual
          // Note: y array is computed in CALC_FAIR; in practice update next state
          // We keep y and recompute x in CLAMP
          // Determine min_active and max_active flags to guide distribution
          // We compute per species in parallel using current x array (updated here)
          // To avoid missing assignments, recompute y and x again in CLAMP cycle
          // First compute y again to be safe (consumes 1 extra cycle)
          y[0] <= div_q16_16(mul_q16_16(d[0], t_latch), denom);
          y[1] <= div_q16_16(mul_q16_16(d[1], t_latch), denom);
          y[2] <= div_q16_16(mul_q16_16(d[2], t_latch), denom);
          y[3] <= div_q16_16(mul_q16_16(d[3], t_latch), denom);
        end
        DISTRIBUTE: begin
          // Iteratively adjust allocations
          // Update x[i] and recompute total/residual incrementally
          // idx is from 0..3; iter_cnt counts up to 3, then to VERIFY
          case (idx)
            32'd0: begin
              if (residual >= 32) begin
                // Increase x0 by 1 Q16.16 step if not at max
                if (x[0] < b[0]) begin
                  x[0] <= x[0] + 1;
                  total <= total + 1;
                  residual <= residual - 1;
                end else begin
                  // cannot increase, still consume cycle to progress
                end
              end else if (residual <= -32) begin
                // Decrease x0 by 1 Q16.16 step if not at min
                if (x[0] > a[0]) begin
                  x[0] <= x[0] - 1;
                  total <= total - 1;
                  residual <= residual + 1;
                end else begin
                  // cannot decrease
                end
              end
            end
            32'd1: begin
              if (residual >= 32) begin
                if (x[1] < b[1]) begin
                  x[1] <= x[1] + 1;
                  total <= total + 1;
                  residual <= residual - 1;
                end else begin
                end
              end else if (residual <= -32) begin
                if (x[1] > a[1]) begin
                  x[1] <= x[1] - 1;
                  total <= total - 1;
                  residual <= residual + 1;
                end else begin
                end
              end
            end
            32'd2: begin
              if (residual >= 32) begin
                if (x[2] < b[2]) begin
                  x[2] <= x[2] + 1;
                  total <= total + 1;
                  residual <= residual - 1;
                end else begin
                end
              end else if (residual <= -32) begin
                if (x[2] > a[2]) begin
                  x[2] <= x[2] - 1;
                  total <= total - 1;
                  residual <= residual + 1;
                end else begin
                end
              end
            end
            32'd3: begin
              if (residual >= 32) begin
                if (x[3] < b[3]) begin
                  x[3] <= x[3] + 1;
                  total <= total + 1;
                  residual <= residual - 1;
                end else begin
                end
              end else if (residual <= -32) begin
                if (x[3] > a[3]) begin
                  x[3] <= x[3] - 1;
                  total <= total - 1;
                  residual <= residual + 1;
                end else begin
                end
              end
            end
          endcase
        end
        VERIFY: begin
          // Keep current x; done will be set in DONE state
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
      state <= next_state;
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_FAIR;
        else next_state = IDLE;
      end
      CALC_FAIR: begin
        // After one cycle, sum_d is ready; use upper 32 bits for denom
        // We need a combinatorial selection of denom based on sum_d
        // Use a temporary to avoid large mux; it is OK to transition in next cycle
        // Transition to CLAMP unconditionally after a cycle
        next_state = CLAMP;
      end
      CLAMP: begin
        // In CLAMP cycle, compute y and x based on denom; then move to DISTRIBUTE
        next_state = DISTRIBUTE;
      end
      DISTRIBUTE: begin
        // After distributing and trying all indices (idx 0..3), go to VERIFY
        if (residual == 0) begin
          next_state = VERIFY;
        end else begin
          // Progress idx across 0..3 repeatedly, up to 3 passes (12 cycles)
          // iter_cnt is not strictly needed since we check residual, but for safety:
          if (idx < 3) begin
            next_state = DISTRIBUTE; // stay in DISTRIBUTE to move idx
          end else begin
            if (iter_cnt < 3) begin
              // Reset idx and continue for another pass
              next_state = DISTRIBUTE;
            end else begin
              // Hard cap: if still residual, go to VERIFY (finalize)
              next_state = VERIFY;
            end
          end
        end
      end
      VERIFY: begin
        // After verify cycle, set DONE
        next_state = DONE;
      end
      DONE: begin
        // Hold until start deasserted; then go back to IDLE if start=0
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Update outputs and internal arrays each cycle based on state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Outputs are already cleared in reset case above
    end else begin
      case (state)
        IDLE: begin
          // Outputs held reset until DONE
          x0 <= 32'h0; x1 <= 32'h0; x2 <= 32'h0; x3 <= 32'h0;
        end
        CALC_FAIR: begin
          // In CALC_FAIR, compute denom in the next cycle; hold y/x for now
        end
        CLAMP: begin
          // Compute denom from sum_d (upper 32 bits in 64.48 -> upper 32 is fine, we used 48.16; use high part of 64-bit)
          // We carried sum_d in 64-bit {d, 16'h0}, so use upper 32 bits
          denom <= sum_d[63:32];
          // Compute y_i and x_i (clamped)
          y[0] <= div_q16_16(mul_q16_16(d[0], t_latch), denom);
          y[1] <= div_q16_16(mul_q16_16(d[1], t_latch), denom);
          y[2] <= div_q16_16(mul_q16_16(d[2], t_latch), denom);
          y[3] <= div_q16_16(mul_q16_16(d[3], t_latch), denom);
          x[0] <= clamp_q16(y[0], a[0], b[0]);
          x[1] <= clamp_q16(y[1], a[1], b[1]);
          x[2] <= clamp_q16(y[2], a[2], b[2]);
          x[3] <= clamp_q16(y[3], a[3], b[3]);
          // Determine min_active and max_active flags
          min_active <= (x[0] > a[0] ? 1'b1 : 1'b0) |
                        (x[1] > a[1] ? 1'b1 : 1'b0) |
                        (x[2] > a[2] ? 1'b1 : 1'b0) |
                        (x[3] > a[3] ? 1'b1 : 1'b0);
          max_active <= (x[0] < b[0] ? 1'b1 : 1'b0) |
                        (x[1] < b[1] ? 1'b1 : 1'b0) |
                        (x[2] < b[2] ? 1'b1 : 1'b0) |
                        (x[3] < b[3] ? 1'b1 : 1'b0);
          // Initialize total and residual using latched t_fixed
          total <= {x[0], 16'h0} + {x[1], 16'h0} + {x[2], 16'h0} + {x[3], 16'h0};
          residual <= {t_latch, 16'h0} - ({x[0], 16'h0} + {x[1], 16'h0} + {x[2], 16'h0} + {x[3], 16'h0});
          idx <= 32'h0;
          iter_cnt <= 32'h0;
        end
        DISTRIBUTE: begin
          // Update idx and iter_cnt
          if (idx < 3) begin
            idx <= idx + 1;
          end else begin
            idx <= 32'h0;
            if (iter_cnt < 3) begin
              iter_cnt <= iter_cnt + 1;
            end else begin
              iter_cnt <= iter_cnt; // hold
            end
          end
        end
        VERIFY: begin
          // Finalize outputs
          x0 <= x[0]; x1 <= x[1]; x2 <= x[2]; x3 <= x[3];
        end
        DONE: begin
          // Keep outputs stable
          x0 <= x[0]; x1 <= x[1]; x2 <= x[2]; x3 <= x[3];
        end
      endcase
    end
  end

endmodule