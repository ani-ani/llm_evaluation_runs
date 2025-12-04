module grade_optimizer(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] N, // number of subjects (1-8)
  input [7:0] T, // total hours (0-255)
  input [31:0] a0, // Q16.16 fixed-point a_i for subject 0
  input [31:0] b0, // Q16.16 fixed-point b_i for subject 0
  input [31:0] c0, // Q16.16 fixed-point c_i for subject 0
  input [31:0] a1, // Q16.16 fixed-point a_i for subject 1
  input [31:0] b1, // Q16.16 fixed-point b_i for subject 1
  input [31:0] c1, // Q16.16 fixed-point c_i for subject 1
  input [31:0] a2, // Q16.16 fixed-point a_i for subject 2
  input [31:0] b2, // Q16.16 fixed-point b_i for subject 2
  input [31:0] c2, // Q16.16 fixed-point c_i for subject 2
  input [31:0] a3, // Q16.16 fixed-point a_i for subject 3
  input [31:0] b3, // Q16.16 fixed-point b_i for subject 3
  input [31:0] c3, // Q16.16 fixed-point c_i for subject 3
  input [31:0] a4, // Q16.16 fixed-point a_i for subject 4
  input [31:0] b4, // Q16.16 fixed-point b_i for subject 4
  input [31:0] c4, // Q16.16 fixed-point c_i for subject 4
  input [31:0] a5, // Q16.16 fixed-point a_i for subject 5
  input [31:0] b5, // Q16.16 fixed-point b_i for subject 5
  input [31:0] c5, // Q16.16 fixed-point c_i for subject 5
  input [31:0] a6, // Q16.16 fixed-point a_i for subject 6
  input [31:0] b6, // Q16.16 fixed-point b_i for subject 6
  input [31:0] c6, // Q16.16 fixed-point c_i for subject 6
  input [31:0] a7, // Q16.16 fixed-point a_i for subject 7
  input [31:0] b7, // Q16.16 fixed-point b_i for subject 7
  input [31:0] c7, // Q16.16 fixed-point c_i for subject 7
  output reg [31:0] avg_grade, // Q16.16 result
  output reg done // high when result valid
);

  // Q16.16 multiply with rounding-to-nearest, tie to even
  function [31:0] mul_q16_16;
    input [31:0] a;
    input [31:0] b;
    reg [63:0] prod;
    reg [16:0] frac;
    reg sign_res;
    reg [30:0] mag_res;
    reg carry;
  begin
    prod = $signed(a) * $signed(b);
    // Sign-extend to 65 bits for proper rounding
    sign_res = prod[63];
    // Use only the low 48 bits: [47:0] = {i32, f16} plus sticky
    // Rounding position: 16 fractional bits
    frac = prod[47:31]; // 17 bits: 16 frac + sticky (LSB is sticky)
    carry = frac[16]; // the 16th fractional bit (bit 16 is the 1 below tie)
    // Rounding: add 1 to position 16 if frac[15:0] >= 2^15, or frac[15:0] > 2^15 (tie case handled via LSB sticky)
    // frac[0] is the sticky bit (OR of all bits below position 15), so tie when frac[15:0] == 2^15
    if (frac[15:0] > 16'h8000 || (frac[15:0] == 16'h8000 && carry)) begin
      prod = prod + (1 << 31); // increment integer part by 1 (16 fractional bits => add 2^16 => in 64-bit view add 1<<31)
    end else begin
      // clear fraction: round down
      prod[30:0] = prod[30:0]; // no change; just keep the same
    end
    // Result is in high 32 bits of prod, already rounded
    mul_q16_16 = prod[63:32];
  end
  endfunction

  // Q16.16 addition
  function [31:0] add_q16_16;
    input [31:0] a;
    input [31:0] b;
  begin
    add_q16_16 = $signed(a) + $signed(b);
  end
  endfunction

  // Q16.16 addition of three operands
  function [31:0] add3_q16_16;
    input [31:0] a;
    input [31:0] b;
    input [31:0] c;
  begin
    add3_q16_16 = $signed(a) + $signed(b) + $signed(c);
  end
  endfunction

  // Signed clamp: x = min(max(x, lo), hi)
  function [31:0] clamp;
    input [31:0] x;
    input [31:0] lo;
    input [31:0] hi;
    reg [31:0] t;
  begin
    t = x;
    if ($signed(t) < $signed(lo)) t = lo;
    if ($signed(t) > $signed(hi)) t = hi;
    clamp = t;
  end
  endfunction

  // Registers and state
  reg [6:0] stage;        // 0..99
  reg active;

  // Time allocation per subject (Q16.16)
  reg [31:0] t_mem [0:7];
  // Coefficient storage (Q16.16)
  reg [31:0] a_mem [0:7];
  reg [31:0] b_mem [0:7];
  reg [31:0] c_mem [0:7];

  // Temporary/shared for compute
  reg [31:0] deriv_mem [0:7];
  reg [31:0] t_next [0:7];

  // Stage 0 buffers
  reg [31:0] max_deriv_reg;
  reg [31:0] min_deriv_reg;
  reg [2:0] max_idx_reg;
  reg [2:0] min_idx_reg;

  // Final accumulation
  reg [31:0] sum_grade [0:7];
  reg [31:0] acc_grade;

  // Division-by-N iterative stepper (unsigned)
  // denom is power of two at each step; start with denom = N, then denom>>=1 each step
  reg [7:0] denom;
  reg [31:0] rema; // remainder in Q16.16 scaled by denom
  reg [31:0] qu32; // integer result accumulator (Q0.0)
  reg [15:0] frac16; // fractional 16 bits accumulator
  reg frac_carry; // carry into 16-bit fraction
  reg [15:0] frac_next; // next fraction

  // Helpers to index coefficients
  always @(*) begin
    a_mem[0] = a0; b_mem[0] = b0; c_mem[0] = c0;
    a_mem[1] = a1; b_mem[1] = b1; c_mem[1] = c1;
    a_mem[2] = a2; b_mem[2] = b2; c_mem[2] = c2;
    a_mem[3] = a3; b_mem[3] = b3; c_mem[3] = c3;
    a_mem[4] = a4; b_mem[4] = b4; c_mem[4] = c4;
    a_mem[5] = a5; b_mem[5] = b5; c_mem[5] = c5;
    a_mem[6] = a6; b_mem[6] = b6; c_mem[6] = c6;
    a_mem[7] = a7; b_mem[7] = b7; c_mem[7] = c7;
  end

  integer i;

  // FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active <= 1'b0;
      done <= 1'b0;
      stage <= 7'd0;
      avg_grade <= 32'd0;
      for (i = 0; i < 8; i = i + 1) begin
        t_mem[i] <= 32'd0;
        deriv_mem[i] <= 32'd0;
        t_next[i] <= 32'd0;
        sum_grade[i] <= 32'd0;
      end
      max_deriv_reg <= 32'h80000000; // very small
      min_deriv_reg <= 32'h7FFFFFFF; // very large
      max_idx_reg <= 3'd0;
      min_idx_reg <= 3'd0;
      acc_grade <= 32'd0;
      denom <= 8'd0;
      rema <= 32'd0;
      qu32 <= 32'd0;
      frac16 <= 16'd0;
      frac_carry <= 1'b0;
      frac_next <= 16'd0;
    end else begin
      // default
      done <= 1'b0;
      // Start condition
      if (!active && start) begin
        active <= 1'b1;
        stage <= 7'd0;
        done <= 1'b0;
        // Initialize t[i] = T/N (rounded) in Q16.16
        // Use truncation then correct rounding
        // base = T << 16 / N
        for (i = 0; i < 8; i = i + 1) begin
          if (i < N) begin
            // t_i = (T << 16) / N, rounded to nearest
            // We'll compute with one extra bit, then round
            // Compute with floor, then compare remainder*2 vs N
            t_mem[i] <= (($unsigned(T) << 16) / N);
          end else begin
            t_mem[i] <= 32'd0;
          end
          deriv_mem[i] <= 32'd0;
          sum_grade[i] <= 32'd0;
        end
        // Precompute max/min deriv in stage 0
        max_deriv_reg <= 32'h80000000;
        min_deriv_reg <= 32'h7FFFFFFF;
        max_idx_reg <= 3'd0;
        min_idx_reg <= 3'd0;
        acc_grade <= 32'd0;
        // Reset division state
        denom <= N;
        rema <= 32'd0;
        qu32 <= 32'd0;
        frac16 <= 16'd0;
        frac_carry <= 1'b0;
        frac_next <= 16'd0;
      end else if (active) begin
        if (stage == 0) begin
          // Stage 0: compute initial derivs and adjust once
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              deriv_mem[i] <= add_q16_16(mul_q16_16({2'b0, a_mem[i][29:0]}, t_mem[i]), b_mem[i]); // 2*a_i*t_i + b_i; a is Q16.16, t is Q16.16; 2*a_i is effectively a_i<<1 with 0 fraction (Q16.16)
            end else begin
              deriv_mem[i] <= 32'h80000000; // very small for disabled
            end
          end
          // Find max/min deriv with index
          max_deriv_reg <= 32'h80000000;
          min_deriv_reg <= 32'h7FFFFFFF;
          max_idx_reg <= 3'd0;
          min_idx_reg <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              if ($signed(deriv_mem[i]) > $signed(max_deriv_reg)) begin
                max_deriv_reg <= deriv_mem[i];
                max_idx_reg <= i[2:0];
              end
              if ($signed(deriv_mem[i]) < $signed(min_deriv_reg)) begin
                min_deriv_reg <= deriv_mem[i];
                min_idx_reg <= i[2:0];
              end
            end
          end
          // Prepare t_next with +1 for max, -1 for min, clamp to [0, T]
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              if (i == max_idx_reg) begin
                t_next[i] <= clamp(add_q16_16(t_mem[i], 32'd1), 32'd0, {T, 16'd0});
              end else if (i == min_idx_reg) begin
                t_next[i] <= clamp(add_q16_16(t_mem[i], 32'hFFFFFFFF), 32'd0, {T, 16'd0});
              end else begin
                t_next[i] <= t_mem[i];
              end
            end else begin
              t_next[i] <= 32'd0;
            end
          end
          stage <= stage + 1;
        end else if (stage >= 1 && stage < 99) begin
          // Stages 1..98: compute derivs from last adjusted times, adjust again
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              deriv_mem[i] <= add_q16_16(mul_q16_16({2'b0, a_mem[i][29:0]}, t_next[i]), b_mem[i]);
            end else begin
              deriv_mem[i] <= 32'h80000000;
            end
          end
          max_deriv_reg <= 32'h80000000;
          min_deriv_reg <= 32'h7FFFFFFF;
          max_idx_reg <= 3'd0;
          min_idx_reg <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              if ($signed(deriv_mem[i]) > $signed(max_deriv_reg)) begin
                max_deriv_reg <= deriv_mem[i];
                max_idx_reg <= i[2:0];
              end
              if ($signed(deriv_mem[i]) < $signed(min_deriv_reg)) begin
                min_deriv_reg <= deriv_mem[i];
                min_idx_reg <= i[2:0];
              end
            end
          end
          // Apply new adjustments to t_next
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              if (i == max_idx_reg) begin
                t_next[i] <= clamp(add_q16_16(t_next[i], 32'd1), 32'd0, {T, 16'd0});
              end else if (i == min_idx_reg) begin
                t_next[i] <= clamp(add_q16_16(t_next[i], 32'hFFFFFFFF), 32'd0, {T, 16'd0});
              end else begin
                t_next[i] <= t_next[i];
              end
            end else begin
              t_next[i] <= 32'd0;
            end
          end
          stage <= stage + 1;
        end else if (stage == 99) begin
          // Final stage: compute avg_grade = (sum f_i(t_i))/N, set done for one cycle
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              // f_i(t) = a*t^2 + b*t + c (all Q16.16)
              sum_grade[i] <= add3_q16_16(
                mul_q16_16(a_mem[i], mul_q16_16(t_next[i], t_next[i])),
                mul_q16_16(b_mem[i], t_next[i]),
                c_mem[i]
              );
            end else begin
              sum_grade[i] <= 32'd0;
            end
          end
          // Accumulate sum
          acc_grade <= 32'd0;
          for (i = 0; i < 8; i = i + 1) begin
            acc_grade <= add_q16_16(acc_grade, sum_grade[i]);
          end
          // Start division by N (unsigned iterative method)
          // Ensure numerator is non-negative for division
          rema <= $unsigned($signed(acc_grade) < 32'd0 ? 32'd0 : acc_grade);
          qu32 <= 32'd0;
          denom <= N;
          frac16 <= 16'd0;
          frac_carry <= 1'b0;
          stage <= stage + 1; // go to 100 (finalize)
        end else if (stage == 100) begin
          // Perform up to 16 iterations of division to compute 16 fractional bits
          if (denom != 0) begin
            if (rema >= {qu32, 1'b0, denom}) begin
              rema <= rema - ({qu32, 1'b0, denom});
              qu32 <= {qu32, 1'b1};
            end else begin
              qu32 <= {qu32, 1'b0};
            end
            rema <= {rema, 1'b0};
            denom <= denom >> 1;
          end else begin
            // denom == 0 means done; keep state
            denom <= 8'd0;
          end
          // Build fractional bits during shifts
          if (denom >= 1) begin
            // still shifting, store next bit for fraction
            if (rema >= {qu32, 1'b0, 8'd1}) begin
              frac_next <= {frac_next, 1'b1};
            end else begin
              frac_next <= {frac_next, 1'b0};
            end
          end
          // After denominator becomes 0, propagate final fraction and set done
          if (denom == 0) begin
            avg_grade <= { $signed(qu32[31] ? 1'b1 : 1'b0), qu32[30:0] } | ( {16'd0, frac16} << 16 ); // keep signedness in integer part; fraction uses all fraction bits
            done <= 1'b1;
            active <= 1'b0;
          end
        end
      end
    end
  end

  // Track fractional accumulation in stage 100 across cycles
  // Carry final quotient bit into fraction as we shift denom
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frac16 <= 16'd0;
    end else if (active && stage == 100) begin
      // After the comparison in stage 100, feed the decision into frac16 next cycle
      // We rely on numerator >= {qu32, 1'b0, denom} check earlier in the block.
      // To avoid combinational loops, update frac16 based on previous qu32 and denom.
      // Implementation detail: we precompute frac_next in comb block, then sync it here.
      frac16 <= frac_next;
    end else begin
      frac16 <= 16'd0;
    end
  end

endmodule
