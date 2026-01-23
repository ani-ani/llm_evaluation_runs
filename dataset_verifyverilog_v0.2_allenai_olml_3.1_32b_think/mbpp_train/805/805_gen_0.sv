module max_sum_list(input [2:0][3:0] list_0, input [2:0][3:0] list_1, input [2:0][3:0] list_2, input [2:0][3:0] list_3, output [2:0][3:0] max_list);
reg signed [5:0] sum_0, sum_1, sum_2, sum_3;
reg signed [5:0] max_ab, max_abc, max_sum;
reg [1:0] selected_idx;
assign sum_0 = (signed)list_0[0] + (signed)list_0[1] + (signed)list_0[2];
assign sum_1 = (signed)list_1[0] + (signed)list_1[1] + (signed)list_1[2];
assign sum_2 = (signed)list_2[0] + (signed)list_2[1] + (signed)list_2[2];
assign sum_3 = (signed)list_3[0] + (signed)list_3[1] + (signed)list_3[2];
assign max_ab = (sum_0 > sum_1) ? sum_0 : sum_1;
assign max_abc = (max_ab > sum_2) ? max_ab : sum_2;
assign max_sum = (max_abc > sum_3) ? max_abc : sum_3;
assign selected_idx = (sum_0 == max_sum) ? 2'd0 : (sum_1 == max_sum) ? 2'd1 : (sum_2 == max_sum) ? 2'd2 : 2'd3;
assign max_list = (selected_idx == 2'd0) ? list_0 : (selected_idx == 2'd1) ? list_1 : (selected_idx == 2'd2) ? list_2 : list_3;
endmodule