module cone_volume(input [31:0] radius, input [31:0] height, output reg [31:0] volume);
wire [63:0] r_squared = radius * radius;
reg [31:0] temp1;
assign temp1 = r_squared >> 32;
wire [63:0] temp2_product = temp1 * height;
reg [31:0] temp2;
assign temp2 = temp2_product >> 32;
wire [63:0] temp3_product = temp2 * 32'h0003243F;
reg [31:0] temp3;
assign temp3 = temp3_product >> 32;
wire [63:0] temp4_product = temp3 * 32'h00005555;
reg [31:0] temp4;
assign temp4 = temp4_product >> 32;
assign volume = temp4;
endmodule