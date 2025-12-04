module closest_pair(
  input  [255:0] numbers_packed,
  output [63:0]  closest_pair
);

  // Unpack 8 elements (each 32-bit, little-endian by index)
  wire [31:0] e0 = numbers_packed[31:0];
  wire [31:0] e1 = numbers_packed[63:32];
  wire [31:0] e2 = numbers_packed[95:64];
  wire [31:0] e3 = numbers_packed[127:96];
  wire [31:0] e4 = numbers_packed[159:128];
  wire [31:0] e5 = numbers_packed[191:160];
  wire [31:0] e6 = numbers_packed[223:192];
  wire [31:0] e7 = numbers_packed[255:224];

  // Helper function: absolute difference between two 32-bit values
  function automatic [31:0] abs_diff(input [31:0] a, input [31:0] b);
    begin
      abs_diff = (a >= b) ? (a - b) : (b - a);
    end
  endfunction

  // Compute absolute differences for all 28 pairs
  wire [31:0] d0_1 = abs_diff(e0,e1);
  wire [31:0] d0_2 = abs_diff(e0,e2);
  wire [31:0] d0_3 = abs_diff(e0,e3);
  wire [31:0] d0_4 = abs_diff(e0,e4);
  wire [31:0] d0_5 = abs_diff(e0,e5);
  wire [31:0] d0_6 = abs_diff(e0,e6);
  wire [31:0] d0_7 = abs_diff(e0,e7);

  wire [31:0] d1_2 = abs_diff(e1,e2);
  wire [31:0] d1_3 = abs_diff(e1,e3);
  wire [31:0] d1_4 = abs_diff(e1,e4);
  wire [31:0] d1_5 = abs_diff(e1,e5);
  wire [31:0] d1_6 = abs_diff(e1,e6);
  wire [31:0] d1_7 = abs_diff(e1,e7);

  wire [31:0] d2_3 = abs_diff(e2,e3);
  wire [31:0] d2_4 = abs_diff(e2,e4);
  wire [31:0] d2_5 = abs_diff(e2,e5);
  wire [31:0] d2_6 = abs_diff(e2,e6);
  wire [31:0] d2_7 = abs_diff(e2,e7);

  wire [31:0] d3_4 = abs_diff(e3,e4);
  wire [31:0] d3_5 = abs_diff(e3,e5);
  wire [31:0] d3_6 = abs_diff(e3,e6);
  wire [31:0] d3_7 = abs_diff(e3,e7);

  wire [31:0] d4_5 = abs_diff(e4,e5);
  wire [31:0] d4_6 = abs_diff(e4,e6);
  wire [31:0] d4_7 = abs_diff(e4,e7);

  wire [31:0] d5_6 = abs_diff(e5,e6);
  wire [31:0] d5_7 = abs_diff(e5,e7);

  wire [31:0] d6_7 = abs_diff(e6,e7);

  // Struct for pair candidate: diff, smaller, larger
  typedef struct packed {
    logic [31:0] diff;
    logic [31:0] small;
    logic [31:0] large;
  } pair_t;

  // Helper function to construct ordered pair
  function automatic pair_t make_pair(input [31:0] a, input [31:0] b);
    pair_t p;
    begin
      p.small = (a <= b) ? a : b;
      p.large = (a <= b) ? b : a;
      p.diff  = abs_diff(a,b);
      make_pair = p;
    end
  endfunction

  // Comparison: choose better of two candidates
  // Priority:
  // 1) smaller diff
  // 2) if tie: smaller 'small'
  function automatic pair_t better_pair(input pair_t x, input pair_t y);
    begin
      if (y.diff < x.diff) begin
        better_pair = y;
      end else if (y.diff > x.diff) begin
        better_pair = x;
      end else begin
        // equal diff: choose one with smaller 'small'
        if (y.small < x.small)
          better_pair = y;
        else
          better_pair = x;
      end
    end
  endfunction

  // Build all pair candidates
  wire pair_t p0_1 = make_pair(e0,e1);
  wire pair_t p0_2 = make_pair(e0,e2);
  wire pair_t p0_3 = make_pair(e0,e3);
  wire pair_t p0_4 = make_pair(e0,e4);
  wire pair_t p0_5 = make_pair(e0,e5);
  wire pair_t p0_6 = make_pair(e0,e6);
  wire pair_t p0_7 = make_pair(e0,e7);

  wire pair_t p1_2 = make_pair(e1,e2);
  wire pair_t p1_3 = make_pair(e1,e3);
  wire pair_t p1_4 = make_pair(e1,e4);
  wire pair_t p1_5 = make_pair(e1,e5);
  wire pair_t p1_6 = make_pair(e1,e6);
  wire pair_t p1_7 = make_pair(e1,e7);

  wire pair_t p2_3 = make_pair(e2,e3);
  wire pair_t p2_4 = make_pair(e2,e4);
  wire pair_t p2_5 = make_pair(e2,e5);
  wire pair_t p2_6 = make_pair(e2,e6);
  wire pair_t p2_7 = make_pair(e2,e7);

  wire pair_t p3_4 = make_pair(e3,e4);
  wire pair_t p3_5 = make_pair(e3,e5);
  wire pair_t p3_6 = make_pair(e3,e6);
  wire pair_t p3_7 = make_pair(e3,e7);

  wire pair_t p4_5 = make_pair(e4,e5);
  wire pair_t p4_6 = make_pair(e4,e6);
  wire pair_t p4_7 = make_pair(e4,e7);

  wire pair_t p5_6 = make_pair(e5,e6);
  wire pair_t p5_7 = make_pair(e5,e7);

  wire pair_t p6_7 = make_pair(e6,e7);

  // Reduction tree to find best pair
  wire pair_t r0 = better_pair(p0_1, p0_2);
  wire pair_t r1 = better_pair(p0_3, p0_4);
  wire pair_t r2 = better_pair(p0_5, p0_6);
  wire pair_t r3 = better_pair(p0_7, p1_2);
  wire pair_t r4 = better_pair(p1_3, p1_4);
  wire pair_t r5 = better_pair(p1_5, p1_6);
  wire pair_t r6 = better_pair(p1_7, p2_3);
  wire pair_t r7 = better_pair(p2_4, p2_5);
  wire pair_t r8 = better_pair(p2_6, p2_7);
  wire pair_t r9 = better_pair(p3_4, p3_5);
  wire pair_t r10 = better_pair(p3_6, p3_7);
  wire pair_t r11 = better_pair(p4_5, p4_6);
  wire pair_t r12 = better_pair(p4_7, p5_6);
  wire pair_t r13 = better_pair(p5_7, p6_7);

  // Continue reduction
  wire pair_t s0 = better_pair(r0, r1);
  wire pair_t s1 = better_pair(r2, r3);
  wire pair_t s2 = better_pair(r4, r5);
  wire pair_t s3 = better_pair(r6, r7);
  wire pair_t s4 = better_pair(r8, r9);
  wire pair_t s5 = better_pair(r10, r11);
  wire pair_t s6 = better_pair(r12, r13);

  wire pair_t t0 = better_pair(s0, s1);
  wire pair_t t1 = better_pair(s2, s3);
  wire pair_t t2 = better_pair(s4, s5);

  wire pair_t u0 = better_pair(t0, t1);
  wire pair_t u1 = better_pair(t2, s6);

  wire pair_t best = better_pair(u0, u1);

  assign closest_pair = {best.small, best.large};

endmodule