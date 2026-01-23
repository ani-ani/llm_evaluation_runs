module count_occurrence (
    input [7:0] tuple_data,
    input [2:0] tuple_len,
    input [7:0] list_data,
    input [2:0] list_len,
    output [3:0] result
);

wire tuple_valid_0, tuple_valid_1, tuple_valid_2, tuple_valid_3, tuple_valid_4, tuple_valid_5, tuple_valid_6, tuple_valid_7;

assign tuple_valid_0 = (0 < tuple_len);
assign tuple_valid_1 = (1 < tuple_len);
assign tuple_valid_2 = (2 < tuple_len);
assign tuple_valid_3 = (3 < tuple_len);
assign tuple_valid_4 = (4 < tuple_len);
assign tuple_valid_5 = (5 < tuple_len);
assign tuple_valid_6 = (6 < tuple_len);
assign tuple_valid_7 = (7 < tuple_len);

wire list_valid_0, list_valid_1, list_valid_2, list_valid_3, list_valid_4, list_valid_5, list_valid_6, list_valid_7;

assign list_valid_0 = (0 < list_len);
assign list_valid_1 = (1 < list_len);
assign list_valid_2 = (2 < list_len);
assign list_valid_3 = (3 < list_len);
assign list_valid_4 = (4 < list_len);
assign list_valid_5 = (5 < list_len);
assign list_valid_6 = (6 < list_len);
assign list_valid_7 = (7 < list_len);

wire any_match_0, any_match_1, any_match_2, any_match_3, any_match_4, any_match_5, any_match_6, any_match_7;

assign any_match_0 = tuple_valid_0 & (list_valid_0 & (tuple_data[0] == list_data[0]) | list_valid_1 & (tuple_data[0] == list_data[1]) | list_valid_2 & (tuple_data[0] == list_data[2]) | list_valid_3 & (tuple_data[0] == list_data[3]) | list_valid_4 & (tuple_data[0] == list_data[4]) | list_valid_5 & (tuple_data[0] == list_data[5]) | list_valid_6 & (tuple_data[0] == list_data[6]) | list_valid_7 & (tuple_data[0] == list_data[7]));
assign any_match_1 = tuple_valid_1 & (list_valid_0 & (tuple_data[1] == list_data[0]) | list_valid_1 & (tuple_data[1] == list_data[1]) | list_valid_2 & (tuple_data[1] == list_data[2]) | list_valid_3 & (tuple_data[1] == list_data[3]) | list_valid_4 & (tuple_data[1] == list_data[4]) | list_valid_5 & (tuple_data[1] == list_data[5]) | list_valid_6 & (tuple_data[1] == list_data[6]) | list_valid_7 & (tuple_data[1] == list_data[7]));
assign any_match_2 = tuple_valid_2 & (list_valid_0 & (tuple_data[2] == list_data[0]) | list_valid_1 & (tuple_data[2] == list_data[1]) | list_valid_2 & (tuple_data[2] == list_data[2]) | list_valid_3 & (tuple_data[2] == list_data[3]) | list_valid_4 & (tuple_data[2] == list_data[4]) | list_valid_5 & (tuple_data[2] == list_data[5]) | list_valid_6 & (tuple_data[2] == list_data[6]) | list_valid_7 & (tuple_data[2] == list_data[7]));
assign any_match_3 = tuple_valid_3 & (list_valid_0 & (tuple_data[3] == list_data[0]) | list_valid_1 & (tuple_data[3] == list_data[1]) | list_valid_2 & (tuple_data[3] == list_data[2]) | list_valid_3 & (tuple_data[3] == list_data[3]) | list_valid_4 & (tuple_data[3] == list_data[4]) | list_valid_5 & (tuple_data[3] == list_data[5]) | list_valid_6 & (tuple_data[3] == list_data[6]) | list_valid_7 & (tuple_data[3] == list_data[7]));
assign any_match_4 = tuple_valid_4 & (list_valid_0 & (tuple_data[4] == list_data[0]) | list_valid_1 & (tuple_data[4] == list_data[1]) | list_valid_2 & (tuple_data[4] == list_data[2]) | list_valid_3 & (tuple_data[4] == list_data[3]) | list_valid_4 & (tuple_data[4] == list_data[4]) | list_valid_5 & (tuple_data[4] == list_data[5]) | list_valid_6 & (tuple_data[4] == list_data[6]) | list_valid_7 & (tuple_data[4] == list_data[7]));
assign any_match_5 = tuple_valid_5 & (list_valid_0 & (tuple_data[5] == list_data[0]) | list_valid_1 & (tuple_data[5] == list_data[1]) | list_valid_2 & (tuple_data[5] == list_data[2]) | list_valid_3 & (tuple_data[5] == list_data[3]) | list_valid_4 & (tuple_data[5] == list_data[4]) | list_valid_5 & (tuple_data[5] == list_data[5]) | list_valid_6 & (tuple_data[5] == list_data[6]) | list_valid_7 & (tuple_data[5] == list_data[7]));
assign any_match_6 = tuple_valid_6 & (list_valid_0 & (tuple_data[6] == list_data[0]) | list_valid_1 & (tuple_data[6] == list_data[1]) | list_valid_2 & (tuple_data[6] == list_data[2]) | list_valid_3 & (tuple_data[6] == list_data[3]) | list_valid_4 & (tuple_data[6] == list_data[4]) | list_valid_5 & (tuple_data[6] == list_data[5]) | list_valid_6 & (tuple_data[6] == list_data[6]) | list_valid_7 & (tuple_data[6] == list_data[7]));
assign any_match_7 = tuple_valid_7 & (list_valid_0 & (tuple_data[7] == list_data[0]) | list_valid_1 & (tuple_data[7] == list_data[1]) | list_valid_2 & (tuple_data[7] == list_data[2]) | list_valid_3 & (tuple_data[7] == list_data[3]) | list_valid_4 & (tuple_data[7] == list_data[4]) | list_valid_5 & (tuple_data[7] == list_data[5]) | list_valid_6 & (tuple_data[7] == list_data[6]) | list_valid_7 & (tuple_data[7] == list_data[7]));

assign result = any_match_0 + any_match_1 + any_match_2 + any_match_3 + any_match_4 + any_match_5 + any_match_6 + any_match_7;

endmodule