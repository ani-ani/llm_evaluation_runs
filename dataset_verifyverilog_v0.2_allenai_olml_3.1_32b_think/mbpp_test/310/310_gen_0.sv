module string_to_tuple (
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output [7:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output [3:0] count
);
assign non_space_0 = (char_0 != 8'h20);
assign non_space_1 = (char_1 != 8'h20);
assign non_space_2 = (char_2 != 8'h20);
assign non_space_3 = (char_3 != 8'h20);
assign non_space_4 = (char_4 != 8'h20);
assign non_space_5 = (char_5 != 8'h20);
assign non_space_6 = (char_6 != 8'h20);
assign non_space_7 = (char_7 != 8'h20);
assign cum_0 = non_space_0 ? 1 : 0;
assign cum_1 = cum_0 + (non_space_1 ? 1 : 0);
assign cum_2 = cum_1 + (non_space_2 ? 1 : 0);
assign cum_3 = cum_2 + (non_space_3 ? 1 : 0);
assign cum_4 = cum_3 + (non_space_4 ? 1 : 0);
assign cum_5 = cum_4 + (non_space_5 ? 1 : 0);
assign cum_6 = cum_5 + (non_space_6 ? 1 : 0);
assign cum_7 = cum_6 + (non_space_7 ? 1 : 0);
assign count = cum_7;
assign cum_prev_0 = 0;
assign cum_prev_1 = cum_0;
assign cum_prev_2 = cum_1;
assign cum_prev_3 = cum_2;
assign cum_prev_4 = cum_3;
assign cum_prev_5 = cum_4;
assign cum_prev_6 = cum_5;
assign cum_prev_7 = cum_6;
assign result_0 = (count > 0) ? (non_space_0 && cum_prev_0 == 0 ? char_0 : (non_space_1 && cum_prev_1 == 0 ? char_1 : (non_space_2 && cum_prev_2 == 0 ? char_2 : (non_space_3 && cum_prev_3 == 0 ? char_3 : (non_space_4 && cum_prev_4 == 0 ? char_4 : (non_space_5 && cum_prev_5 == 0 ? char_5 : (non_space_6 && cum_prev_6 == 0 ? char_6 : (non_space_7 && cum_prev_7 == 0 ? char_7 : 8'h00))))))) : 8'h00;
assign result_1 = (count > 1) ? (non_space_0 && cum_prev_0 == 1 ? char_0 : (non_space_1 && cum_prev_1 == 1 ? char_1 : (non_space_2 && cum_prev_2 == 1 ? char_2 : (non_space_3 && cum_prev_3 == 1 ? char_3 : (non_space_4 && cum_prev_4 == 1 ? char_4 : (non_space_5 && cum_prev_5 == 1 ? char_5 : (non_space_6 && cum_prev_6 == 1 ? char_6 : (non_space_7 && cum_prev_7 == 1 ? char_7 : 8'h00))))))) : 8'h00;
assign result_2 = (count > 2) ? (non_space_0 && cum_prev_0 == 2 ? char_0 : (non_space_1 && cum_prev_1 == 2 ? char_1 : (non_space_2 && cum_prev_2 == 2 ? char_2 : (non_space_3 && cum_prev_3 == 2 ? char_3 : (non_space_4 && cum_prev_4 == 2 ? char_4 : (non_space_5 && cum_prev_5 == 2 ? char_5 : (non_space_6 && cum_prev_6 == 2 ? char_6 : (non_space_7 && cum_prev_7 == 2 ? char_7 : 8'h00))))))) : 8'h00;
assign result_3 = (count > 3) ? (non_space_0 && cum_prev_0 == 3 ? char_0 : (non_space_1 && cum_prev_1 == 3 ? char_1 : (non_space_2 && cum_prev_2 == 3 ? char_2 : (non_space_3 && cum_prev_3 == 3 ? char_3 : (non_space_4 && cum_prev_4 == 3 ? char_4 : (non_space_5 && cum_prev_5 == 3 ? char_5 : (non_space_6 && cum_prev_6 == 3 ? char_6 : (non_space_7 && cum_prev_7 == 3 ? char_7 : 8'h00))))))) : 8'h00;
assign result_4 = (count > 4) ? (non_space_0 && cum_prev_0 == 4 ? char_0 : (non_space_1 && cum_prev_1 == 4 ? char_1 : (non_space_2 && cum_prev_2 == 4 ? char_2 : (non_space_3 && cum_prev_3 == 4 ? char_3 : (non_space_4 && cum_prev_4 == 4 ? char_4 : (non_space_5 && cum_prev_5 == 4 ? char_5 : (non_space_6 && cum_prev_6 == 4 ? char_6 : (non_space_7 && cum_prev_7 == 4 ? char_7 : 8'h00))))))) : 8'h00;
assign result_5 = (count > 5) ? (non_space_0 && cum_prev_0 == 5 ? char_0 : (non_space_1 && cum_prev_1 == 5 ? char_1 : (non_space_2 && cum_prev_2 == 5 ? char_2 : (non_space_3 && cum_prev_3 == 5 ? char_3 : (non_space_4 && cum_prev_4 == 5 ? char_4 : (non_space_5 && cum_prev_5 == 5 ? char_5 : (non_space_6 && cum_prev_6 == 5 ? char_6 : (non_space_7 && cum_prev_7 == 5 ? char_7 : 8'h00))))))) : 8'h00;
assign result_6 = (count > 6) ? (non_space_0 && cum_prev_0 == 6 ? char_0 : (non_space_1 && cum_prev_1 == 6 ? char_1 : (non_space_2 && cum_prev_2 == 6 ? char_2 : (non_space_3 && cum_prev_3 == 6 ? char_3 : (non_space_4 && cum_prev_4 == 6 ? char_4 : (non_space_5 && cum_prev_5 == 6 ? char_5 : (non_space_6 && cum_prev_6 == 6 ? char_6 : (non_space_7 && cum_prev_7 == 6 ? char_7 : 8'h00))))))) : 8'h00;
assign result_7 = (count > 7) ? (non_space_0 && cum_prev_0 == 7 ? char_0 : (non_space_1 && cum_prev_1 == 7 ? char_1 : (non_space_2 && cum_prev_2 == 7 ? char_2 : (non_space_3 && cum_prev_3 == 7 ? char_3 : (non_space_4 && cum_prev_4 == 7 ? char_4 : (non_space_5 && cum_prev_5 == 7 ? char_5 : (non_space_6 && cum_prev_6 == 7 ? char_6 : (non_space_7 && cum_prev_7 == 7 ? char_7 : 8'h00))))))) : 8'h00;
endmodule