module find_max(input [7:0] data_in [0:7], output [7:0] max_value);
function [7:0] max2(input [7:0] a, input [7:0] b); max2 = (a > b) ? a : b; endfunction
assign stage1 = { max2(data_in[0], data_in[1]), max2(data_in[2], data_in[3]), max2(data_in[4], data_in[5]), max2(data_in[6], data_in[7]) };
assign stage2 = { max2(stage1[0], stage1[1]), max2(stage1[2], stage1[3]) };
assign max_value = max2(stage2[0], stage2[1]);
endmodule