module surface_area_sphere(input reg [7:0] r, output reg [31:0] surfacearea);
  localparam [31:0] FOUR_PI = 32'h000C90FD;
  reg [15:0] r_squared;
  reg [47:0] product;
  always_comb begin
    r_squared = r * r;
    product = r_squared * FOUR_PI;
    surfacearea = product[47:16];
  end
endmodule