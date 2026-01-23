module remove_elements (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:7],
    output reg [3:0] result_len
);

    // Internal signals for match detection
    reg [7:0] match_found [0:7];
    
    // Generate match flags for each list1 element
    integer i, j;
    
    always @(*) begin
        // Initialize match_found and result arrays
        for (i = 0; i < 8; i = i + 1) begin
            match_found[i] = 8'd0;
            result[i] = 8'd0; // Initialize don't care
        end
        result_len = 4'd0;
        
        // Check each element in list1 against list2
        for (i = 0; i < 8; i = i + 1) begin
            if (i < len1) begin
                // Compare list1[i] with all valid elements in list2
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < len2) begin
                        if (list1[i] == list2[j]) begin
                            match_found[i] = 8'd1;
                        end
                    end
                end
                
                // If no match found, add to result
                if (match_found[i] == 8'd0) begin
                    result[result_len] = list1[i];
                    result_len = result_len + 4'd1;
                end
            end
        end
    end

endmodule