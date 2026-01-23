module max_diff (
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [2:0] valid_count,
    output reg [7:0] max_diff_result
);

always @(*) begin
    reg [7:0] min_val, max_val;
    min_val = arr_0;
    max_val = arr_0;
    if (valid_count > 1) begin
        if (arr_1 < min_val) min_val = arr_1;
        if (arr_1 > max_val) max_val = arr_1;
    end
    if (valid_count > 2) begin
        if (arr_2 < min_val) min_val = arr_2;
        if (arr_2 > max_val) max_val = arr_2;
    end
    if (valid_count > 3) begin
        if (arr_3 < min_val) min_val = arr_3;
        if (arr_3 > max_val) max_val = arr_3;
    end
    if (valid_count > 4) begin
        if (arr_4 < min_val) min_val = arr_4;
        if (arr_4 > max_val) max_val = arr_4;
    end
    if (valid_count > 5) begin
        if (arr_5 < min_val) min_val = arr_5;
        if (arr_5 > max_val) max_val = arr_5;
    end
    if (valid_count > 6) begin
        if (arr_6 < min_val) min_val = arr_6;
        if (arr_6 > max_val) max_val = arr_6;
    end
    if (valid_count > 7) begin
        if (arr_7 < min_val) min_val = arr_7;
        if (arr_7 > max_val) max_val = arr_7;
    end
    max_diff_result = max_val - min_val;
end
endmodule