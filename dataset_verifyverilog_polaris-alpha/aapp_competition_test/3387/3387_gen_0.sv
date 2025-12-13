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

  // State encoding
  localparam IDLE       = 3'd0;
  localparam CALC_FAIR  = 3'd1;
  localparam CLAMP      = 3'd2;
  localparam DISTRIBUTE = 3'd3;
  localparam VERIFY     = 3'd4;
  localparam DONE       = 3'd5;

  reg [2:0] state, next_state;

  // Internal registers
  reg [31:0] d0_r, d1_r, d2_r, d3_r;
  reg [31:0] a0_r, a1_r, a2_r, a3_r;
  reg [31:0] b0_r, b1_r, b2_r, b3_r;
  reg [31:0] t_fixed_r;

  reg [33:0] sum_d;            // Sum of demands (allow growth)
  reg [63:0] prod0, prod1, prod2, prod3;
  reg [31:0] y0, y1, y2, y3;   // Fair shares

  reg [31:0] x0_r, x1_r, x2_r, x3_r; // Internal allocations

  reg [33:0] T;                // total allocated

  reg [31:0] rem;              // remaining bandwidth

  reg [3:0] constrained_mask;  // 1 if clamped at min or max
  reg [3:0] at_min_mask;       // track min clamping
  reg [3:0] at_max_mask;       // track max clamping

  reg [7:0] iter_cnt;          // iteration counter (for safety / 50 cycles)

  // Safe add with saturation (32-bit)
  function automatic [31:0] sat_add32;
    input [31:0] a, b;
    reg [32:0] s;
    begin
      s = {1'b0,a} + {1'b0,b};
      sat_add32 = (s[32]) ? 32'hFFFF_FFFF : s[31:0];
    end
  endfunction

  // Safe sub (assume no negative for valid inputs; clamp at 0)
  function automatic [31:0] sat_sub32;
    input [31:0] a, b;
    begin
      if (a >= b) sat_sub32 = a - b;
      else sat_sub32 = 32'd0;
    end
  endfunction

  // Clamp function
  function automatic [31:0] clamp32;
    input [31:0] val, min_v, max_v;
    begin
      if (val < min_v) clamp32 = min_v;
      else if (val > max_v) clamp32 = max_v;
      else clamp32 = val;
    end
  endfunction

  // Multiply Q16.16 * Q16.16 -> Q16.16 with saturation
  function automatic [31:0] qmul32;
    input [31:0] a, b;
    reg [63:0] m;
    begin
      m = a * b; // 64-bit
      // Shift right 16 for Q16.16
      qmul32 = m[47:16];
    end
  endfunction

  // Divide (unsigned) 64/32 -> 32 with simple protection
  function automatic [31:0] udiv64_32;
    input [63:0] num;
    input [31:0] den;
    begin
      if (den == 32'd0)
        udiv64_32 = 32'd0;
      else
        udiv64_32 = num / den;
    end
  endfunction

  // Sequential state and regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      x0 <= 32'd0;
      x1 <= 32'd0;
      x2 <= 32'd0;
      x3 <= 32'd0;
      x0_r <= 32'd0;
      x1_r <= 32'd0;
      x2_r <= 32'd0;
      x3_r <= 32'd0;
      d0_r <= 32'd0; d1_r <= 32'd0; d2_r <= 32'd0; d3_r <= 32'd0;
      a0_r <= 32'd0; a1_r <= 32'd0; a2_r <= 32'd0; a3_r <= 32'd0;
      b0_r <= 32'd0; b1_r <= 32'd0; b2_r <= 32'd0; b3_r <= 32'd0;
      t_fixed_r <= 32'd0;
      sum_d <= 34'd0;
      prod0 <= 64'd0; prod1 <= 64'd0; prod2 <= 64'd0; prod3 <= 64'd0;
      y0 <= 32'd0; y1 <= 32'd0; y2 <= 32'd0; y3 <= 32'd0;
      T <= 34'd0;
      rem <= 32'd0;
      constrained_mask <= 4'b0000;
      at_min_mask <= 4'b0000;
      at_max_mask <= 4'b0000;
      iter_cnt <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs
            t_fixed_r <= t_fixed;
            d0_r <= d0; d1_r <= d1; d2_r <= d2; d3_r <= d3;
            a0_r <= a0; a1_r <= a1; a2_r <= a2; a3_r <= a3;
            b0_r <= b0; b1_r <= b1; b2_r <= b2; b3_r <= b3;
            iter_cnt <= 8'd0;
            constrained_mask <= 4'b0000;
            at_min_mask <= 4'b0000;
            at_max_mask <= 4'b0000;
          end
        end

        CALC_FAIR: begin
          // Compute sum_d
          sum_d <= {2'd0, d0_r} + {2'd0, d1_r} + {2'd0, d2_r} + {2'd0, d3_r};
          // Pre-calc products with t_fixed (64-bit)
          prod0 <= d0_r * t_fixed_r;
          prod1 <= d1_r * t_fixed_r;
          prod2 <= d2_r * t_fixed_r;
          prod3 <= d3_r * t_fixed_r;
        end

        CLAMP: begin
          // Avoid divide by zero: if sum_d==0, split equally
          if (sum_d != 0) begin
            y0 <= udiv64_32(prod0, sum_d[31:0]);
            y1 <= udiv64_32(prod1, sum_d[31:0]);
            y2 <= udiv64_32(prod2, sum_d[31:0]);
            y3 <= udiv64_32(prod3, sum_d[31:0]);
          end else begin
            y0 <= (t_fixed_r >> 2);
            y1 <= (t_fixed_r >> 2);
            y2 <= (t_fixed_r >> 2);
            y3 <= t_fixed_r - ((t_fixed_r >> 2) * 3);
          end

          // Initial clamp
          x0_r <= clamp32(y0, a0_r, b0_r);
          x1_r <= clamp32(y1, a1_r, b1_r);
          x2_r <= clamp32(y2, a2_r, b2_r);
          x3_r <= clamp32(y3, a3_r, b3_r);

          // Track constrained
          at_min_mask[0] <= (x0_r == a0_r) && (y0 < a0_r);
          at_min_mask[1] <= (x1_r == a1_r) && (y1 < a1_r);
          at_min_mask[2] <= (x2_r == a2_r) && (y2 < a2_r);
          at_min_mask[3] <= (x3_r == a3_r) && (y3 < a3_r);

          at_max_mask[0] <= (x0_r == b0_r) && (y0 > b0_r);
          at_max_mask[1] <= (x1_r == b1_r) && (y1 > b1_r);
          at_max_mask[2] <= (x2_r == b2_r) && (y2 > b2_r);
          at_max_mask[3] <= (x3_r == b3_r) && (y3 > b3_r);

          constrained_mask <= at_min_mask | at_max_mask;
        end

        DISTRIBUTE: begin
          // Compute total allocation T
          T <= {2'd0, x0_r} + {2'd0, x1_r} + {2'd0, x2_r} + {2'd0, x3_r};
        end

        VERIFY: begin
          iter_cnt <= iter_cnt + 8'd1;

          if (T[31:0] == t_fixed_r || iter_cnt >= 8'd50) begin
            // Done or reached iteration cap
            x0 <= x0_r;
            x1 <= x1_r;
            x2 <= x2_r;
            x3 <= x3_r;
            done <= 1'b1;
          end else begin
            // Compute remaining (could be positive or negative in concept)
            if (T[31:0] < t_fixed_r) begin
              // Need to distribute extra bandwidth
              rem <= t_fixed_r - T[31:0];

              // Count unconstrained
              // Simple integer proportional to original demand, ignoring clamped
              // If all constrained, just assign leftovers to not exceed max
              // Single-cycle heuristic distribution
              reg [3:0] uc_mask;
              reg [31:0] d_sum_uc;
              reg [31:0] add0, add1, add2, add3;

              uc_mask = ~constrained_mask;

              d_sum_uc = 32'd0;
              if (uc_mask[0]) d_sum_uc = d_sum_uc + d0_r;
              if (uc_mask[1]) d_sum_uc = d_sum_uc + d1_r;
              if (uc_mask[2]) d_sum_uc = d_sum_uc + d2_r;
              if (uc_mask[3]) d_sum_uc = d_sum_uc + d3_r;

              add0 = 32'd0; add1 = 32'd0; add2 = 32'd0; add3 = 32'd0;

              if (d_sum_uc != 0) begin
                if (uc_mask[0]) add0 = udiv64_32((d0_r * rem), d_sum_uc);
                if (uc_mask[1]) add1 = udiv64_32((d1_r * rem), d_sum_uc);
                if (uc_mask[2]) add2 = udiv64_32((d2_r * rem), d_sum_uc);
                if (uc_mask[3]) add3 = udiv64_32((d3_r * rem), d_sum_uc);
              end

              // Apply additions with max constraints and recompute T
              x0_r <= clamp32(sat_add32(x0_r, add0), a0_r, b0_r);
              x1_r <= clamp32(sat_add32(x1_r, add1), a1_r, b1_r);
              x2_r <= clamp32(sat_add32(x2_r, add2), a2_r, b2_r);
              x3_r <= clamp32(sat_add32(x3_r, add3), a3_r, b3_r);

              // Update constrained mask after distribution
              at_max_mask[0] <= (x0_r >= b0_r);
              at_max_mask[1] <= (x1_r >= b1_r);
              at_max_mask[2] <= (x2_r >= b2_r);
              at_max_mask[3] <= (x3_r >= b3_r);
              constrained_mask <= constrained_mask | at_max_mask;

              // Recalculate T next cycle in DISTRIBUTE
            end else begin
              // T > t_fixed_r: need to scale down proportionally on unconstrained
              reg [31:0] excess;
              reg [3:0] uc_mask2;
              reg [31:0] x_sum_uc;
              reg [31:0] sub0, sub1, sub2, sub3;

              excess = T[31:0] - t_fixed_r;
              uc_mask2 = ~constrained_mask;
              x_sum_uc = 32'd0;
              if (uc_mask2[0]) x_sum_uc = x_sum_uc + x0_r;
              if (uc_mask2[1]) x_sum_uc = x_sum_uc + x1_r;
              if (uc_mask2[2]) x_sum_uc = x_sum_uc + x2_r;
              if (uc_mask2[3]) x_sum_uc = x_sum_uc + x3_r;

              sub0 = 32'd0; sub1 = 32'd0; sub2 = 32'd0; sub3 = 32'd0;

              if (x_sum_uc != 0) begin
                if (uc_mask2[0]) sub0 = udiv64_32((x0_r * excess), x_sum_uc);
                if (uc_mask2[1]) sub1 = udiv64_32((x1_r * excess), x_sum_uc);
                if (uc_mask2[2]) sub2 = udiv64_32((x2_r * excess), x_sum_uc);
                if (uc_mask2[3]) sub3 = udiv64_32((x3_r * excess), x_sum_uc);
              end

              x0_r <= clamp32(sat_sub32(x0_r, sub0), a0_r, b0_r);
              x1_r <= clamp32(sat_sub32(x1_r, sub1), a1_r, b1_r);
              x2_r <= clamp32(sat_sub32(x2_r, sub2), a2_r, b2_r);
              x3_r <= clamp32(sat_sub32(x3_r, sub3), a3_r, b3_r);

              at_min_mask[0] <= (x0_r <= a0_r);
              at_min_mask[1] <= (x1_r <= a1_r);
              at_min_mask[2] <= (x2_r <= a2_r);
              at_min_mask[3] <= (x3_r <= a3_r);
              constrained_mask <= constrained_mask | at_min_mask;

              // Recalculate T next cycle in DISTRIBUTE
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold outputs until next start or reset
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_FAIR;
      end
      CALC_FAIR: begin
        next_state = CLAMP;
      end
      CLAMP: begin
        next_state = DISTRIBUTE;
      end
      DISTRIBUTE: begin
        next_state = VERIFY;
      end
      VERIFY: begin
        if (done) next_state = DONE;
        else if (iter_cnt >= 8'd50) next_state = DONE;
        else next_state = DISTRIBUTE;
      end
      DONE: begin
        if (!start) next_state = IDLE; // wait for start deassertion
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule