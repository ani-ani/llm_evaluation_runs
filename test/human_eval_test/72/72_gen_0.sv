module will_it_fly(
  input  [63:0] q_flat,
  input  [3:0]  length,
  input  [10:0] w,
  output        will_fly
);

  // Unpack elements for clarity
  wire [7:0] e0 = q_flat[7:0];
  wire [7:0] e1 = q_flat[15:8];
  wire [7:0] e2 = q_flat[23:16];
  wire [7:0] e3 = q_flat[31:24];
  wire [7:0] e4 = q_flat[39:32];
  wire [7:0] e5 = q_flat[47:40];
  wire [7:0] e6 = q_flat[55:48];
  wire [7:0] e7 = q_flat[63:56];

  // Palindrome checks (only enabled when corresponding indices are valid)
  wire pal_0_7 = (e0 == e7);
  wire pal_1_6 = (e1 == e6);
  wire pal_2_5 = (e2 == e5);
  wire pal_3_4 = (e3 == e4);

  wire pal_ok =
    (length <= 1) ? 1'b1 :
    (length == 2) ? 1'b1 :
    (length == 3) ? (pal_0_7) :
    (length == 4) ? (pal_0_7 & pal_1_6) :
    (length == 5) ? (pal_0_7 & pal_1_6) :
    (length == 6) ? (pal_0_7 & pal_1_6 & pal_2_5) :
    (length == 7) ? (pal_0_7 & pal_1_6 & pal_2_5) :
    /* length == 8 or >8 (treat >8 as using 8 elements) */
                    (pal_0_7 & pal_1_6 & pal_2_5 & pal_3_4);

  // Sum of first 'length' elements (11-bit result is enough since max 8*255=2040)
  wire [10:0] sum =
      ((length > 0) ? {3'b000, e0} : 11'd0) +
      ((length > 1) ? {3'b000, e1} : 11'd0) +
      ((length > 2) ? {3'b000, e2} : 11'd0) +
      ((length > 3) ? {3'b000, e3} : 11'd0) +
      ((length > 4) ? {3'b000, e4} : 11'd0) +
      ((length > 5) ? {3'b000, e5} : 11'd0) +
      ((length > 6) ? {3'b000, e6} : 11'd0) +
      ((length > 7) ? {3'b000, e7} : 11'd0);

  assign will_fly = pal_ok & (sum <= w);

endmodule