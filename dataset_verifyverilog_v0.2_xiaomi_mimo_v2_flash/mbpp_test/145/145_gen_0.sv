module max_diff(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [2:0] valid_count,
    output reg [7:0] max_diff_result
);

    // Combinational logic block
    always @(*) begin
        // Default values to avoid latches
        reg [7:0] min_val;
        reg [7:0] max_val;
        
        // Initialize with first element (assuming valid_count >= 1)
        min_val = arr_0;
        max_val = arr_0;
        
        // Use if-else statements based on valid_count
        // This handles the number of elements to consider
        if (valid_count >= 3'd2) begin
            if (arr_1 < min_val) min_val = arr_1;
            if (arr_1 > max_val) max_val = arr_1;
        end
        
        if (valid_count >= 3'd3) begin
            if (arr_2 < min_val) min_val = arr_2;
            if (arr_2 > max_val) max_val = arr_2;
        end
        
        if (valid_count >= 3'd4) begin
            if (arr_3 < min_val) min_val = arr_3;
            if (arr_3 > max_val) max_val = arr_3;
        end
        
        if (valid_count >= 3'd5) begin
            if (arr_4 < min_val) min_val = arr_4;
            if (arr_4 > max_val) max_val = arr_4;
        end
        
        if (valid_count >= 3'd6) begin
            if (arr_5 < min_val) min_val = arr_5;
            if (arr_5 > max_val) max_val = arr_5;
        end
        
        if (valid_count >= 3'd7) begin
            if (arr_6 < min_val) min_val = arr_6;
            if (arr_6 > max_val) max_val = arr_6;
        end
        
        if (valid_count == 3'd0) begin
            // For valid_count=0, we could output 0 or handle specially
            // Based on spec, valid_count is 1-8, but handling edge case
            max_diff_result = 8'd0;
        end else begin
            max_diff_result = max_val - min_val;
        end
    end

endmodule
