module count_distinct_characters(
    input [127:0] char_array,
    input [3:0] length,
    output [3:0] distinct_count
);

    wire [7:0] norm_0, norm_1, norm_2, norm_3, norm_4, norm_5, norm_6, norm_7, norm_8, norm_9, norm_10, norm_11, norm_12, norm_13, norm_14, norm_15;

    assign norm_0 = char_array[7:0] & ~8'h20;
    assign norm_1 = char_array[15:8] & ~8'h20;
    assign norm_2 = char_array[23:16] & ~8'h20;
    assign norm_3 = char_array[31:24] & ~8'h20;
    assign norm_4 = char_array[39:32] & ~8'h20;
    assign norm_5 = char_array[47:40] & ~8'h20;
    assign norm_6 = char_array[55:48] & ~8'h20;
    assign norm_7 = char_array[63:56] & ~8'h20;
    assign norm_8 = char_array[71:64] & ~8'h20;
    assign norm_9 = char_array[79:72] & ~8'h20;
    assign norm_10 = char_array[87:80] & ~8'h20;
    assign norm_11 = char_array[95:88] & ~8'h20;
    assign norm_12 = char_array[103:96] & ~8'h20;
    assign norm_13 = char_array[111:104] & ~8'h20;
    assign norm_14 = char_array[119:112] & ~8'h20;
    assign norm_15 = char_array[127:120] & ~8'h20;

    wire match_found_0;
    wire is_i_less_length_0;
    wire is_new_0;
    match_found_0 = 1'b0;
    is_i_less_length_0 = (length != 4'd0);
    is_new_0 = is_i_less_length_0 & !match_found_0;

    wire match_found_1;
    wire is_i_less_length_1;
    wire is_new_1;
    match_found_1 = (norm_0 == norm_1);
    is_i_less_length_1 = (length > 1);
    is_new_1 = is_i_less_length_1 & !match_found_1;

    wire match_found_2;
    wire is_i_less_length_2;
    wire is_new_2;
    match_found_2 = (norm_0 == norm_2) | (norm_1 == norm_2);
    is_i_less_length_2 = (length > 2);
    is_new_2 = is_i_less_length_2 & !match_found_2;

    wire match_found_3;
    wire is_i_less_length_3;
    wire is_new_3;
    match_found_3 = (norm_0 == norm_3) | (norm_1 == norm_3) | (norm_2 == norm_3);
    is_i_less_length_3 = (length > 3);
    is_new_3 = is_i_less_length_3 & !match_found_3;

    wire match_found_4;
    wire is_i_less_length_4;
    wire is_new_4;
    match_found_4 = (norm_0 == norm_4) | (norm_1 == norm_4) | (norm_2 == norm_4) | (norm_3 == norm_4);
    is_i_less_length_4 = (length > 4);
    is_new_4 = is_i_less_length_4 & !match_found_4;

    wire match_found_5;
    wire is_i_less_length_5;
    wire is_new_5;
    match_found_5 = (norm_0 == norm_5) | (norm_1 == norm_5) | (norm_2 == norm_5) | (norm_3 == norm_5) | (norm_4 == norm_5);
    is_i_less_length_5 = (length > 5);
    is_new_5 = is_i_less_length_5 & !match_found_5;

    wire match_found_6;
    wire is_i_less_length_6;
    wire is_new_6;
    match_found_6 = (norm_0 == norm_6) | (norm_1 == norm_6) | (norm_2 == norm_6) | (norm_3 == norm_6) | (norm_4 == norm_6) | (norm_5 == norm_6);
    is_i_less_length_6 = (length > 6);
    is_new_6 = is_i_less_length_6 & !match_found_6;

    wire match_found_7;
    wire is_i_less_length_7;
    wire is_new_7;
    match_found_7 = (norm_0 == norm_7) | (norm_1 == norm_7) | (norm_2 == norm_7) | (norm_3 == norm_7) | (norm_4 == norm_7) | (norm_5 == norm_7) | (norm_6 == norm_7);
    is_i_less_length_7 = (length > 7);
    is_new_7 = is_i_less_length_7 & !match_found_7;

    wire match_found_8;
    wire is_i_less_length_8;
    wire is_new_8;
    match_found_8 = (norm_0 == norm_8) | (norm_1 == norm_8) | (norm_2 == norm_8) | (norm_3 == norm_8) | (norm_4 == norm_8) | (norm_5 == norm_8) | (norm_6 == norm_8) | (norm_7 == norm_8);
    is_i_less_length_8 = (length > 8);
    is_new_8 = is_i_less_length_8 & !match_found_8;

    wire match_found_9;
    wire is_i_less_length_9;
    wire is_new_9;
    match_found_9 = (norm_0 == norm_9) | (norm_1 == norm_9) | (norm_2 == norm_9) | (norm_3 == norm_9) | (norm_4 == norm_9) | (norm_5 == norm_9) | (norm_6 == norm_9) | (norm_7 == norm_9) | (norm_8 == norm_9);
    is_i_less_length_9 = (length > 9);
    is_new_9 = is_i_less_length_9 & !match_found_9;

    wire match_found_10;
    wire is_i_less_length_10;
    wire is_new_10;
    match_found_10 = (norm_0 == norm_10) | (norm_1 == norm_10) | (norm_2 == norm_10) | (norm_3 == norm_10) | (norm_4 == norm_10) | (norm_5 == norm_10) | (norm_6 == norm_10) | (norm_7 == norm_10) | (norm_8 == norm_10) | (norm_9 == norm_10);
    is_i_less_length_10 = (length > 10);
    is_new_10 = is_i_less_length_10 & !match_found_10;

    wire match_found_11;
    wire is_i_less_length_11;
    wire is_new_11;
    match_found_11 = (norm_0 == norm_11) | (norm_1 == norm_11) | (norm_2 == norm_11) | (norm_3 == norm_11) | (norm_4 == norm_11) | (norm_5 == norm_11) | (norm_6 == norm_11) | (norm_7 == norm_11) | (norm_8 == norm_11) | (norm_9 == norm_11) | (norm_10 == norm_11);
    is_i_less_length_11 = (length > 11);
    is_new_11 = is_i_less_length_11 & !match_found_11;

    wire match_found_12;
    wire is_i_less_length_12;
    wire is_new_12;
    match_found_12 = (norm_0 == norm_12) | (norm_1 == norm_12) | (norm_2 == norm_12) | (norm_3 == norm_12) | (norm_4 == norm_12) | (norm_5 == norm_12) | (norm_6 == norm_12) | (norm_7 == norm_12) | (norm_8 == norm_12) | (norm_9 == norm_12) | (norm_10 == norm_12) | (norm_11 == norm_12);
    is_i_less_length_12 = (length > 12);
    is_new_12 = is_i_less_length_12 & !match_found_12;

    wire match_found_13;
    wire is_i_less_length_13;
    wire is_new_13;
    match_found_13 = (norm_0 == norm_13) | (norm_1 == norm_13) | (norm_2 == norm_13) | (norm_3 == norm_13) | (norm_4 == norm_13) | (norm_5 == norm_13) | (norm_6 == norm_13) | (norm_7 == norm_13) | (norm_8 == norm_13) | (norm_9 == norm_13) | (norm_10 == norm_13) | (norm_11 == norm_13) | (norm_12 == norm_13);
    is_i_less_length_13 = (length > 13);
    is_new_13 = is_i_less_length_13 & !match_found_13;

    wire match_found_14;
    wire is_i_less_length_14;
    wire is_new_14;
    match_found_14 = (norm_0 == norm_14) | (norm_1 == norm_14) | (norm_2 == norm_14) | (norm_3 == norm_14) | (norm_4 == norm_14) | (norm_5 == norm_14) | (norm_6 == norm_14) | (norm_7 == norm_14) | (norm_8 == norm_14) | (norm_9 == norm_14) | (norm_10 == norm_14) | (norm_11 == norm_14) | (norm_12 == norm_14) | (norm_13 == norm_14);
    is_i_less_length_14 = (length > 14);
    is_new_14 = is_i_less_length_14 & !match_found_14;

    wire match_found_15;
    wire is_i_less_length_15;
    wire is_new_15;
    match_found_15 = (norm_0 == norm_15) | (norm_1 == norm_15) | (norm_2 == norm_15) | (norm_3 == norm_15) | (norm_4 == norm_15) | (norm_5 == norm_15) | (norm_6 == norm_15) | (norm_7 == norm_15) | (norm_8 == norm_15) | (norm_9 == norm_15) | (norm_10 == norm_15) | (norm_11 == norm_15) | (norm_12 == norm_15) | (norm_13 == norm_15) | (norm_14 == norm_15);
    is_i_less_length_15 = (length > 15);
    is_new_15 = is_i_less_length_15 & !match_found_15;

    reg [3:0] count;
    always @(*) begin
        count = 0;
        if (is_new_0) count = count + 1;
        if (is_new_1) count = count + 1;
        if (is_new_2) count = count + 1;
        if (is_new_3) count = count + 1;
        if (is_new_4) count = count + 1;
        if (is_new_5) count = count + 1;
        if (is_new_6) count = count + 1;
        if (is_new_7) count = count + 1;
        if (is_new_8) count = count + 1;
        if (is_new_9) count = count + 1;
        if (is_new_10) count = count + 1;
        if (is_new_11) count = count + 1;
        if (is_new_12) count = count + 1;
        if (is_new_13) count = count + 1;
        if (is_new_14) count = count + 1;
        if (is_new_15) count = count + 1;
    end
    assign distinct_count = count;
endmodule