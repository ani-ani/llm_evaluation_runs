module surface_area_cube(input [7:0] l, output reg [15:0] surface_area);
  always @(*) begin
    surface_area = 6 * l * l;
  end
endmodule