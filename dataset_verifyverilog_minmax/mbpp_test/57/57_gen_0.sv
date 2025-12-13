module form_largest_number #(
  parameter N = 4,                     // number of digits (1..8)
  parameter MAX_N = 8,                // maximum supported N for unused lanes
  parameter WIDTH = (N*32)/10 + 1     // enough bits to hold max number (>= ceil(N*3.322))
) (
  input [N-1:0][3:0] digits,          // 4-bit BCD digits (0-9)
  output [WIDTH-1:0] max_num          // combined decimal value
);

  function [31:0] clogb2;
    input [31:0] value;
    integer i;
  begin
    clogb2 = 0;
    for (i = 31; i >= 0; i = i - 1) begin
      if (value[i]) begin
        clogb2 = i + 1;
        disable fit;
      end
    end
  end
  endfunction

  function [31:0] pow10 (input [31:0] e);
    integer i;
  begin
    pow10 = 1;
    for (i = 0; i < e; i = i + 1) pow10 = pow10 * 10;
  end
  endfunction

  localparam TOTAL_W = clogb2(10**MAX_N); // enough bits for 10^MAX_N

  // 1) Sort in descending order using a fixed-size sorting network (MAX_N = 8)
  //    - Pad unused lanes with 0 to keep them out of the result
  //    - BCD clamp: values > 9 are treated as 0 to avoid overflow

  logic [MAX_N-1:0][3:0] stage0;
  logic [MAX_N-1:0][3:0] stage1;
  logic [MAX_N-1:0][3:0] stage2;
  logic [MAX_N-1:0][3:0] stage3;
  logic [MAX_N-1:0][3:0] stage4;
  logic [MAX_N-1:0][3:0] stage5;
  logic [MAX_N-1:0][3:0] stage6;
  logic [MAX_N-1:0][3:0] stage7;
  logic [MAX_N-1:0][3:0] stage8;
  logic [MAX_N-1:0][3:0] stage9;
  logic [MAX_N-1:0][3:0] stage10;
  logic [MAX_N-1:0][3:0] stage11;
  logic [MAX_N-1:0][3:0] stage12;
  logic [MAX_N-1:0][3:0] stage13;
  logic [MAX_N-1:0][3:0] stage14;
  logic [MAX_N-1:0][3:0] stage15;
  logic [MAX_N-1:0][3:0] stage16;
  logic [MAX_N-1:0][3:0] stage17;
  logic [MAX_N-1:0][3:0] stage18;
  logic [MAX_N-1:0][3:0] stage19;
  logic [MAX_N-1:0][3:0] sorted;

  // Stage 0: Load inputs, clamp BCD (0..9), pad with 0 for unused lanes
  genvar gi;
  generate
    for (gi = 0; gi < MAX_N; gi = gi + 1) begin : stage0_load
      if (gi < N) begin
        assign stage0[gi] = (digits[gi] <= 4'd9) ? digits[gi] : 4'd0;
      end else begin
        assign stage0[gi] = 4'd0; // unused lanes -> 0
      end
    end
  endgenerate

  // Odd-even transposition sort (combining compare-exchange per stage)
  // Stages 1..8 for MAX_N=8
  assign stage1 = stage0;
  assign stage2 = stage1;
  assign stage3 = stage2;
  assign stage4 = stage3;
  assign stage5 = stage4;
  assign stage6 = stage5;
  assign stage7 = stage6;
  assign stage8 = stage7;

  // Stage 1: compare pairs (0,1), (2,3), (4,5), (6,7) - keep max at even index
  generate for (gi = 0; gi < MAX_N; gi = gi + 2) begin : st1_even
    if (gi+1 < MAX_N) begin
      assign stage1[gi]   = (stage0[gi] >= stage0[gi+1]) ? stage0[gi] : stage0[gi+1];
      assign stage1[gi+1] = (stage0[gi] >= stage0[gi+1]) ? stage0[gi+1] : stage0[gi];
    end else begin
      assign stage1[gi] = stage0[gi];
    end
  end endgenerate

  // Stage 2: compare pairs (1,2), (3,4), (5,6) - keep max at lower index
  generate for (gi = 1; gi < MAX_N-1; gi = gi + 2) begin : st2_odd
    if (gi+1 < MAX_N) begin
      assign stage2[gi]   = (stage1[gi] >= stage1[gi+1]) ? stage1[gi] : stage1[gi+1];
      assign stage2[gi+1] = (stage1[gi] >= stage1[gi+1]) ? stage1[gi+1] : stage1[gi];
    end
  end endgenerate
  // Preserve other indices
  assign stage2[0] = stage1[0];
  if (MAX_N > 1) assign stage2[MAX_N-1] = stage1[MAX_N-1];

  // Stage 3
  generate for (gi = 0; gi < MAX_N; gi = gi + 2) begin : st3_even
    if (gi+1 < MAX_N) begin
      assign stage3[gi]   = (stage2[gi] >= stage2[gi+1]) ? stage2[gi] : stage2[gi+1];
      assign stage3[gi+1] = (stage2[gi] >= stage2[gi+1]) ? stage2[gi+1] : stage2[gi];
    end else begin
      assign stage3[gi] = stage2[gi];
    end
  end endgenerate

  // Stage 4
  generate for (gi = 1; gi < MAX_N-1; gi = gi + 2) begin : st4_odd
    if (gi+1 < MAX_N) begin
      assign stage4[gi]   = (stage3[gi] >= stage3[gi+1]) ? stage3[gi] : stage3[gi+1];
      assign stage4[gi+1] = (stage3[gi] >= stage3[gi+1]) ? stage3[gi+1] : stage3[gi];
    end
  end endgenerate
  assign stage4[0] = stage3[0];
  if (MAX_N > 1) assign stage4[MAX_N-1] = stage3[MAX_N-1];

  // Stage 5
  generate for (gi = 0; gi < MAX_N; gi = gi + 2) begin : st5_even
    if (gi+1 < MAX_N) begin
      assign stage5[gi]   = (stage4[gi] >= stage4[gi+1]) ? stage4[gi] : stage4[gi+1];
      assign stage5[gi+1] = (stage4[gi] >= stage4[gi+1]) ? stage4[gi+1] : stage4[gi];
    end else begin
      assign stage5[gi] = stage4[gi];
    end
  end endgenerate

  // Stage 6
  generate for (gi = 1; gi < MAX_N-1; gi = gi + 2) begin : st6_odd
    if (gi+1 < MAX_N) begin
      assign stage6[gi]   = (stage5[gi] >= stage5[gi+1]) ? stage5[gi] : stage5[gi+1];
      assign stage6[gi+1] = (stage5[gi] >= stage5[gi+1]) ? stage5[gi+1] : stage5[gi];
    end
  end endgenerate
  assign stage6[0] = stage5[0];
  if (MAX_N > 1) assign stage6[MAX_N-1] = stage5[MAX_N-1];

  // Stage 7
  generate for (gi = 0; gi < MAX_N; gi = gi + 2) begin : st7_even
    if (gi+1 < MAX_N) begin
      assign stage7[gi]   = (stage6[gi] >= stage6[gi+1]) ? stage6[gi] : stage6[gi+1];
      assign stage7[gi+1] = (stage6[gi] >= stage6[gi+1]) ? stage6[gi+1] : stage6[gi];
    end else begin
      assign stage7[gi] = stage6[gi];
    end
  end endgenerate

  // Stage 8
  generate for (gi = 1; gi < MAX_N-1; gi = gi + 2) begin : st8_odd
    if (gi+1 < MAX_N) begin
      assign stage8[gi]   = (stage7[gi] >= stage7[gi+1]) ? stage7[gi] : stage7[gi+1];
      assign stage8[gi+1] = (stage7[gi] >= stage7[gi+1]) ? stage7[gi+1] : stage7[gi];
    end
  end endgenerate
  assign stage8[0] = stage7[0];
  if (MAX_N > 1) assign stage8[MAX_N-1] = stage7[MAX_N-1];

  // Keep advancing through remaining stages unchanged to balance depth (for MAX_N=8)
  assign stage9  = stage8;
  assign stage10 = stage9;
  assign stage11 = stage10;
  assign stage12 = stage11;
  assign stage13 = stage12;
  assign stage14 = stage13;
  assign stage15 = stage14;
  assign stage16 = stage15;
  assign stage17 = stage16;
  assign stage18 = stage17;
  assign stage19 = stage18;

  // Sorted result (descending) for first N positions
  assign sorted = stage19;

  // 2) Power-of-10 constants (10^(N-1-i)) for i in [0, N-1]
  logic [31:0] weight [N];
  genvar gi2;
  generate
    for (gi2 = 0; gi2 < N; gi2 = gi2 + 1) begin : gen_weights
      assign weight[gi2] = pow10(N - 1 - gi2);
    end
  endgenerate

  // 3) Multiply-accumulate: max_num = sum(sorted[i] * weight[i])
  //    Weight*TOTAL_W bits, accumulate on WIDTH bits
  logic [TOTAL_W-1:0] term [N];
  logic [TOTAL_W-1:0] acc;
  integer k;

  generate for (gi = 0; gi < N; gi = gi + 1) begin : gen_terms
    assign term[gi] = {TOTAL_W{1'b0}}; // avoid x-propagation on unsized assignment
    assign term[gi] = (sorted[gi] * weight[gi]);
  end endgenerate

  always_comb begin
    acc = {TOTAL_W{1'b0}};
    for (k = 0; k < N; k = k + 1) begin
      acc = acc + term[k];
    end
  end

  // Truncate/extend to the required WIDTH
  assign max_num = (WIDTH > TOTAL_W) ? {acc, {WIDTH - TOTAL_W{1'b0}}} : acc[WIDTH-1:0];

endmodule
