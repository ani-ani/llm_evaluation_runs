module choose_num(input [15:0] x, input [15:0] y, output reg [15:0] result);
assign temp = (y & 1) ? y - 1 : y;
assign result = ({32{x}} > {32{y}}) ? 16'hFFFF : ( ({32{temp}} >= {32{x}}) ) ? temp : 16'hFFFF;
endmodule