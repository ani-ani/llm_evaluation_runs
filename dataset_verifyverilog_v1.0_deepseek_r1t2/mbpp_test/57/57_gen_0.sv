module find_max_num(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [31:0] result
);

    reg [7:0] sorted [0:7];
    reg [7:0] temp_val;
    integer i, j, k;
    
    always @(*) begin
        // Initialize array from inputs
        sorted[0] = arr_0;
        sorted[1] = arr_1;
        sorted[2] = arr_2;
        sorted[3] = arr_3;
        sorted[4] = arr_4;
        sorted[5] = arr_5;
        sorted[6] = arr_6;
        sorted[7] = arr_7;
        
        // Bubble sort (descending order)
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 7 - i; j = j + 1) begin
                if (sorted[j] < sorted[j + 1]) begin
                    temp_val = sorted[j];
                    sorted[j] = sorted[j + 1];
                    sorted[j + 1] = temp_val;
                end
            end
        end
        
        // Construct maximum number
        result = 32'd0;
        for (k = 0; k < len; k = k + 1) begin
            result = result * 32'd10 + sorted[k];
        end
    end

endmodule