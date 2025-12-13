module cone_lsa(
  input  clk,
  input  rst_n,
  input  start,
  input  [31:0] r_q16,
  input  [31:0] h_q16,
  output reg [31:0] lsa_q16,
  output reg done
);

  // Constants
  // pi in Q16.16: 3.141586 * 65536 ≈ 205887 (0x0003243F)
  localparam [31:0] PI_Q16 = 32'h0003243F;

  // ---------------------------------------------------------------------------
  // Control: 12-cycle fixed-latency from start to done
  // ---------------------------------------------------------------------------
  reg [3:0] cycle_cnt;
  reg       start_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 4'd0;
      start_d   <= 1'b0;
      done      <= 1'b0;
    end else begin
      start_d <= start;

      if (start && !start_d) begin
        // Rising edge of start: initialize counter
        cycle_cnt <= 4'd1;
        done      <= 1'b0;
      end else if (cycle_cnt != 4'd0) begin
        cycle_cnt <= cycle_cnt + 4'd1;
        if (cycle_cnt == 4'd11) begin
          done      <= 1'b1; // 12th cycle after start
        end else begin
          done      <= 1'b0;
        end
        if (cycle_cnt == 4'd12) begin
          cycle_cnt <= 4'd0; // ready for next start
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Pipeline registers and datapath
  // Latency map (relative to start edge):
  //  C1-2: r^2
  //  C3-4: h^2
  //  C5:   sum = r^2 + h^2
  //  C6-10: sqrt(sum) via 5-cycle non-restoring (stubbed as pipeline)
  //  C11-12: r * sqrt_term, then * pi
  // Result latched at C12, done asserted
  // ---------------------------------------------------------------------------

  // Stage 0: latch inputs on start
  reg        v_s0;
  reg [31:0] r_s0, h_s0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_s0 <= 1'b0;
      r_s0 <= 32'd0;
      h_s0 <= 32'd0;
    end else begin
      if (start && !start_d) begin
        v_s0 <= 1'b1;
        r_s0 <= r_q16;
        h_s0 <= h_q16;
      end else if (cycle_cnt == 4'd0) begin
        v_s0 <= 1'b0;
      end
    end
  end

  // ------------------------
  // 32x32 -> 64 pipelined multiplier #1 for r^2 and h^2
  // latency: 2 cycles
  // ------------------------
  reg        m1_v_s1, m1_v_s2;
  reg [31:0] m1_a_s1, m1_b_s1;
  reg [63:0] m1_p_s2;

  // Control which operand to square based on cycle
  // C1-2: r^2; C3-4: h^2
  wire use_r_sq = (cycle_cnt == 4'd1) || (cycle_cnt == 4'd2);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m1_v_s1 <= 1'b0;
      m1_v_s2 <= 1'b0;
      m1_a_s1 <= 32'd0;
      m1_b_s1 <= 32'd0;
      m1_p_s2 <= 64'd0;
    end else begin
      // Stage 1
      if (v_s0 && (cycle_cnt == 4'd1 || cycle_cnt == 4'd3)) begin
        if (use_r_sq)
          {m1_a_s1, m1_b_s1} <= {r_s0, r_s0};
        else
          {m1_a_s1, m1_b_s1} <= {h_s0, h_s0};
        m1_v_s1 <= 1'b1;
      end else begin
        m1_v_s1 <= 1'b0;
      end

      // Stage 2
      m1_v_s2 <= m1_v_s1;
      if (m1_v_s1)
        m1_p_s2 <= m1_a_s1 * m1_b_s1;
    end
  end

  // Capture r^2 and h^2 from m1_p_s2
  reg        v_r2_s3, v_h2_s5;
  reg [63:0] r2_s3;
  reg [63:0] h2_s5;

  // r^2 available at cycle 3 (from request at C1)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_r2_s3 <= 1'b0;
      r2_s3   <= 64'd0;
    end else begin
      if (m1_v_s2 && use_r_sq) begin
        v_r2_s3 <= 1'b1;
        r2_s3   <= m1_p_s2;
      end else if (cycle_cnt == 4'd0) begin
        v_r2_s3 <= 1'b0;
      end
    end
  end

  // h^2 available at cycle 5 (from request at C3)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_h2_s5 <= 1'b0;
      h2_s5   <= 64'd0;
    end else begin
      if (m1_v_s2 && !use_r_sq) begin
        v_h2_s5 <= 1'b1;
        h2_s5   <= m1_p_s2;
      end else if (cycle_cnt == 4'd0) begin
        v_h2_s5 <= 1'b0;
      end
    end
  end

  // ------------------------
  // Sum: r^2 + h^2 (Q32.32)
  // r^2, h^2 each are (Q16.16)^2 -> Q32.32 in 64-bit
  // ------------------------
  reg        v_sum_s6;
  reg [63:0] sum_s6;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_sum_s6 <= 1'b0;
      sum_s6   <= 64'd0;
    end else begin
      if (v_r2_s3 && v_h2_s5 && cycle_cnt >= 4'd5) begin
        // align when both are ready; simple direct use
        v_sum_s6 <= 1'b1;
        sum_s6   <= r2_s3 + h2_s5;
      end else if (cycle_cnt == 4'd0) begin
        v_sum_s6 <= 1'b0;
      end
    end
  end

  // ------------------------
  // 5-cycle non-restoring sqrt approximation block
  // Input: sum_s6 (Q32.32), Output: slant_s (approx sqrt in Q16.16)
  // Here implemented as a 5-stage registered passthrough placeholder
  // with combinational sqrt for illustration (tool can replace).
  // ------------------------
  reg        v_sqrt_s[0:5];
  reg [63:0] sum_pipe_s[0:5];
  integer i;

  // Stage 0 load
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i <= 5; i = i + 1) begin
        v_sqrt_s[i]   <= 1'b0;
        sum_pipe_s[i] <= 64'd0;
      end
    end else begin
      // shift pipeline
      for (i = 5; i > 0; i = i - 1) begin
        v_sqrt_s[i]   <= v_sqrt_s[i-1];
        sum_pipe_s[i] <= sum_pipe_s[i-1];
      end
      // load new input at stage0
      if (v_sum_s6) begin
        v_sqrt_s[0]   <= 1'b1;
        sum_pipe_s[0] <= sum_s6;
      end else begin
        v_sqrt_s[0]   <= 1'b0;
      end
    end
  end

  // Combinational sqrt from final pipeline stage (non-restoring stub)
  reg [31:0] slant_q16_s11;
  always @(*) begin
    // Convert Q32.32 (64-bit) to real-like magnitude by integer sqrt on upper bits
    // Take top 32 bits as integer for approximation
    // sqrt_int in 16.16 form: sqrt(sum_pipe_s[5][63:32]) << 16
    // Simple integer sqrt (non-optimized) for synthesis-safe stub
    integer k;
    reg [31:0] x;
    reg [31:0] res;
    x   = sum_pipe_s[5][63:32];
    res = 0;
    for (k = 15; k >= 0; k = k - 1) begin
      if ((res | (32'd1 << k)) * (res | (32'd1 << k)) <= x)
        res = res | (32'd1 << k);
    end
    slant_q16_s11 = res << 16; // Q16.16
  end

  wire        v_slant_s11 = v_sqrt_s[5];

  // ------------------------
  // Multiplier #2: r * slant (2 cycles)
  // ------------------------
  reg        m2_v_s1, m2_v_s2;
  reg [31:0] m2_a_s1, m2_b_s1;
  reg [63:0] r_slant_s2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m2_v_s1   <= 1'b0;
      m2_v_s2   <= 1'b0;
      m2_a_s1   <= 32'd0;
      m2_b_s1   <= 32'd0;
      r_slant_s2 <= 64'd0;
    end else begin
      // Stage1: load when slant ready
      if (v_slant_s11) begin
        m2_v_s1 <= 1'b1;
        m2_a_s1 <= r_s0;          // original r in Q16.16
        m2_b_s1 <= slant_q16_s11; // Q16.16
      end else begin
        m2_v_s1 <= 1'b0;
      end

      // Stage2
      m2_v_s2 <= m2_v_s1;
      if (m2_v_s1)
        r_slant_s2 <= m2_a_s1 * m2_b_s1; // Q32.32
    end
  end

  // ------------------------
  // Multiplier #3: (r*slant) * pi (2 cycles)
  // ------------------------
  reg        m3_v_s1, m3_v_s2;
  reg [63:0] m3_a_s1;
  reg [31:0] m3_b_s1;
  reg [95:0] m3_p_s2; // 64x32 -> 96 bits

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      m3_v_s1 <= 1'b0;
      m3_v_s2 <= 1'b0;
      m3_a_s1 <= 64'd0;
      m3_b_s1 <= 32'd0;
      m3_p_s2 <= 96'd0;
    end else begin
      // Stage1: when r*slant ready
      if (m2_v_s2) begin
        m3_v_s1 <= 1'b1;
        m3_a_s1 <= r_slant_s2; // Q32.32
        m3_b_s1 <= PI_Q16;     // Q16.16
      end else begin
        m3_v_s1 <= 1'b0;
      end

      // Stage2
      m3_v_s2 <= m3_v_s1;
      if (m3_v_s1)
        m3_p_s2 <= m3_a_s1 * m3_b_s1; // Q48.48
    end
  end

  // ------------------------
  // Final scaling to Q16.16 and register output
  // (Q32.32 * Q16.16 = Q48.48; need to shift right by 32 to get Q16.16)
  // ------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lsa_q16 <= 32'd0;
    end else begin
      if (m3_v_s2) begin
        // m3_p_s2 is Q48.48 -> take bits [47:16] for Q32.32 then >>16 => Q16.16
        // Equivalent to >>32 from Q48.48: bits [47:16]
        lsa_q16 <= m3_p_s2[47:16];
      end
    end
  end

endmodule