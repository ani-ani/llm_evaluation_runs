module lcs_3strings(input clk, input rst_n, input start, input [7:0] char_x, input [7:0] char_y, input [7:0] char_z, input [2:0] idx_x, input [2:0] idx_y, input [2:0] idx_z, input char_valid, output reg [3:0] result, output reg done, output reg ready);
  assign result = 4'd0;
  assign done = 1'b0;
  assign ready = 1'b0;
endmodule