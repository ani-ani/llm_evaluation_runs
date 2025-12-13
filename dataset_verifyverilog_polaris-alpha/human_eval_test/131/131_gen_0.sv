module odd_digit_product(
  input  [15:0] num,
  output [12:0] product
);

  // Maximum value of num is 65535, which has digits up to 99999.
  // Max product of odd digits: 9*9*9*9*9 = 59049 (< 2^16), but spec requires [12:0].

  // Decimal digits (0-9) extracted combinationally via division/modulo by constants
  // d4 d3 d2 d1 d0 represent digits of num in decimal: num = d4*10000 + d3*1000 + ... + d0

  wire [15:0] q10, r10;
  assign q10 = num / 10;
  assign r10 = num % 10;

  wire [15:0] q100, r100;
  assign q100 = q10 / 10;
  assign r100 = q10 % 10;

  wire [15:0] q1000, r1000;
  assign q1000 = q100 / 10;
  assign r1000 = q100 % 10;

  wire [15:0] q10000, r10000;
  assign q10000 = q1000 / 10;
  assign r10000 = q1000 % 10;

  wire [3:0] d0 = r10[3:0];
  wire [3:0] d1 = r100[3:0];
  wire [3:0] d2 = r1000[3:0];
  wire [3:0] d3 = r10000[3:0];
  wire [3:0] d4 = q10000[3:0];

  // Identify odd digits (1,3,5,7,9)
  wire is_odd0 = d0[0];
  wire is_odd1 = d1[0];
  wire is_odd2 = d2[0];
  wire is_odd3 = d3[0];
  wire is_odd4 = d4[0];

  // Replace even digits with multiplicative identity 1 for product accumulation
  // (so they don't affect the product). Odd digits keep their value.
  wire [3:0] val0 = is_odd0 ? d0 : 4'd1;
  wire [3:0] val1 = is_odd1 ? d1 : 4'd1;
  wire [3:0] val2 = is_odd2 ? d2 : 4'd1;
  wire [3:0] val3 = is_odd3 ? d3 : 4'd1;
  wire [3:0] val4 = is_odd4 ? d4 : 4'd1;

  // Compute product of (odd digits, with even digits mapped to 1)
  wire [7:0]  p01 = val0 * val1;
  wire [11:0] p012 = p01 * val2;
  wire [15:0] p0123 = p012 * val3;
  wire [19:0] p_all = p0123 * val4;

  // Determine if there is at least one odd digit
  wire any_odd = is_odd0 | is_odd1 | is_odd2 | is_odd3 | is_odd4;

  // If no odd digits, output 0; otherwise output the product (truncated to 13 bits as specified)
  assign product = any_odd ? p_all[12:0] : 13'd0;

endmodule