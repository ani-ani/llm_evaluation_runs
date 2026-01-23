module slavko_word (
reg clk,
reg rst_n,
reg start,
reg [7:0] char_in,
output reg [79:0] slavko_word_out,
output reg [2:0] length_out,
output reg winnable,
output reg done 
);

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
slavko_word_out <= 80'b0;
length_out <= 3'b000;
winnable <= 1'b0;
done <= 1'b0;
end
end
endmodule