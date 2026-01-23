module find_max_num (
    // Inputs
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,           // Number of valid digits (1-8)
    
    // Outputs
    output reg [31:0] result   // Result can be up to 8 digits: 10^8 ~ 2^32
);

    // Internal state for sorted array
    reg [7:0] sorted_0, sorted_1, sorted_2, sorted_3, sorted_4, sorted_5, sorted_6, sorted_7;
    reg [7:0] temp;
    integer i, j;
    
    // Combinational logic
    always @(*) begin
        // Initialize sorted array with input values
        sorted_0 = arr_0;
        sorted_1 = arr_1;
        sorted_2 = arr_2;
        sorted_3 = arr_3;
        sorted_4 = arr_4;
        sorted_5 = arr_5;
        sorted_6 = arr_6;
        sorted_7 = arr_7;
        
        // Bubble sort descending (for maximum number formation)
        for (i = 0; i < 7; i = i + 1) begin
            for (j = 0; j < 7 - i; j = j + 1) begin
                // Compare and swap adjacent elements
                if (j == 0) begin
                    if (sorted_0 < sorted_1) begin
                        temp = sorted_0;
                        sorted_0 = sorted_1;
                        sorted_1 = temp;
                    end
                end else if (j == 1) begin
                    if (sorted_1 < sorted_2) begin
                        temp = sorted_1;
                        sorted_1 = sorted_2;
                        sorted_2 = temp;
                    end
                end else if (j == 2) begin
                    if (sorted_2 < sorted_3) begin
                        temp = sorted_2;
                        sorted_2 = sorted_3;
                        sorted_3 = temp;
                    end
                end else if (j == 3) begin
                    if (sorted_3 < sorted_4) begin
                        temp = sorted_3;
                        sorted_3 = sorted_4;
                        sorted_4 = temp;
                    end
                end else if (j == 4) begin
                    if (sorted_4 < sorted_5) begin
                        temp = sorted_4;
                        sorted_4 = sorted_5;
                        sorted_5 = temp;
                    end
                end else if (j == 5) begin
                    if (sorted_5 < sorted_6) begin
                        temp = sorted_5;
                        sorted_5 = sorted_6;
                        sorted_6 = temp;
                    end
                end else if (j == 6) begin
                    if (sorted_6 < sorted_7) begin
                        temp = sorted_6;
                        sorted_6 = sorted_7;
                        sorted_7 = temp;
                    end
                end
            end
        end
        
        // Construct the number from sorted digits
        result = 32'd0;
        if (len >= 1) result = result * 10 + sorted_0;
        if (len >= 2) result = result * 10 + sorted_1;
        if (len >= 3) result = result * 10 + sorted_2;
        if (len >= 4) result = result * 10 + sorted_3;
        if (len >= 5) result = result * 10 + sorted_4;
        if (len >= 6) result = result * 10 + sorted_5;
        if (len >= 7) result = result * 10 + sorted_6;
        if (len >= 8) result = result * 10 + sorted_7;
    end

endmodule