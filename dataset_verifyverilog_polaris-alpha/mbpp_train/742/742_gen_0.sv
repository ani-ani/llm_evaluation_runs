module tetrahedron_area(
  input  [15:0] side_q8,
  output [31:0] area_q16
);

  // Step 1: square_value = side_q8 * side_q8 (16b x 16b = 32b)
  wire [31:0] square_value;
  assign square_value = side_q8 * side_q8;

  // sqrt(3) in Q16.16 fixed-point format
  localparam [31:0] SQRT3_Q16 = 32'h0001_BB67;

  // Step 2: Multiply square_value by SQRT3_Q16 (32b x 32b = 64b)
  wire [63:0] mult_result;
  assign mult_result = square_value * SQRT3_Q16;

  // Take upper 32 bits as Q16.16 result
  assign area_q16 = mult_result[63:32];

endmodule