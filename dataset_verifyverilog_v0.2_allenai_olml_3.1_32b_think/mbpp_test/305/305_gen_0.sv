module start_withp(input [79:0] input_string, output reg [7:0] word1_char0, output reg [7:0] word1_char1, output reg [7:0] word1_char2, output reg [7:0] word1_char3, output reg [7:0] word1_char4, output reg [7:0] word1_char5, output reg [7:0] word1_char6, output reg [7:0] word1_char7, output reg [7:0] word2_char0, output reg [7:0] word2_char1, output reg [7:0] word2_char2, output reg [7:0] word2_char3, output reg [7:0] word2_char4, output reg [7:0] word2_char5, output reg [7:0] word2_char6, output reg [7:0] word2_char7, output reg found);

assign word1_char0 = 8'h00;
assign word1_char1 = 8'h00;
assign word1_char2 = 8'h00;
assign word1_char3 = 8'h00;
assign word1_char4 = 8'h00;
assign word1_char5 = 8'h00;
assign word1_char6 = 8'h00;
assign word1_char7 = 8'h00;
assign word2_char0 = 8'h00;
assign word2_char1 = 8'h00;
assign word2_char2 = 8'h00;
assign word2_char3 = 8'h00;
assign word2_char4 = 8'h00;
assign word2_char5 = 8'h00;
assign word2_char6 = 8'h00;
assign word2_char7 = 8'h00;
assign found = 1'b0;
endmodule