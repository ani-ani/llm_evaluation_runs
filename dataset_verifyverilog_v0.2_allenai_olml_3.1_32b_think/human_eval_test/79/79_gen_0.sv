module decimal_to_binary (
    input [7:0] decimal,
    output reg [71:0] binary_str
);

localparam CHAR_WIDTH = 8;
localparam CHAR_D = 8'b01100100;
localparam CHAR_B = 8'b01100010;
localparam CHAR_0 = 8'b00110000;
localparam CHAR_1 = 8'b00110001;

assign binary_str[0:7] = CHAR_D;
assign binary_str[8:15] = CHAR_B;
assign binary_str[16:23] = (decimal[6] ? CHAR_1 : CHAR_0);
assign binary_str[24:31] = (decimal[5] ? CHAR_1 : CHAR_0);
assign binary_str[32:39] = (decimal[4] ? CHAR_1 : CHAR_0);
assign binary_str[40:47] = (decimal[3] ? CHAR_1 : CHAR_0);
assign binary_str[48:55] = (decimal[2] ? CHAR_1 : CHAR_0);
assign binary_str[56:63] = (decimal[1] ? CHAR_1 : CHAR_0);
assign binary_str[64:71] = (decimal[0] ? CHAR_1 : CHAR_0);

endmodule