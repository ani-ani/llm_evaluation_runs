module array_intersection(
    input [7:0] array1 [0:7],
    input [7:0] array2 [0:7],
    input [2:0] len1,
    input [2:0] len2,
    output reg [7:0] result [0:7],
    output reg [7:0] result_valid
);

    integer i, j;
    reg [7:0] match_vector [0:7];
    reg valid_element [0:7];
    reg [2:0] result_index;
    
    always @(*) begin
        // Initialize result and valid mask
        for (i = 0; i < 8; i = i + 1) begin
            result[i] = 8'b0;
        end
        result_valid = 8'b0;
        result_index = 3'b0;
        
        // Process each element of array2
        for (i = 0; i < 8; i = i + 1) begin
            // Check if element i is within len2
            if (i < len2) begin
                // Check if array2[i] exists in array1
                match_vector[i] = 8'b0;
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < len1 && array2[i] == array1[j]) begin
                        match_vector[i][j] = 1'b1;
                    end
                end
                
                // Element is valid if any match found
                valid_element[i] = (match_vector[i] != 8'b0);
                
                // If valid, add to result
                if (valid_element[i]) begin
                    result[result_index] = array2[i];
                    result_valid[result_index] = 1'b1;
                    result_index = result_index + 1;
                end
            end
        end
    end

endmodule