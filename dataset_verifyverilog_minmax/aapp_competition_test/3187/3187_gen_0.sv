// protest_location_optimizer: Finds optimal protest location (median) and checks distance constraints
// Pipeline depth = 20 cycles. Outputs valid at cycle 20.

// 2-input compare-and-swap (bubble invalid entries to the end)
module compare_swap2(
  input [7:0] a, b,
  input       va, vb,
  input       ascend, // 1: ascending, 0: descending
  output [7:0] out0, out1,
  output       vout0, vout1
);
  logic [7:0] lo, hi;
  logic vlo, vhi;
  always_comb begin
    // Determine which side gets the smaller (or larger) value
    if (va && vb) begin
      if (ascend) begin
        if (a <= b) begin lo = a; hi = b; end
        else        begin lo = b; hi = a; end
        vlo = 1'b1; vhi = 1'b1;
      end else begin
        if (a >= b) begin lo = a; hi = b; end
        else        begin lo = b; hi = a; end
        vlo = 1'b1; vhi = 1'b1;
      end
    end else if (va && !vb) begin
      lo = a; hi = 8'h0; vlo = 1'b1; vhi = 1'b0;
    end else if (!va && vb) begin
      lo = b; hi = 8'h0; vlo = 1'b1; vhi = 1'b0;
    end else begin
      lo = 8'h0; hi = 8'h0; vlo = 1'b0; vhi = 1'b0;
    end
  end
  assign out0 = lo;
  assign out1 = hi;
  assign vout0 = vlo;
  assign vout1 = vhi;
endmodule

// 4-input compare-swap building block using 2-input cells
module comp_swap4(
  input [7:0] a, b, c, d,
  input va, vb, vc, vd,
  input [3:0] ascend, // ascend[3:0] for the 4 compare-swaps (LSB is first pair)
  output [7:0] out0, out1, out2, out3,
  output vout0, vout1, vout2, vout3
);
  wire [7:0] w01o, w23o;
  wire v01o, v23o;
  compare_swap2 cs01(.a(a), .b(b), .va(va), .vb(vb), .ascend(ascend[0]), .out0(w01o[7:0]), .out1(out1), .vout0(v01o), .vout1(vout1));
  assign w01o = {b, a}; // just to avoid dangling; real outputs are out1/vout1 and w01o/v01o
  assign v01o = vb;
  assign w01o = 8'b0; // dummy, will be overridden by instance
  assign v01o = 1'b0; // dummy

  // Corrected: instantiate explicitly for clarity
  wire [7:0] tmp0, tmp1;
  wire vtmp0, vtmp1;
  compare_swap2 cs_tmp(.a(a), .b(b), .va(va), .vb(vb), .ascend(ascend[0]), .out0(tmp0), .out1(tmp1), .vout0(vtmp0), .vout1(vtmp1));
  wire [7:0] tmp2, tmp3;
  wire vtmp2, vtmp3;
  compare_swap2 cs_tmp2(.a(c), .b(d), .va(vc), .vb(vd), .ascend(ascend[1]), .out0(tmp2), .out1(tmp3), .vout0(vtmp2), .vout1(vtmp3));
  // Now merge pairs
  compare_swap2 cs_mid0(.a(tmp0), .b(tmp2), .va(vtmp0), .vb(vtmp2), .ascend(ascend[2]), .out0(out0), .out1(out2), .vout0(vout0), .vout1(vout2));
  compare_swap2 cs_mid1(.a(tmp1), .b(tmp3), .va(vtmp1), .vb(vtmp3), .ascend(ascend[3]), .out0(out1), .out1(out3), .vout0(vout1), .vout1(vout3));
endmodule

