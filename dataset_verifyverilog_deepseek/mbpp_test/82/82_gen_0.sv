module sphere_volume(input [31:0] radius, output [31:0] volume);
  logic [95:0] radius_cubed;
  localparam [31:0] FOUR_THIRDS_PI = 32'h00043172;
  logic [127:0] full_product;
  logic [63:0] intermediate;
  
  assign radius_cubed = radius * radius * radius;
  assign full_product = radius_cubed * FOUR_THIRDS_PI;
  assign intermediate = full_product[127:64];
  assign volume = intermediate[63:32];
endmodule