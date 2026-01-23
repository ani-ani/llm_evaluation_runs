module cylinder_volume(input [15:0] radius, input [15:0] height, output [31:0] volume);
localparam PI_FIXED = 32'h0003243F;
wire [31:0] radius_scaled = radius << 16;
wire [31:0] height_scaled = height << 16;
wire [63:0] r_squared = radius_scaled * radius_scaled;
wire [95:0] temp1 = r_squared * PI_FIXED;
wire [127:0] temp2 = temp1 * height_scaled;
wire [63:0] upper_64 = temp2[127:64];
assign volume = upper_64[47:16];
endmodule