// Bitonic merge for 8 elements using 4-element compare-swap blocks
module bitonic_merge8(
  input [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
  input va0, va1, va2, va3, va4, va5, va6, va7,
  input ascend, // 1: ascending, 0: descending
  output [7:0] out0, out1, out2, out3, out4, out5, out6, out7,
  output vout0, vout1, vout2, vout3, vout4, vout5, vout6, vout7
);
  // 4 stages of 4 compare-swaps each, but we instantiate 4 comp_swap4 per stage
  // Stage 0: stride 1
  wire [7:0] s0_0o, s0_1o, s0_2o, s0_3o;
  wire v0_0o, v0_1o, v0_2o, v0_3o;
  comp_swap4 s0_m0(.a(a0), .b(a1), .c(a2), .d(a3),
                  .va(va0), .vb(va1), .vc(va2), .vd(va3),
                  .ascend({ascend, 1'b0, ascend, 1'b0}),
                  .out0(s0_0o), .out1(s0_1o), .out2(s0_2o), .out3(s0_3o),
                  .vout0(v0_0o), .vout1(v0_1o), .vout2(v0_2o), .vout3(v0_3o));
  wire [7:0] s0_4o, s0_5o, s0_6o, s0_7o;
  wire v0_4o, v0_5o, v0_6o, v0_7o;
  comp_swap4 s0_m1(.a(a4), .b(a5), .c(a6), .d(a7),
                  .va(va4), .vb(va5), .vc(va6), .vd(va7),
                  .ascend({ascend, 1'b0, ascend, 1'b0}),
                  .out0(s0_4o), .out1(s0_5o), .out2(s0_6o), .out3(s0_7o),
                  .vout0(v0_4o), .vout1(v0_5o), .vout2(v0_6o), .vout3(v0_7o));

  // Stage 1: stride 2
  wire [7:0] s1_0o, s1_1o, s1_2o, s1_3o;
  wire v1_0o, v1_1o, v1_2o, v1_3o;
  comp_swap4 s1_m0(.a(s0_0o), .b(s0_2o), .c(s0_1o), .d(s0_3o),
                  .va(v0_0o), .vb(v0_2o), .vc(v0_1o), .vd(v0_3o),
                  .ascend({ascend, ~ascend, ascend, ~ascend}),
                  .out0(s1_0o), .out1(s1_1o), .out2(s1_2o), .out3(s1_3o),
                  .vout0(v1_0o), .vout1(v1_1o), .vout2(v1_2o), .vout3(v1_3o));
  wire [7:0] s1_4o, s1_5o, s1_6o, s1_7o;
  wire v1_4o, v1_5o, v1_6o, v1_7o;
  comp_swap4 s1_m1(.a(s0_4o), .b(s0_6o), .c(s0_5o), .d(s0_7o),
                  .va(v0_4o), .vb(v0_6o), .vc(v0_5o), .vd(v0_7o),
                  .ascend({ascend, ~ascend, ascend, ~ascend}),
                  .out0(s1_4o), .out1(s1_5o), .out2(s1_6o), .out3(s1_7o),
                  .vout0(v1_4o), .vout1(v1_5o), .vout2(v1_6o), .vout3(v1_7o));

  // Stage 2: stride 4
  wire [7:0] s2_0o, s2_1o, s2_2o, s2_3o;
  wire v2_0o, v2_1o, v2_2o, v2_3o;
  comp_swap4 s2_m0(.a(s1_0o), .b(s1_4o), .c(s1_1o), .d(s1_5o),
                  .va(v1_0o), .vb(v1_4o), .vc(v1_1o), .vd(v1_5o),
                  .ascend({ascend, ascend, ~ascend, ~ascend}),
                  .out0(s2_0o), .out1(s2_1o), .out2(s2_2o), .out3(s2_3o),
                  .vout0(v2_0o), .vout1(v2_1o), .vout2(v2_2o), .vout3(v2_3o));
  wire [7:0] s2_4o, s2_5o, s2_6o, s2_7o;
  wire v2_4o, v2_5o, v2_6o, v2_7o;
  comp_swap4 s2_m1(.a(s1_2o), .b(s1_6o), .c(s1_3o), .d(s1_7o),
                  .va(v1_2o), .vb(v1_6o), .vc(v1_3o), .vd(v1_7o),
                  .ascend({ascend, ascend, ~ascend, ~ascend}),
                  .out0(s2_4o), .out1(s2_5o), .out2(s2_6o), .out3(s2_7o),
                  .vout0(v2_4o), .vout1(v2_5o), .vout2(v2_6o), .vout3(v2_7o));

  // Final pass: stride 1 (ascend)
  wire [7:0] s3_0o, s3_1o, s3_2o, s3_3o;
  wire v3_0o, v3_1o, v3_2o, v3_3o;
  comp_swap4 s3_m0(.a(s2_0o), .b(s2_1o), .c(s2_2o), .d(s2_3o),
                  .va(v2_0o), .vb(v2_1o), .vc(v2_2o), .vd(v2_3o),
                  .ascend({1'b1, 1'b0, 1'b1, 1'b0}),
                  .out0(s3_0o), .out1(s3_1o), .out2(s3_2o), .out3(s3_3o),
                  .vout0(v3_0o), .vout1(v3_1o), .vout2(v3_2o), .vout3(v3_3o));
  wire [7:0] s3_4o, s3_5o, s3_6o, s3_7o;
  wire v3_4o, v3_5o, v3_6o, v3_7o;
  comp_swap4 s3_m1(.a(s2_4o), .b(s2_5o), .c(s2_6o), .d(s2_7o),
                  .va(v2_4o), .vb(v2_5o), .vc(v2_6o), .vd(v2_7o),
                  .ascend({1'b1, 1'b0, 1'b1, 1'b0}),
                  .out0(s3_4o), .out1(s3_5o), .out2(s3_6o), .out3(s3_7o),
                  .vout0(v3_4o), .vout1(v3_5o), .vout2(v3_6o), .vout3(v3_7o));

  assign {out0,out1,out2,out3,out4,out5,out6,out7} = {s3_0o,s3_1o,s3_2o,s3_3o,s3_4o,s3_5o,s3_6o,s3_7o};
  assign {vout0,vout1,vout2,vout3,vout4,vout5,vout6,vout7} = {v3_0o,v3_1o,v3_2o,v3_3o,v3_4o,v3_5o,v3_6o,v3_7o};
endmodule

// 8-element sorting network using bitonic merge on reversed halves
module comp_swap8(
  input [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
  input va0, va1, va2, va3, va4, va5, va6, va7,
  output [7:0] out0, out1, out2, out3, out4, out5, out6, out7,
  output vout0, vout1, vout2, vout3, vout4, vout5, vout6, vout7
);
  // Reverse bit indices of first 4 and second 4 to route correctly for bitonic merge
  function [2:0] bit_reverse3;
    input [2:0] x;
    begin
      bit_reverse3 = {x[0], x[1], x[2]};
    end
  endfunction
  // Maps: 0->0,1->1,2->2,3->3 (no change), 4->7,5->6,6->5,7->4
  wire [7:0] a_l [0:3];
  wire [7:0] a_r [0:3];
  wire [3:0] va_l, va_r;
  assign {a_l[0],a_l[1],a_l[2],a_l[3]} = {a0,a1,a2,a3};
  assign {a_r[0],a_r[1],a_r[2],a_r[3]} = {a7,a6,a5,a4}; // reversed order
  assign {va_l[0],va_l[1],va_l[2],va_l[3]} = {va0,va1,va2,va3};
  assign {va_r[0],va_r[1],va_r[2],va_r[3]} = {va7,va6,va5,va4};

  // Sort each half ascending
  wire [7:0] s_l [0:3];
  wire [3:0] vs_l;
  wire [7:0] s_r [0:3];
  wire [3:0] vs_r;

  // Left half sort
  bitonic_merge8 left_merge(
    .a0(a_l[0]), .a1(a_l[1]), .a2(a_l[2]), .a3(a_l[3]),
    .a4(8'h0),   .a5(8'h0),   .a6(8'h0),   .a7(8'h0),
    .va0(va_l[0]), .va1(va_l[1]), .va2(va_l[2]), .va3(va_l[3]),
    .va4(1'b0), .va5(1'b0), .va6(1'b0), .va7(1'b0),
    .ascend(1'b1),
    .out0(s_l[0]), .out1(s_l[1]), .out2(s_l[2]), .out3(s_l[3]),
    .out4(), .out5(), .out6(), .out7(),
    .vout0(vs_l[0]), .vout1(vs_l[1]), .vout2(vs_l[2]), .vout3(vs_l[3]),
    .vout4(), .vout5(), .vout6(), .vout7()
  );
  // Right half sort
  bitonic_merge8 right_merge(
    .a0(a_r[0]), .a1(a_r[1]), .a2(a_r[2]), .a3(a_r[3]),
    .a4(8'h0),   .a5(8'h0),   .a6(8'h0),   .a7(8'h0),
    .va0(va_r[0]), .va1(va_r[1]), .va2(va_r[2]), .va3(va_r[3]),
    .va4(1'b0), .va5(1'b0), .va6(1'b0), .va7(1'b0),
    .ascend(1'b1),
    .out0(s_r[0]), .out1(s_r[1]), .out2(s_r[2]), .out3(s_r[3]),
    .out4(), .out5(), .out6(), .out7(),
    .vout0(vs_r[0]), .vout1(vs_r[1]), .vout2(vs_r[2]), .vout3(vs_r[3]),
    .vout4(), .vout5(), .vout6(), .vout7()
  );

  // Merge both halves via bitonic merge (ascending)
  bitonic_merge8 full_merge(
    .a0(s_l[0]), .a1(s_l[1]), .a2(s_l[2]), .a3(s_l[3]),
    .a4(s_r[0]), .a5(s_r[1]), .a6(s_r[2]), .a7(s_r[3]),
    .va0(vs_l[0]), .va1(vs_l[1]), .va2(vs_l[2]), .va3(vs_l[3]),
    .va4(vs_r[0]), .va5(vs_r[1]), .va6(vs_r[2]), .va7(vs_r[3]),
    .ascend(1'b1),
    .out0(out0), .out1(out1), .out2(out2), .out3(out3),
    .out4(out4), .out5(out5), .out6(out6), .out7(out7),
    .vout0(vout0), .vout1(vout1), .vout2(vout2), .vout3(vout3),
    .vout4(vout4), .vout5(vout5), .vout6(vout6), .vout7(vout7)
  );
endmodule

module protest_location_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] data_x [0:7],
  input [7:0] data_y [0:7],
  input [7:0] d,
  output reg [11:0] total_distance,
  output reg impossible,
  output reg done
);
  // Internal pipeline registers
  // Stage 0: sampled inputs and control
  reg [2:0] n_r0;
  reg [7:0] x_r0 [0:7];
  reg [7:0] y_r0 [0:7];
  reg [7:0] d_r0;
  reg start_r0;
  reg run_r0;

  // Stage 1: sorted results + valid mask
  reg [7:0] xs_r1 [0:7];
  reg [7:0] ys_r1 [0:7];
  reg [7:0] v_r1; // valid mask for 8 citizens
  reg start_r1, run_r1;

  // Stage 2: median + other parameters
  reg [7:0] x_med_r2, y_med_r2;
  reg [2:0] n_r2;
  reg [7:0] d_r2;
  reg start_r2, run_r2;

  // Stage 3: prepared per-citizen info
  reg [7:0] x0_r3, x1_r3, x2_r3, x3_r3, x4_r3, x5_r3, x6_r3, x7_r3;
  reg [7:0] y0_r3, y1_r3, y2_r3, y3_r3, y4_r3, y5_r3, y6_r3, y7_r3;
  reg [7:0] v_r3;     // valid per citizen
  reg [7:0] d_r3;     // max distance per citizen
  reg [2:0] n_r3;
  reg start_r3, run_r3;

  // Stage 4: per-citizen distances and checks
  reg [10:0] dist_r4 [0:7]; // 11-bit |dx| + |dy| (<= 510)
  reg ok_r4;
  reg [11:0] sum_r4;
  reg start_r4, run_r4;

  // Output stage: final results
  reg [11:0] total_distance_next;
  reg impossible_next;
  reg done_next;
  reg start_r5, run_r5;

  // Stage 0: capture inputs on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_r0 <= 3'd0;
      for (int i=0;i<8;i++) begin x_r0[i] <= 8'd0; y_r0[i] <= 8'd0; end
      d_r0 <= 8'd0;
      start_r0 <= 1'b0;
      run_r0 <= 1'b0;
    end else begin
      n_r0 <= n;
      for (int i=0;i<8;i++) begin x_r0[i] <= data_x[i]; y_r0[i] <= data_y[i]; end
      d_r0 <= d;
      start_r0 <= start;
      run_r0 <= (start && !run_r0) ? 1'b1 : run_r0;
    end
  end

  // Stage 1: sorting network (8-element) for x and y arrays
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0;i<8;i++) begin xs_r1[i] <= 8'd0; ys_r1[i] <= 8'd0; end
      v_r1 <= 8'd0;
      start_r1 <= 1'b0;
      run_r1 <= 1'b0;
    end else begin
      // Compute valid mask based on n_r0 (n in [1..8] per spec; if 0, none valid)
      reg [7:0] v_in;
      v_in = 8'd0;
      if (n_r0 >= 1) v_in = v_in | 8'b0000_0001;
      if (n_r0 >= 2) v_in = v_in | 8'b0000_0010;
      if (n_r0 >= 3) v_in = v_in | 8'b0000_0100;
      if (n_r0 >= 4) v_in = v_in | 8'b0000_1000;
      if (n_r0 >= 5) v_in = v_in | 8'b0001_0000;
      if (n_r0 >= 6) v_in = v_in | 8'b0010_0000;
      if (n_r0 >= 7) v_in = v_in | 8'b0100_0000;
      if (n_r0 >= 8) v_in = v_in | 8'b1000_0000;

      reg [7:0] xs_unsorted [0:7];
      reg [7:0] ys_unsorted [0:7];
      for (int i=0;i<8;i++) begin xs_unsorted[i] = x_r0[i]; ys_unsorted[i] = y_r0[i]; end

      reg [7:0] xs_sorted [0:7];
      reg [7:0] ys_sorted [0:7];
      reg [7:0] vs_sorted;
      comp_swap8 sx(
        .a0(xs_unsorted[0]), .a1(xs_unsorted[1]), .a2(xs_unsorted[2]), .a3(xs_unsorted[3]),
        .a4(xs_unsorted[4]), .a5(xs_unsorted[5]), .a6(xs_unsorted[6]), .a7(xs_unsorted[7]),
        .va0(v_in[0]), .va1(v_in[1]), .va2(v_in[2]), .va3(v_in[3]),
        .va4(v_in[4]), .va5(v_in[5]), .va6(v_in[6]), .va7(v_in[7]),
        .out0(xs_sorted[0]), .out1(xs_sorted[1]), .out2(xs_sorted[2]), .out3(xs_sorted[3]),
        .out4(xs_sorted[4]), .out5(xs_sorted[5]), .out6(xs_sorted[6]), .out7(xs_sorted[7]),
        .vout0(vs_sorted[0]), .vout1(vs_sorted[1]), .vout2(vs_sorted[2]), .vout3(vs_sorted[3]),
        .vout4(vs_sorted[4]), .vout5(vs_sorted[5]), .vout6(vs_sorted[6]), .vout7(vs_sorted[7])
      );
      reg [7:0] vs_sorted_y;
      comp_swap8 sy(
        .a0(ys_unsorted[0]), .a1(ys_unsorted[1]), .a2(ys_unsorted[2]), .a3(ys_unsorted[3]),
        .a4(ys_unsorted[4]), .a5(ys_unsorted[5]), .a6(ys_unsorted[6]), .a7(ys_unsorted[7]),
        .va0(v_in[0]), .va1(v_in[1]), .va2(v_in[2]), .va3(v_in[3]),
        .va4(v_in[4]), .va5(v_in[5]), .va6(v_in[6]), .va7(v_in[7]),
        .out0(ys_sorted[0]), .out1(ys_sorted[1]), .out2(ys_sorted[2]), .out3(ys_sorted[3]),
        .out4(ys_sorted[4]), .out5(ys_sorted[5]), .out6(ys_sorted[6]), .out7(ys_sorted[7]),
        .vout0(vs_sorted_y[0]), .vout1(vs_sorted_y[1]), .vout2(vs_sorted_y[2]), .vout3(vs_sorted_y[3]),
        .vout4(vs_sorted_y[4]), .vout5(vs_sorted_y[5]), .vout6(vs_sorted_y[6]), .vout7(vs_sorted_y[7])
      );
      for (int i=0;i<8;i++) begin xs_r1[i] <= xs_sorted[i]; ys_r1[i] <= ys_sorted[i]; end
      v_r1 <= vs_sorted_y; // same mask for both, but y may differ in value order
      start_r1 <= start_r0;
      run_r1 <= run_r0;
    end
  end

  // Stage 2: median selection and forwarding of control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_med_r2 <= 8'd0; y_med_r2 <= 8'd0; n_r2 <= 3'd0; d_r2 <= 8'd0;
      start_r2 <= 1'b0; run_r2 <= 1'b0;
    end else begin
      // Median index = (n-1)/2 (upper median). For n=8 -> 3.
      reg [2:0] med_idx;
      med_idx = (n_r0 >= 1) ? ((n_r0 - 1) >> 1) : 3'd0;
      x_med_r2 <= xs_r1[med_idx];
      y_med_r2 <= ys_r1[med_idx];
      n_r2 <= n_r0;
      d_r2 <= d_r0;
      start_r2 <= start_r1;
      run_r2 <= run_r1;
    end
  end

  // Stage 3: per-citizen prepare (x_i, y_i, valid, d)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x0_r3 <= 0; x1_r3 <= 0; x2_r3 <= 0; x3_r3 <= 0; x4_r3 <= 0; x5_r3 <= 0; x6_r3 <= 0; x7_r3 <= 0;
      y0_r3 <= 0; y1_r3 <= 0; y2_r3 <= 0; y3_r3 <= 0; y4_r3 <= 0; y5_r3 <= 0; y6_r3 <= 0; y7_r3 <= 0;
      v_r3 <= 0; d_r3 <= 0; n_r3 <= 0;
      start_r3 <= 0; run_r3 <= 0;
    end else begin
      x0_r3 <= x_r0[0]; x1_r3 <= x_r0[1]; x2_r3 <= x_r0[2]; x3_r3 <= x_r0[3];
      x4_r3 <= x_r0[4]; x5_r3 <= x_r0[5]; x6_r3 <= x_r0[6]; x7_r3 <= x_r0[7];
      y0_r3 <= y_r0[0]; y1_r3 <= y_r0[1]; y2_r3 <= y_r0[2]; y3_r3 <= y_r0[3];
      y4_r3 <= y_r0[4]; y5_r3 <= y_r0[5]; y6_r3 <= y_r0[6]; y7_r3 <= y_r0[7];
      v_r3 <= v_r1;
      d_r3 <= d_r2;
      n_r3 <= n_r2;
      start_r3 <= start_r2;
      run_r3 <= run_r2;
    end
  end

  // Stage 4: compute per-citizen Manhattan distances and check constraints
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0;i<8;i++) dist_r4[i] <= 11'd0;
      ok_r4 <= 1'b0;
      sum_r4 <= 12'd0;
      start_r4 <= 1'b0; run_r4 <= 1'b0;
    end else begin
      // Compute absolute differences (Manhattan distances)
      reg [10:0] dx0, dx1, dx2, dx3, dx4, dx5, dx6, dx7;
      reg [10:0] dy0, dy1, dy2, dy3, dy4, dy5, dy6, dy7;
      dx0 = (x0_r3 >= x_med_r2) ? (x0_r3 - x_med_r2) : (x_med_r2 - x0_r3);
      dx1 = (x1_r3 >= x_med_r2) ? (x1_r3 - x_med_r2) : (x_med_r2 - x1_r3);
      dx2 = (x2_r3 >= x_med_r2) ? (x2_r3 - x_med_r2) : (x_med_r2 - x2_r3);
      dx3 = (x3_r3 >= x_med_r2) ? (x3_r3 - x_med_r2) : (x_med_r2 - x3_r3);
      dx4 = (x4_r3 >= x_med_r2) ? (x4_r3 - x_med_r2) : (x_med_r2 - x4_r3);
      dx5 = (x5_r3 >= x_med_r2) ? (x5_r3 - x_med_r2) : (x_med_r2 - x5_r3);
      dx6 = (x6_r3 >= x_med_r2) ? (x6_r3 - x_med_r2) : (x_med_r2 - x6_r3);
      dx7 = (x7_r3 >= x_med_r2) ? (x7_r3 - x_med_r2) : (x_med_r2 - x7_r3);

      dy0 = (y0_r3 >= y_med_r2) ? (y0_r3 - y_med_r2) : (y_med_r2 - y0_r3);
      dy1 = (y1_r3 >= y_med_r2) ? (y1_r3 - y_med_r2) : (y_med_r2 - y1_r3);
      dy2 = (y2_r3 >= y_med_r2) ? (y2_r3 - y_med_r2) : (y_med_r2 - y2_r3);
      dy3 = (y3_r3 >= y_med_r2) ? (y3_r3 - y_med_r2) : (y_med_r2 - y3_r3);
      dy4 = (y4_r3 >= y_med_r2) ? (y4_r3 - y_med_r2) : (y_med_r2 - y4_r3);
      dy5 = (y5_r3 >= y_med_r2) ? (y5_r3 - y_med_r2) : (y_med_r2 - y5_r3);
      dy6 = (y6_r3 >= y_med_r2) ? (y6_r3 - y_med_r2) : (y_med_r2 - y6_r3);
      dy7 = (y7_r3 >= y_med_r2) ? (y7_r3 - y_med_r2) : (y_med_r2 - y7_r3);

      dist_r4[0] <= dx0 + dy0;
      dist_r4[1] <= dx1 + dy1;
      dist_r4[2] <= dx2 + dy2;
      dist_r4[3] <= dx3 + dy3;
      dist_r4[4] <= dx4 + dy4;
      dist_r4[5] <= dx5 + dy5;
      dist_r4[6] <= dx6 + dy6;
      dist_r4[7] <= dx7 + dy7;

      // Constraint check: for all valid citizens, distance <= d
      reg ok_all;
      ok_all = 1'b1;
      if (v_r3[0] && (dist_r4[0] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[1] && (dist_r4[1] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[2] && (dist_r4[2] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[3] && (dist_r4[3] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[4] && (dist_r4[4] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[5] && (dist_r4[5] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[6] && (dist_r4[6] > {3'd0, d_r3})) ok_all = 1'b0;
      if (v_r3[7] && (dist_r4[7] > {3'd0, d_r3})) ok_all = 1'b0;
      ok_r4 <= ok_all;

      // Sum distances of valid citizens
      reg [11:0] sum_cur;
      sum_cur = 12'd0;
      if (v_r3[0]) sum_cur = sum_cur + dist_r4[0];
      if (v_r3[1]) sum_cur = sum_cur + dist_r4[1];
      if (v_r3[2]) sum_cur = sum_cur + dist_r4[2];
      if (v_r3[3]) sum_cur = sum_cur + dist_r4[3];
      if (v_r3[4]) sum_cur = sum_cur + dist_r4[4];
      if (v_r3[5]) sum_cur = sum_cur + dist_r4[5];
      if (v_r3[6]) sum_cur = sum_cur + dist_r4[6];
      if (v_r3[7]) sum_cur = sum_cur + dist_r4[7];
      sum_r4 <= sum_cur;

      start_r4 <= start_r3;
      run_r4 <= run_r3;
    end
  end

  // Output stage (stage 5): finalize results and done pulse
  always @(*) begin
    if (start_r4 && run_r4) begin
      total_distance_next = ok_r4 ? sum_r4 : 12'd0;
      impossible_next = ok_r4 ? 1'b0 : 1'b1;
      done_next = 1'b1; // 1-cycle pulse
    end else begin
      total_distance_next = total_distance; // hold previous
      impossible_next = impossible;
      done_next = 1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_distance <= 12'd0;
      impossible <= 1'b0;
      done <= 1'b0;
      start_r5 <= 1'b0; run_r5 <= 1'b0;
    end else begin
      total_distance <= total_distance_next;
      impossible <= impossible_next;
      done <= done_next;
      start_r5 <= start_r4;
      run_r5 <= run_r4;
    end
  end
endmodule