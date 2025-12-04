module cone_lsa(
  input clk,
  input rst_n,
  input start,
  input [31:0] r_q16,
  input [31:0] h_q16,
  output reg [31:0] lsa_q16,
  output reg done
);

// Q16.16 constants
localparam PI_Q16 = 32'h03243F; // 3.141586 in Q16.16 (0x3243F)

// Multiplication pipeline (2-cycle latency)
// Returns high 32 bits (Q16.16 * Q16.16 -> Q32.32, keep high 32 bits)
function [31:0] mul_q16_q16_q16;
  input [31:0] a;
  input [31:0] b;
  reg [63:0] prod;
  begin
    prod = $signed(a) * $signed(b);
    mul_q16_q16_q16 = prod[63:32]; // keep high 32 bits (Q16.16 result)
  end
endfunction

// Non-restoring digit-by-digit square root, 5-cycle latency
// Input radicand in Q32.32 (as two 32-bit parts hi:lo), output sqrt in Q16.16
function [31:0] sqrt_q32_q16;
  input [31:0] rad_hi;
  input [31:0] rad_lo;
  reg [65:0] rem;  // accumulator
  reg [31:0] root;
  reg [31:0] rem_save;
  integer i;
  begin
    // Normalize radicand so that bit 63 is 1 (if not zero)
    if (rad_hi == 0 && rad_lo == 0) begin
      rem = 0;
    end else begin
      if (rad_hi[31]) begin
        rem = {rad_hi, 2'b00};
      end else begin
        rem = {rad_hi, 2'b00} - {1'b0, rad_hi, 2'b00};
        if (rem[65]) begin
          rem = {rad_hi, 2'b00};
        end else begin
          rem = rem << 1;
          rem[0] = 1'b1;
        end
      end
    end

    root = 0;
    rem_save = rem[65:34];
    rem = {rem_save, 32'b0};

    for (i = 0; i < 16; i = i + 1) begin
      // Trial subtraction: 4*root+1 at position 2*i
      if (rem[65]) begin
        rem = rem + ({root, 3'b001});
      end else begin
        rem = rem - ({root, 3'b001});
      end
      root = {root, 1'b0};
      if (!rem[65]) begin
        root[0] = 1;
      end
      rem = rem << 2;
    end

    sqrt_q32_q16 = root; // Q16.16
  end
endfunction

// Pipeline state (single launch, strictly timed to ensure done in 12 cycles)
// We perform all computation with a fixed timing relative to start.
reg start_d1, start_d2, start_d3, start_d4, start_d5, start_d6, start_d7, start_d8, start_d9, start_d10, start_d11;
reg start_sqrt, start_mul1, start_mul2, start_mul3;

// Cycle 0: sample inputs
reg [31:0] r0, h0;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    r0 <= 0; h0 <= 0;
  end else if (start) begin
    r0 <= r_q16;
    h0 <= h_q16;
  end
end

// Cycle 1: r^2 and h^2 (2-cycle mult)
reg [31:0] r2_1, h2_1;
reg r2_1_v, h2_1_v;
wire [31:0] r2_1_o = mul_q16_q16_q16(r0, r0);
wire [31:0] h2_1_o = mul_q16_q16_q16(h0, h0);
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    r2_1 <= 0; h2_1 <= 0;
    r2_1_v <= 0; h2_1_v <= 0;
  end else begin
    r2_1 <= r2_1_o;
    h2_1 <= h2_1_o;
    r2_1_v <= start;
    h2_1_v <= start;
  end
end

// Cycle 2: sum = r^2 + h^2
reg [31:0] sum_q32_hi2, sum_q32_lo2;
reg sum_v2;
wire [31:0] sum_q32_hi2_w = r2_1 + h2_1; // hi part of Q32.32
wire [31:0] sum_q32_lo2_w = 0;           // lo part is 0 (r^2 and h^2 are Q16.16)
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sum_q32_hi2 <= 0; sum_q32_lo2 <= 0; sum_v2 <= 0;
  end else begin
    sum_q32_hi2 <= sum_q32_hi2_w;
    sum_q32_lo2 <= sum_q32_lo2_w;
    sum_v2 <= r2_1_v; // gated by valid
  end
end

// Cycle 3: sqrt input formed
reg [31:0] rad_hi3, rad_lo3;
reg sqrt_v3;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    rad_hi3 <= 0; rad_lo3 <= 0; sqrt_v3 <= 0;
  end else begin
    rad_hi3 <= sum_q32_hi2;
    rad_lo3 <= sum_q32_lo2;
    sqrt_v3 <= sum_v2;
  end
end

// Cycle 4: sqrt stage 1 (normalize)
reg [31:0] rad_hi4, rad_lo4;
reg sqrt_v4;
reg [65:0] rem4;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    rad_hi4 <= 0; rad_lo4 <= 0; sqrt_v4 <= 0; rem4 <= 0;
  end else begin
    rad_hi4 <= rad_hi3;
    rad_lo4 <= rad_lo3;
    sqrt_v4 <= sqrt_v3;
    if (rad_hi3 == 0 && rad_lo3 == 0) begin
      rem4 <= 0;
    end else begin
      if (rad_hi3[31]) begin
        rem4 <= {rad_hi3, 2'b00};
      end else begin
        rem4 <= ({rad_hi3, 2'b00} - {1'b0, rad_hi3, 2'b00}) << 1;
        if (rem4[65]) begin
          rem4 <= {rad_hi3, 2'b00};
        end else begin
          rem4[0] <= 1'b1;
        end
      end
    end
  end
end

// Cycle 5: sqrt stage 2 (init remainder and root)
reg [31:0] root5;
reg [65:0] rem5;
reg sqrt_v5;
reg [31:0] rem_save5;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    root5 <= 0; rem5 <= 0; rem_save5 <= 0; sqrt_v5 <= 0;
  end else begin
    sqrt_v5 <= sqrt_v4;
    rem_save5 <= rem4[65:34];
    rem5 <= {rem_save5, 32'b0};
    root5 <= 0;
  end
end

// Cycle 6: sqrt stage 3 (iter 0..3)
reg [31:0] root6;
reg [65:0] rem6;
reg sqrt_v6;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    root6 <= 0; rem6 <= 0; sqrt_v6 <= 0;
  end else begin
    sqrt_v6 <= sqrt_v5;
    root6 <= root5;
    rem6 <= rem5;
    // four iterations
    if (rem6[65]) rem6 = rem6 + ({root6, 3'b001});
    else          rem6 = rem6 - ({root6, 3'b001});
    root6 = {root6, 1'b0};
    if (!rem6[65]) root6[0] = 1;
    rem6 = {rem6[63:0], 2'b0};

    if (rem6[65]) rem6 = rem6 + ({root6, 3'b001});
    else          rem6 = rem6 - ({root6, 3'b001});
    root6 = {root6, 1'b0};
    if (!rem6[65]) root6[0] = 1;
    rem6 = {rem6[63:0], 2'b0};

    if (rem6[65]) rem6 = rem6 + ({root6, 3'b001});
    else          rem6 = rem6 - ({root6, 3'b001});
    root6 = {root6, 1'b0};
    if (!rem6[65]) root6[0] = 1;
    rem6 = {rem6[63:0], 2'b0};

    if (rem6[65]) rem6 = rem6 + ({root6, 3'b001});
    else          rem6 = rem6 - ({root6, 3'b001});
    root6 = {root6, 1'b0};
    if (!rem6[65]) root6[0] = 1;
    rem6 = {rem6[63:0], 2'b0};
  end
end

// Cycle 7: sqrt stage 4 (iter 4..7)
reg [31:0] root7;
reg [65:0] rem7;
reg sqrt_v7;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    root7 <= 0; rem7 <= 0; sqrt_v7 <= 0;
  end else begin
    sqrt_v7 <= sqrt_v6;
    root7 <= root6;
    rem7 <= rem6;
    // four iterations
    if (rem7[65]) rem7 = rem7 + ({root7, 3'b001});
    else          rem7 = rem7 - ({root7, 3'b001});
    root7 = {root7, 1'b0};
    if (!rem7[65]) root7[0] = 1;
    rem7 = {rem7[63:0], 2'b0};

    if (rem7[65]) rem7 = rem7 + ({root7, 3'b001});
    else          rem7 = rem7 - ({root7, 3'b001});
    root7 = {root7, 1'b0};
    if (!rem7[65]) root7[0] = 1;
    rem7 = {rem7[63:0], 2'b0};

    if (rem7[65]) rem7 = rem7 + ({root7, 3'b001});
    else          rem7 = rem7 - ({root7, 3'b001});
    root7 = {root7, 1'b0};
    if (!rem7[65]) root7[0] = 1;
    rem7 = {rem7[63:0], 2'b0};

    if (rem7[65]) rem7 = rem7 + ({root7, 3'b001});
    else          rem7 = rem7 - ({root7, 3'b001});
    root7 = {root7, 1'b0};
    if (!rem7[65]) root7[0] = 1;
    rem7 = {rem7[63:0], 2'b0};
  end
end

// Cycle 8: sqrt stage 5 (iter 8..11 + finalize) -> sqrt ready
reg [31:0] sqrt8;
reg sqrt_v8;
reg [31:0] root8;
reg [65:0] rem8;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sqrt8 <= 0; sqrt_v8 <= 0; root8 <= 0; rem8 <= 0;
  end else begin
    sqrt_v8 <= sqrt_v7;
    root8 <= root7;
    rem8 <= rem7;
    // four iterations
    if (rem8[65]) rem8 = rem8 + ({root8, 3'b001});
    else          rem8 = rem8 - ({root8, 3'b001});
    root8 = {root8, 1'b0};
    if (!rem8[65]) root8[0] = 1;
    rem8 = {rem8[63:0], 2'b0};

    if (rem8[65]) rem8 = rem8 + ({root8, 3'b001});
    else          rem8 = rem8 - ({root8, 3'b001});
    root8 = {root8, 1'b0};
    if (!rem8[65]) root8[0] = 1;
    rem8 = {rem8[63:0], 2'b0};

    if (rem8[65]) rem8 = rem8 + ({root8, 3'b001});
    else          rem8 = rem8 - ({root8, 3'b001});
    root8 = {root8, 1'b0};
    if (!rem8[65]) root8[0] = 1;
    rem8 = {rem8[63:0], 2'b0};

    if (rem8[65]) rem8 = rem8 + ({root8, 3'b001});
    else          rem8 = rem8 - ({root8, 3'b001});
    root8 = {root8, 1'b0};
    if (!rem8[65]) root8[0] = 1;
    rem8 = {rem8[63:0], 2'b0};
    sqrt8 <= root8; // Q16.16
  end
end

// Start signals for the 2-cycle multiplications with timing aligned to pipeline
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    start_d1 <= 0; start_d2 <= 0; start_d3 <= 0; start_d4 <= 0;
    start_d5 <= 0; start_d6 <= 0; start_d7 <= 0; start_d8 <= 0;
    start_d9 <= 0; start_d10 <= 0; start_d11 <= 0;
    start_sqrt <= 0; start_mul1 <= 0; start_mul2 <= 0; start_mul3 <= 0;
  end else begin
    start_d1 <= start;
    start_d2 <= start_d1;
    start_d3 <= start_d2;
    start_d4 <= start_d3;
    start_d5 <= start_d4;
    start_d6 <= start_d5;
    start_d7 <= start_d6;
    start_d8 <= start_d7;
    start_d9 <= start_d8;
    start_d10 <= start_d9;
    start_d11 <= start_d10;
    start_sqrt <= start_d2; // for gating sqrt_valid
    start_mul1 <= start_d7; // start PI * sqrt at cycle 8 -> ready at cycle 10
    start_mul2 <= start_d8; // start r * t1 at cycle 9 -> ready at cycle 11
    start_mul3 <= start_d9; // start r * t1 at cycle 10 -> ready at cycle 12
  end
end

// Cycle 8: PI * sqrt
reg [31:0] t1_10, t1_v10;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    t1_10 <= 0; t1_v10 <= 0;
  end else begin
    t1_10 <= mul_q16_q16_q16(PI_Q16, sqrt8);
    t1_v10 <= start_mul1 && sqrt_v8;
  end
end

// Cycle 9: r * t1 (two-cycle mult)
reg [31:0] t2_11, t2_v11;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    t2_11 <= 0; t2_v11 <= 0;
  end else begin
    t2_11 <= mul_q16_q16_q16(r0, t1_10);
    t2_v11 <= start_mul2 && t1_v10;
  end
end

// Cycle 10: r * t1 (duplicate path to be latched at cycle 12)
reg [31:0] t2_12, t2_v12;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    t2_12 <= 0; t2_v12 <= 0;
  end else begin
    t2_12 <= mul_q16_q16_q16(r0, t1_10);
    t2_v12 <= start_mul3 && t1_v10;
  end
end

// Output and done: latch at cycle 12
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    lsa_q16 <= 0;
    done <= 0;
  end else begin
    // Choose the result that arrives in cycle 12 (start_mul3 path)
    if (t2_v12) lsa_q16 <= t2_12; // Q16.16 result
    done <= start_d11 && t2_v12; // assert done when result is valid
  end
end

endmodule