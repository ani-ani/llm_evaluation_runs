module largest_neg (
    input [7:0] list1_0, list1_1, list1_2, list1_3, list1_4, list1_5, list1_6, list1_7,
    input [2:0] valid_count,
    output reg [7:0] result,
    output reg found
);

always @(*) begin
    result = 0;
    found = 0;
    // element0
    if (valid_count > 0) begin
        if (list1_0 < 0) begin
            if (found == 0 || list1_0 < result) begin
                result = list1_0;
                found = 1;
            end
        end
    end
    // element1
    if (valid_count > 1) begin
        if (list1_1 < 0) begin
            if (found == 0 || list1_1 < result) begin
                result = list1_1;
                found = 1;
            end
        end
    end
    // element2
    if (valid_count > 2) begin
        if (list1_2 < 0) begin
            if (found == 0 || list1_2 < result) begin
                result = list1_2;
                found = 1;
            end
        end
    end
    // element3
    if (valid_count > 3) begin
        if (list1_3 < 0) begin
            if (found == 0 || list1_3 < result) begin
                result = list1_3;
                found = 1;
            end
        end
    end
    // element4
    if (valid_count > 4) begin
        if (list1_4 < 0) begin
            if (found == 0 || list1_4 < result) begin
                result = list1_4;
                found = 1;
            end
        end
    end
    // element5
    if (valid_count > 5) begin
        if (list1_5 < 0) begin
            if (found == 0 || list1_5 < result) begin
                result = list1_5;
                found = 1;
            end
        end
    end
    // element6
    if (valid_count > 6) begin
        if (list1_6 < 0) begin
            if (found == 0 || list1_6 < result) begin
                result = list1_6;
                found = 1;
            end
        end
    end
    // element7
    if (valid_count > 7) begin
        if (list1_7 < 0) begin
            if (found == 0 || list1_7 < result) begin
                result = list1_7;
                found = 1;
            end
        end
    end
endmodule