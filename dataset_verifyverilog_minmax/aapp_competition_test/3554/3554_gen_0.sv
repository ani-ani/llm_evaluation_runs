module smoothie_transport (
  input clk,
  input rst_n,
  input start,
  input [15:0] d,
  input [15:0] w,
  input [15:0] c,
  output reg [31:0] result,
  output reg done
);
  // Internal signals and pipeline stages (16 cycles for ratio + 1 for output)
  logic w_le_c_q0, w_le_c_q1, w_le_c_q2, w_le_c_q3, w_le_c_q4, w_le_c_q5, w_le_c_q6, w_le_c_q7;
  logic w_le_c_q8, w_le_c_q9, w_le_c_q10, w_le_c_q11, w_le_c_q12, w_le_c_q13, w_le_c_q14, w_le_c_q15, w_le_c_final;

  // Stage 0 registers (capture inputs when start rises)
  logic [15:0] d_q0, w_q0, c_q0;
  logic w_le_c_r0;
  // Start and valid pipeline
  logic start_q0, start_q1, start_q2, start_q3, start_q4, start_q5, start_q6, start_q7;
  logic start_q8, start_q9, start_q10, start_q11, start_q12, start_q13, start_q14, start_q15, start_final;
  logic valid_q0, valid_q1, valid_q2, valid_q3, valid_q4, valid_q5, valid_q6, valid_q7;
  logic valid_q8, valid_q9, valid_q10, valid_q11, valid_q12, valid_q13, valid_q14, valid_q15, valid_final;

  // Non-restoring divider state
  logic [16:0] rema;  // partial remainder (sign-extended), 17 bits to hold -C..+C-1
  logic [23:0] quo;   // 16 integer bits + 8 fractional bits
  logic div_c_zero_q0;
  logic [15:0] c_safe_q0;

  // Stage values for downstream computation (16-bit W/C ratio in Q8, with error correction)
  logic [15:0] w_over_c_q1, w_over_c_q2, w_over_c_q3, w_over_c_q4, w_over_c_q5, w_over_c_q6, w_over_c_q7;
  logic [15:0] w_over_c_q8, w_over_c_q9, w_over_c_q10, w_over_c_q11, w_over_c_q12, w_over_c_q13, w_over_c_q14, w_over_c_q15, w_over_c_final;

  // Deferred D, W, C copies (available at the same cycle as w_over_c_final)
  logic [15:0] d_final, w_final, c_final;

  // Base-consumption term (Q8.8) and supporting intermediates
  logic [15:0] base_term_q2, base_term_q3, base_term_q4, base_term_q5, base_term_q6, base_term_q7;
  logic [15:0] base_term_q8, base_term_q9, base_term_q10, base_term_q11, base_term_q12, base_term_q13, base_term_q14, base_term_q15, base_term_final;
  logic [15:0] w_over_c_minus1_q1, w_over_c_minus1_q2, w_over_c_minus1_q3, w_over_c_minus1_q4, w_over_c_minus1_q5, w_over_c_minus1_q6, w_over_c_minus1_q7;
  logic [15:0] w_over_c_minus1_q8, w_over_c_minus1_q9, w_over_c_minus1_q10, w_over_c_minus1_q11, w_over_c_minus1_q12, w_over_c_minus1_q13, w_over_c_minus1_q14, w_over_c_minus1_q15;

  // Final computed smoothie amount in Q8.8 before packing to Q24.8
  logic [15:0] amount_qfinal;
  logic [7:0] amount_frac_qfinal;
  logic [23:0] amount_int_qfinal;
  logic zero_final, simple_regime_final;

  // Initial stage: capture inputs on start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      d_q0 <= '0;
      w_q0 <= '0;
      c_q0 <= '0;
      w_le_c_r0 <= 1'b0;
      start_q0 <= 1'b0;
      valid_q0 <= 1'b0;
      div_c_zero_q0 <= 1'b1;
      c_safe_q0 <= '0;
    end else begin
      // capture only on the first cycle after start rise
      if (start && !start_q0) begin
        d_q0 <= d;
        w_q0 <= w;
        c_q0 <= c;
        w_le_c_r0 <= (w <= c) ? 1'b1 : 1'b0;
        start_q0 <= 1'b1;
        valid_q0 <= 1'b1;
        div_c_zero_q0 <= (c == 16'd0);
        c_safe_q0 <= (c == 16'd0) ? 16'd1 : c; // avoid division by zero
      end else begin
        start_q0 <= 1'b0;
        valid_q0 <= 1'b0;
        // hold values for the pipeline if not starting
        d_q0 <= d_q0;
        w_q0 <= w_q0;
        c_q0 <= c_q0;
        w_le_c_r0 <= w_le_c_r0;
        div_c_zero_q0 <= div_c_zero_q0;
        c_safe_q0 <= c_safe_q0;
      end
    end
  end

  // Start/valid pipeline (shift register)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_q1 <= 1'b0; start_q2 <= 1'b0; start_q3 <= 1'b0; start_q4 <= 1'b0;
      start_q5 <= 1'b0; start_q6 <= 1'b0; start_q7 <= 1'b0; start_q8 <= 1'b0;
      start_q9 <= 1'b0; start_q10 <= 1'b0; start_q11 <= 1'b0; start_q12 <= 1'b0;
      start_q13 <= 1'b0; start_q14 <= 1'b0; start_q15 <= 1'b0; start_final <= 1'b0;
      valid_q1 <= 1'b0; valid_q2 <= 1'b0; valid_q3 <= 1'b0; valid_q4 <= 1'b0;
      valid_q5 <= 1'b0; valid_q6 <= 1'b0; valid_q7 <= 1'b0; valid_q8 <= 1'b0;
      valid_q9 <= 1'b0; valid_q10 <= 1'b0; valid_q11 <= 1'b0; valid_q12 <= 1'b0;
      valid_q13 <= 1'b0; valid_q14 <= 1'b0; valid_q15 <= 1'b0; valid_final <= 1'b0;
    end else begin
      // shift the start pulse and validity through the pipeline
      start_q1 <= start_q0;   start_q2 <= start_q1;   start_q3 <= start_q2;   start_q4 <= start_q3;
      start_q5 <= start_q4;   start_q6 <= start_q5;   start_q7 <= start_q6;   start_q8 <= start_q7;
      start_q9 <= start_q8;   start_q10 <= start_q9;  start_q11 <= start_q10; start_q12 <= start_q11;
      start_q13 <= start_q12; start_q14 <= start_q13; start_q15 <= start_q14; start_final <= start_q15;
      valid_q1 <= valid_q0;   valid_q2 <= valid_q1;   valid_q3 <= valid_q2;   valid_q4 <= valid_q3;
      valid_q5 <= valid_q4;   valid_q6 <= valid_q5;   valid_q7 <= valid_q6;   valid_q8 <= valid_q7;
      valid_q9 <= valid_q8;   valid_q10 <= valid_q9;  valid_q11 <= valid_q10; valid_q12 <= valid_q11;
      valid_q13 <= valid_q12; valid_q14 <= valid_q13; valid_q15 <= valid_q14; valid_final <= valid_q15;
    end
  end

  // Propagate the W<=C flag alongside the pipeline
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_le_c_q0 <= 1'b0; w_le_c_q1 <= 1'b0; w_le_c_q2 <= 1'b0; w_le_c_q3 <= 1'b0;
      w_le_c_q4 <= 1'b0; w_le_c_q5 <= 1'b0; w_le_c_q6 <= 1'b0; w_le_c_q7 <= 1'b0;
      w_le_c_q8 <= 1'b0; w_le_c_q9 <= 1'b0; w_le_c_q10 <= 1'b0; w_le_c_q11 <= 1'b0;
      w_le_c_q12 <= 1'b0; w_le_c_q13 <= 1'b0; w_le_c_q14 <= 1'b0; w_le_c_q15 <= 1'b0; w_le_c_final <= 1'b0;
    end else begin
      w_le_c_q0 <= w_le_c_r0;
      w_le_c_q1 <= w_le_c_q0;
      w_le_c_q2 <= w_le_c_q1;
      w_le_c_q3 <= w_le_c_q2;
      w_le_c_q4 <= w_le_c_q3;
      w_le_c_q5 <= w_le_c_q4;
      w_le_c_q6 <= w_le_c_q5;
      w_le_c_q7 <= w_le_c_q6;
      w_le_c_q8 <= w_le_c_q7;
      w_le_c_q9 <= w_le_c_q8;
      w_le_c_q10 <= w_le_c_q9;
      w_le_c_q11 <= w_le_c_q10;
      w_le_c_q12 <= w_le_c_q11;
      w_le_c_q13 <= w_le_c_q12;
      w_le_c_q14 <= w_le_c_q13;
      w_le_c_q15 <= w_le_c_q14;
      w_le_c_final <= w_le_c_q15;
    end
  end

  // Stage 1: Initialize non-restoring division and compute W/C - 1 in Q8
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q1 <= '0;
      w_over_c_minus1_q1 <= '0;
    end else begin
      if (valid_q0) begin
        // Initialize: remainder = W << 8 (Q8.8), quotient = 0
        rema <= {1'b0, w_q0, 8'b0}; // 17 bits: sign bit (0) + 16 bits + 8 fractional bits of W
        quo <= '0;
        // W/C in Q8: pre-left-shift W by 8 bits then divide by (C_safe) using a single divider cycle (approx) to seed pipeline
        // We'll set w_over_c_q1 here; actual iterative refinement occurs in cycles 1..15 (total 16 cycles)
        // Seed approximation: w_over_c_q1 = (w_q0 << 8) / c_safe_q0;  (Q8.8 -> take high 16 bits to get Q8)
        w_over_c_q1 <= (({16'd0, w_q0} << 8) / c_safe_q0)[23:8];
        w_over_c_minus1_q1 <= (({16'd0, w_q0} << 8) / c_safe_q0)[23:8] - 16'd1;
      end else begin
        // Maintain state
        rema <= rema;
        quo <= quo;
        w_over_c_q1 <= w_over_c_q1;
        w_over_c_minus1_q1 <= w_over_c_minus1_q1;
      end
    end
  end

  // Iterative non-restoring division for 16 cycles (cycles 1..16 mapped to stages 2..16 -> q2..q16)
  // Stage index: s ranges 1..16; we will use q{s+1} to represent after 's' cycles
  // We'll pack them into q2..q16 arrays to avoid large procedural code for each stage using a generate loop would be clearer,
  // but to keep this construct simple and explicit, we use a macro-like shift per stage.
  // Note: Registers are named as q2..q16 to represent 1..15 additional cycles. Total = 16 cycles from initial seed.

  // Helper function via generate-like unrolled operations
  // We'll propagate w_over_c and w_over_c_minus1 through stages 2..15
  genvar gi;
  generate
    for (gi = 2; gi <= 15; gi = gi + 1) begin : div_iter_stages
      logic [15:0] w_over_c_next, w_over_c_minus1_next;
      // We'll compute next ratio by one Newton-like step using current remainder
      // remainder(gi-1) is the partial remainder after gi-2 cycles. Here we will iteratively improve.
      // To keep the design simple and within a 16-cycle path, we approximate: each stage slightly refines by
      // adding (remainder * K) / divisor. For robustness, we use a mild correction: add ((remainder << a) / c)
      // where 'a' is a small scale to avoid over/underflow. Since we already seeded a division in q1,
      // we will only need a light correction to reach a reasonable precision.
      // However, to guarantee correctness, we will directly use the non-restoring remainder to update the quotient.
      // To keep timing predictable, we will pipeline remainder update and derive w_over_c via taking the high bits of the quotient.
      // For practicality, we simply pipeline the quotient bits (quo) across stages. The final w_over_c_final is derived at q16.
      // No extra logic is added here; ratio propagation occurs via explicit registers below.
    end
  endgenerate

  // Explicit pipeline stages for quotient and remainder propagation to achieve 16 cycles total.
  // Stages q2..q16: each cycle advances one non-restoring iteration using the current remainder.
  // To avoid generating 15 always blocks, we will create them explicitly for readability and maintainability.

  // Stage 2
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q2 <= '0;
      w_over_c_minus1_q2 <= '0;
    end else begin
      if (valid_q1) begin
        // Non-restoring: if remainder >= 0 then remainder = remainder - C; quotient_bit = 1
        // else remainder = remainder + C; quotient_bit = 0
        // Note: c_safe_q0 is in Q0.0, we align remainder to Q8.8.
        // rema is 17 bits; we can add/sub 16-bit c (sign-extend to 17 bits) safely.
        if (rema[16] == 1'b0) begin
          // positive
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          // negative
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q2 <= w_over_c_q1; // ratio is derived from quotient after full 16 cycles
        w_over_c_minus1_q2 <= w_over_c_minus1_q1;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q2 <= w_over_c_q2;
        w_over_c_minus1_q2 <= w_over_c_minus1_q2;
      end
    end
  end

  // Stage 3
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q3 <= '0;
      w_over_c_minus1_q3 <= '0;
    end else begin
      if (valid_q2) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q3 <= w_over_c_q2;
        w_over_c_minus1_q3 <= w_over_c_minus1_q2;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q3 <= w_over_c_q3;
        w_over_c_minus1_q3 <= w_over_c_minus1_q3;
      end
    end
  end

  // Stage 4
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q4 <= '0;
      w_over_c_minus1_q4 <= '0;
    end else begin
      if (valid_q3) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q4 <= w_over_c_q3;
        w_over_c_minus1_q4 <= w_over_c_minus1_q3;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q4 <= w_over_c_q4;
        w_over_c_minus1_q4 <= w_over_c_minus1_q4;
      end
    end
  end

  // Stage 5
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q5 <= '0;
      w_over_c_minus1_q5 <= '0;
    end else begin
      if (valid_q4) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q5 <= w_over_c_q4;
        w_over_c_minus1_q5 <= w_over_c_minus1_q4;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q5 <= w_over_c_q5;
        w_over_c_minus1_q5 <= w_over_c_minus1_q5;
      end
    end
  end

  // Stage 6
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q6 <= '0;
      w_over_c_minus1_q6 <= '0;
    end else begin
      if (valid_q5) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q6 <= w_over_c_q5;
        w_over_c_minus1_q6 <= w_over_c_minus1_q5;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q6 <= w_over_c_q6;
        w_over_c_minus1_q6 <= w_over_c_minus1_q6;
      end
    end
  end

  // Stage 7
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q7 <= '0;
      w_over_c_minus1_q7 <= '0;
    end else begin
      if (valid_q6) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q7 <= w_over_c_q6;
        w_over_c_minus1_q7 <= w_over_c_minus1_q6;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q7 <= w_over_c_q7;
        w_over_c_minus1_q7 <= w_over_c_minus1_q7;
      end
    end
  end

  // Stage 8
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q8 <= '0;
      w_over_c_minus1_q8 <= '0;
    end else begin
      if (valid_q7) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q8 <= w_over_c_q7;
        w_over_c_minus1_q8 <= w_over_c_minus1_q7;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q8 <= w_over_c_q8;
        w_over_c_minus1_q8 <= w_over_c_minus1_q8;
      end
    end
  end

  // Stage 9
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q9 <= '0;
      w_over_c_minus1_q9 <= '0;
    end else begin
      if (valid_q8) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q9 <= w_over_c_q8;
        w_over_c_minus1_q9 <= w_over_c_minus1_q8;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q9 <= w_over_c_q9;
        w_over_c_minus1_q9 <= w_over_c_minus1_q9;
      end
    end
  end

  // Stage 10
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q10 <= '0;
      w_over_c_minus1_q10 <= '0;
    end else begin
      if (valid_q9) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q10 <= w_over_c_q9;
        w_over_c_minus1_q10 <= w_over_c_minus1_q9;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q10 <= w_over_c_q10;
        w_over_c_minus1_q10 <= w_over_c_minus1_q10;
      end
    end
  end

  // Stage 11
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q11 <= '0;
      w_over_c_minus1_q11 <= '0;
    end else begin
      if (valid_q10) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q11 <= w_over_c_q10;
        w_over_c_minus1_q11 <= w_over_c_minus1_q10;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q11 <= w_over_c_q11;
        w_over_c_minus1_q11 <= w_over_c_minus1_q11;
      end
    end
  end

  // Stage 12
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q12 <= '0;
      w_over_c_minus1_q12 <= '0;
    end else begin
      if (valid_q11) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q12 <= w_over_c_q11;
        w_over_c_minus1_q12 <= w_over_c_minus1_q11;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q12 <= w_over_c_q12;
        w_over_c_minus1_q12 <= w_over_c_minus1_q12;
      end
    end
  end

  // Stage 13
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q13 <= '0;
      w_over_c_minus1_q13 <= '0;
    end else begin
      if (valid_q12) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q13 <= w_over_c_q12;
        w_over_c_minus1_q13 <= w_over_c_minus1_q12;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q13 <= w_over_c_q13;
        w_over_c_minus1_q13 <= w_over_c_minus1_q13;
      end
    end
  end

  // Stage 14
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q14 <= '0;
      w_over_c_minus1_q14 <= '0;
    end else begin
      if (valid_q13) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q14 <= w_over_c_q13;
        w_over_c_minus1_q14 <= w_over_c_minus1_q13;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q14 <= w_over_c_q14;
        w_over_c_minus1_q14 <= w_over_c_minus1_q14;
      end
    end
  end

  // Stage 15 (final non-restoring step, then error correction and ratio finalization)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rema <= '0;
      quo <= '0;
      w_over_c_q15 <= '0;
      w_over_c_minus1_q15 <= '0;
      d_final <= '0;
      w_final <= '0;
      c_final <= '0;
      zero_final <= 1'b0;
    end else begin
      if (valid_q14) begin
        if (rema[16] == 1'b0) begin
          rema <= {1'b0, rema[15:0]} - {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b1};
        end else begin
          rema <= {1'b0, rema[15:0]} + {1'b0, c_safe_q0};
          quo <= {quo[22:0], 1'b0};
        end
        w_over_c_q15 <= w_over_c_q14;
        w_over_c_minus1_q15 <= w_over_c_minus1_q14;
        d_final <= d_q0; // carry forward D for the final compute stage
        w_final <= w_q0;
        c_final <= c_q0;
        // If divisor was zero at input, we consider the zero case
        zero_final <= div_c_zero_q0;
      end else begin
        rema <= rema;
        quo <= quo;
        w_over_c_q15 <= w_over_c_q15;
        w_over_c_minus1_q15 <= w_over_c_minus1_q15;
        d_final <= d_final;
        w_final <= w_final;
        c_final <= c_final;
        zero_final <= zero_final;
      end
    end
  end

  // Final stage: derive corrected W/C (Q8.8) using quotient and remainder correction, then compute base term and result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_over_c_final <= '0;
      w_over_c_minus1_final <= '0;
      base_term_qfinal <= '0;
      amount_qfinal <= '0;
      amount_frac_qfinal <= '0;
      amount_int_qfinal <= '0;
      simple_regime_final <= 1'b0;
    end else begin
      if (valid_q15) begin
        // Build Q8.8 ratio from quotient bits (24 bits) and final remainder
        // rema is 17 bits (sign + 16 fraction), to convert to fractional bits we align 16 fraction bits.
        // remainder in Q8.8 = rema[15:0] / 256 (since we subtracted multiples of c which were in Q0.0)
        // We'll correct quotient by adding +1 if remainder >= (c/2)
        logic [15:0] ratio_int_frac; // Q8.8
        logic [23:0] ratio_int;      // 8 integer bits + 16 fractional bits
        ratio_int = quo; // 24 bits: 8 integer bits (Q8) and 16 fractional bits (for 0.16 fraction part of Q8.8)
        // remainder correction: if rema >= 0 and remainder >= c/2 then add 1 LSB of the 16-bit fraction
        // LSB value in Q8.8 is 1/256. So we compare rema >= (c >> 1)
        if ((rema[16] == 1'b0) && (({1'b0, rema[15:0]} >= (c_safe_q0 >> 1)))) begin
          ratio_int = ratio_int + 24'd1;
        end else if (rema[16] == 1'b1) begin
          // if remainder negative, subtract 1 LSB if |remainder| >= c/2
          if (({1'b0, (~rema[15:0] + 1'b1)} >= (c_safe_q0 >> 1))) begin
            ratio_int = ratio_int - 24'd1;
          end
        end
        // ratio_int is 24-bit Q8.16; take high 16 bits for Q8 to feed base term; full ratio for other uses
        w_over_c_final <= ratio_int[23:8];        // 16-bit Q8
        w_over_c_minus1_final <= (ratio_int[23:8] - 16'd1);

        // Compute base_term = D * (W/C + 2*(W/C - 1)) in Q8.8
        // D is in meters (Q0.0). To multiply in Q8.8, convert D to Q8.8: d_q8 = {8'd0, d_final}
        logic [31:0] d_q8;        // d in Q8.8 (8 integer bits, 8 fractional bits)
        logic [31:0] ratio_q8_8;  // W/C in Q8.8
        logic [31:0] ratio_m1_q8_8;
        logic [31:0] two_m1_q8_8; // 2*(W/C - 1) in Q8.8
        logic [31:0] sum_q8_8;    // (W/C + 2*(W/C - 1)) in Q8.8
        logic [31:0] base_q8_8;   // base_term in Q8.8

        d_q8 = {8'd0, d_final};   // 0 integer bits -> 8 integer bits; fractional 8 bits from zero
        ratio_q8_8 = {8'd0, ratio_int[23:8]}; // W/C Q8 -> Q8.8
        ratio_m1_q8_8 = {8'd0, ratio_int[23:8] - 16'd1};
        two_m1_q8_8 = ratio_m1_q8_8 << 1; // *2, still Q8.8
        sum_q8_8 = ratio_q8_8 + two_m1_q8_8;
        // D * sum, Q8.8 * Q8.8 -> Q16.16, we take high 16 bits for Q8.8 result (saturate to max 16-bit)
        base_q8_8 = ({d_q8[15:0], 8'd0} * {sum_q8_8[15:0], 8'd0}) >> 16; // 32-bit product, result in Q8.8 (16 bits)
        // Clamp to 16-bit max
        if (base_q8_8[31:16] != '0) begin
          base_term_qfinal <= 16'hFFFF;
        end else begin
          base_term_qfinal <= base_q8_8[15:0];
        end

        // Determine the simple regime: W <= C (before the ratio pipeline this was captured)
        simple_regime_final <= w_le_c_final;
      end else begin
        w_over_c_final <= w_over_c_final;
        w_over_c_minus1_final <= w_over_c_minus1_final;
        base_term_qfinal <= base_term_qfinal;
        simple_regime_final <= simple_regime_final;
      end
    end
  end

  // Final compute and output packing (Q24.8)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= '0;
      done <= 1'b0;
    end else begin
      if (valid_final) begin
        // If C==0, deliverable is 0
        if (c_final == 16'd0) begin
          result <= '0;
          done <= 1'b1;
        end else begin
          if (simple_regime_final) begin
            // Simple regime: result = max(0, W - D)
            // W and D are Q0.0; convert to Q8.8 by 8 fractional zeros
            logic signed [31:0] diff_q8_8;
            diff_q8_8 = ($signed({16'd0, w_final}) << 8) - ($signed({16'd0, d_final}) << 8);
            if (diff_q8_8 < 0) begin
              result <= '0;
            end else begin
              result <= {diff_q8_8[23:8], 8'd0}; // diff_q8_8 already Q8.8; pack as Q24.8 (integer=high 16 bits, fraction=low 8 bits)
            end
            done <= 1'b1;
          end else begin
            // Complex regime
            // amount = W - base_term (both Q8.8)
            logic signed [31:0] amt_q8_8;
            logic [7:0] frac8;
            logic [23:0] int24;
            amt_q8_8 = ($signed({16'd0, w_final}) << 8) - $signed({16'd0, base_term_qfinal});
            if (amt_q8_8 < 0) begin
              result <= '0;
            end else begin
              // amt_q8_8 is Q8.8, convert to Q24.8: shift integer part 16 bits left, keep fraction 8 bits
              int24 = {16'd0, amt_q8_8[23:8]}; // ensure it fits 24 bits; clamp if needed
              if (int24 > 24'hFFFFFF) int24 = 24'hFFFFFF;
              frac8 = amt_q8_8[7:0];
              result <= {int24, frac8};
            end
            done <= 1'b1;
          end
        end
      end else begin
        result <= result;
        done <= 1'b0;
      end
    end
  end

endmodule