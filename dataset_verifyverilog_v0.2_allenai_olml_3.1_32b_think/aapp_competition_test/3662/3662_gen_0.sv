module tree_avenue(input clk, input rst_n, input start, input [2:0] num_trees, input [31:0] road_len, input [31:0] road_width, input [31:0] tree_pos_0, input [31:0] tree_pos_1, input [31:0] tree_pos_2, input [31:0] tree_pos_3, input [31:0] tree_pos_4, input [31:0] tree_pos_5, input [31:0] tree_pos_6, input [31:0] tree_pos_7, output reg [63:0] total_distance, output reg done);
reg [2:0] state;
always @(posedge clk) begin
  if (!rst_n) state <= 3'd0;
  else if (start) state <= 3'd1;
end
assign done = 1'b0;
assign total_distance = 64'd0;
endmodule