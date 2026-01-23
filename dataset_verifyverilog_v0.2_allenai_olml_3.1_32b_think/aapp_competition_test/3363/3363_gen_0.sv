module calorie_optimizer(input clk, input rst_n, input start, input [15:0] m, input [3:0] n, input [15:0] courses [0:9], output reg [31:0] result, output reg done);
assign result = 32'd0;
assign done = 1'b0;
endmodule