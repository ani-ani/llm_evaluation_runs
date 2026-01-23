module sphere_surface_area(input [31:0] radius, output [31:0] surface_area);
localparam PI_Q16_16 = 205887;
reg [31:0] r_squared;
reg [31:0] pi_times;
{64{1'b0}} product1;
product1 = radius * radius;
r_squared = product1[63:32];
{64{1'b0}} product2;
product2 = PI_Q16_16 * r_squared;
pi_times = product2[63:32];
surface_area = pi_times << 2;
endmodule