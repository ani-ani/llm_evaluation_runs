module triangle_area (
  input  [15:0] a,
  input  [15:0] h,
  output [15:0] area
);

  // Compute 32-bit product in Q16.16
  wire [31:0] prod;
  assign prod = a * h;

  // Triangle area = (a * h) / 2
  // For Q16.16, divide by 2 is right shift by 1.
  // Then convert back to Q8.8 by taking bits [23:8].
  assign area = ((prod >> 1) >> 8)[15:0];

endmodule