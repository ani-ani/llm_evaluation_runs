module longest_string (input clk, input rst_n, input [7:0] str0, input [7:0] str1, input [7:0] str2, input [7:0] str3, input [7:0] str4, input [7:0] str5, output reg [7:0] result, output reg valid);
wire [7:0] max_val; wire [7:0] temp;
assign temp = str0 | str1 | str2 | str3 | str4 | str5;
assign valid_comb = |temp;
always @(*) begin max_val = str0; if (str1 > max_val) max_val = str1; if (str2 > max_val) max_val = str2; if (str3 > max_val) max_val = str3; if (str4 > max_val) max_val = str4; if (str5 > max_val) max_val = str5;end
assign result_comb = valid_comb ? max_val : 8'b0;
always @(posedge clk or negedge rst_n) begin if (!rst_n) begin result <= 8'b0; valid <= 1'b0; end else begin result <= result_comb; valid <= valid_comb; end end
endmodule