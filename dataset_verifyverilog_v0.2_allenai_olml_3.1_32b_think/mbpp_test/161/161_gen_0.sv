module list_filter(input [2:0][7:0] list1, input [2:0][7:0] list2, input [2:0] valid2, output [2:0][7:0] result, output [2:0] result_valid);
assign match_found_0 = (valid2[0] && list1[0] == list2[0]) || (valid2[1] && list1[0] == list2[1]) || (valid2[2] && list1[0] == list2[2]);
assign match_found_1 = (valid2[0] && list1[1] == list2[0]) || (valid2[1] && list1[1] == list2[1]) || (valid2[2] && list1[1] == list2[2]);
assign match_found_2 = (valid2[0] && list1[2] == list2[0]) || (valid2[1] && list1[2] == list2[1]) || (valid2[2] && list1[2] == list2[2]);
assign result_valid[0] = !match_found_0;
assign result_valid[1] = !match_found_1;
assign result_valid[2] = !match_found_2;
assign result[0] = !match_found_0 ? list1[0] : 8'b0;
assign result[1] = !match_found_1 ? list1[1] : 8'b0;
assign result[2] = !match_found_2 ? list1[2] : 8'b0;
endmodule