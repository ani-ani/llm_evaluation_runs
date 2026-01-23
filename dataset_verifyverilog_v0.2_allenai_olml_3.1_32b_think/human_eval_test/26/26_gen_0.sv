module remove_duplicates (
    input [7:0] data_in [0:7],
    output [7:0] data_out [0:7]
);
assign valid_0 = data_in[0] != 8'hFF;
assign valid_1 = data_in[1] != 8'hFF;
assign valid_2 = data_in[2] != 8'hFF;
assign valid_3 = data_in[3] != 8'hFF;
assign valid_4 = data_in[4] != 8'hFF;
assign valid_5 = data_in[5] != 8'hFF;
assign valid_6 = data_in[6] != 8'hFF;
assign valid_7 = data_in[7] != 8'hFF;
assign is_duplicate_0 = 0;
assign keep_0 = valid_0 & !is_duplicate_0;
assign is_duplicate_1 = valid_0 & (data_in[0] == data_in[1]);
assign keep_1 = valid_1 & !is_duplicate_1;
assign is_duplicate_2 = valid_0 & (data_in[0] == data_in[2]) | valid_1 & (data_in[1] == data_in[2]);
assign keep_2 = valid_2 & !is_duplicate_2;
assign is_duplicate_3 = valid_0 & (data_in[0] == data_in[3]) | valid_1 & (data_in[1] == data_in[3]) | valid_2 & (data_in[2] == data_in[3]);
assign keep_3 = valid_3 & !is_duplicate_3;
assign is_duplicate_4 = valid_0 & (data_in[0] == data_in[4]) | valid_1 & (data_in[1] == data_in[4]) | valid_2 & (data_in[2] == data_in[4]) | valid_3 & (data_in[3] == data_in[4]);
assign keep_4 = valid_4 & !is_duplicate_4;
assign is_duplicate_5 = valid_0 & (data_in[0] == data_in[5]) | valid_1 & (data_in[1] == data_in[5]) | valid_2 & (data_in[2] == data_in[5]) | valid_3 & (data_in[3] == data_in[5]) | valid_4 & (data_in[4] == data_in[5]);
assign keep_5 = valid_5 & !is_duplicate_5;
assign is_duplicate_6 = valid_0 & (data_in[0] == data_in[6]) | valid_1 & (data_in[1] == data_in[6]) | valid_2 & (data_in[2] == data_in[6]) | valid_3 & (data_in[3] == data_in[6]) | valid_4 & (data_in[4] == data_in[6]) | valid_5 & (data_in[5] == data_in[6]);
assign keep_6 = valid_6 & !is_duplicate_6;
assign is_duplicate_7 = valid_0 & (data_in[0] == data_in[7]) | valid_1 & (data_in[1] == data_in[7]) | valid_2 & (data_in[2] == data_in[7]) | valid_3 & (data_in[3] == data_in[7]) | valid_4 & (data_in[4] == data_in[7]) | valid_5 & (data_in[5] == data_in[7]) | valid_6 & (data_in[6] == data_in[7]);
assign keep_7 = valid_7 & !is_duplicate_7;
assign cumulative_keep_0 = keep_0;
assign cumulative_keep_1 = keep_0 + keep_1;
assign cumulative_keep_2 = keep_0 + keep_1 + keep_2;
assign cumulative_keep_3 = keep_0 + keep_1 + keep_2 + keep_3;
assign cumulative_keep_4 = keep_0 + keep_1 + keep_2 + keep_3 + keep_4;
assign cumulative_keep_5 = keep_0 + keep_1 + keep_2 + keep_3 + keep_4 + keep_5;
assign cumulative_keep_6 = keep_0 + keep_1 + keep_2 + keep_3 + keep_4 + keep_5 + keep_6;
assign cumulative_keep_7 = keep_0 + keep_1 + keep_2 + keep_3 + keep_4 + keep_5 + keep_6 + keep_7;
assign total_keep = cumulative_keep_7;
assign data_out[0] = (total_keep > 0) ? (
    (keep_0 && (0 == 0)) ? data_in[0] :
    (keep_1 && (cumulative_keep_0 == 0)) ? data_in[1] :
    (keep_2 && (cumulative_keep_1 == 0)) ? data_in[2] :
    (keep_3 && (cumulative_keep_2 == 0)) ? data_in[3] :
    (keep_4 && (cumulative_keep_3 == 0)) ? data_in[4] :
    (keep_5 && (cumulative_keep_4 == 0)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 0)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 0)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[1] = (total_keep > 1) ? (
    (keep_1 && (cumulative_keep_0 == 1)) ? data_in[1] :
    (keep_2 && (cumulative_keep_1 == 1)) ? data_in[2] :
    (keep_3 && (cumulative_keep_2 == 1)) ? data_in[3] :
    (keep_4 && (cumulative_keep_3 == 1)) ? data_in[4] :
    (keep_5 && (cumulative_keep_4 == 1)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 1)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 1)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[2] = (total_keep > 2) ? (
    (keep_2 && (cumulative_keep_1 == 2)) ? data_in[2] :
    (keep_3 && (cumulative_keep_2 == 2)) ? data_in[3] :
    (keep_4 && (cumulative_keep_3 == 2)) ? data_in[4] :
    (keep_5 && (cumulative_keep_4 == 2)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 2)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 2)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[3] = (total_keep > 3) ? (
    (keep_3 && (cumulative_keep_2 == 3)) ? data_in[3] :
    (keep_4 && (cumulative_keep_3 == 3)) ? data_in[4] :
    (keep_5 && (cumulative_keep_4 == 3)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 3)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 3)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[4] = (total_keep > 4) ? (
    (keep_4 && (cumulative_keep_3 == 4)) ? data_in[4] :
    (keep_5 && (cumulative_keep_4 == 4)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 4)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 4)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[5] = (total_keep > 5) ? (
    (keep_5 && (cumulative_keep_4 == 5)) ? data_in[5] :
    (keep_6 && (cumulative_keep_5 == 5)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 5)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[6] = (total_keep > 6) ? (
    (keep_6 && (cumulative_keep_5 == 6)) ? data_in[6] :
    (keep_7 && (cumulative_keep_6 == 6)) ? data_in[7] :
    8'hFF
) : 8'hFF;
assign data_out[7] = (total_keep > 7) ? (
    (keep_7 && (cumulative_keep_6 == 7)) ? data_in[7] :
    8'hFF
) : 8'hFF;
endmodule