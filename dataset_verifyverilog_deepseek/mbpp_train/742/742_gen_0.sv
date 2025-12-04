module tetrahedron_area (
  input wire [15:0] side_q8,
  output wire [31:0] area_q16
);
  
  wire [31:0] square_value;
  wire [63:0] product;
  
  localparam [31:0] SQRT3 = 32'h0001BB67;
  
  assign square_value = side_q8 * side_q8;
  assign product = square_value * SQRT3;
  assign area_q16 = product[47:16];
  
endmodule