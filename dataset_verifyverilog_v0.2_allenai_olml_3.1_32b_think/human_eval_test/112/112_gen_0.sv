module reverse_delete (
input clk,
input rst_n,
input start,
input [7:0] s_char_0, s_char_1, s_char_2, s_char_3, s_char_4, s_char_5, s_char_6, s_char_7,
input [7:0] c_char_0, c_char_1, c_char_2, c_char_3, c_char_4, c_char_5, c_char_6, c_char_7,
input [3:0] s_len,
input [3:0] c_len,
output reg [7:0] result_char_0, result_char_1, result_char_2, result_char_3, result_char_4, result_char_5, result_char_6, result_char_7,
output reg [3:0] result_len,
output reg is_palindrome,
output reg done
);

always @(*) begin
   result_char_0 = 8'b0;
   result_char_1 = 8'b0;
   result_char_2 = 8'b0;
   result_char_3 = 8'b0;
   result_char_4 = 8'b0;
   result_char_5 = 8'b0;
   result_char_6 = 8'b0;
   result_char_7 = 8'b0;
   result_len = 4'b0;
   is_palindrome = 1'b0;
   done = 1'b0;
end

endmodule