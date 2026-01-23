module common_elements (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [2:0] len1,
    input [2:0] len2,
    output reg [7:0] result [0:7],
    output reg [2:0] result_len
);
    integer i, j, k, l;
    reg [7:0] temp_common [0:7];
    reg [2:0] temp_len;
    reg [7:0] temp_sorted [0:7];
    reg [7:0] swap_temp;
    reg already_added;
    reg found_in_list2;
    
    always @(*) begin
        // Initialize
        for (i = 0; i < 8; i = i + 1) begin
            temp_common[i] = 8'd0;
            temp_sorted[i] = 8'd0;
            result[i] = 8'd0;
        end
        temp_len = 3'd0;
        result_len = 3'd0;
        
        // Step 1: Find common unique elements
        for (i = 0; i < 8; i = i + 1) begin
            // Only process valid elements in list1
            if (i < len1) begin
                // Check if already added to common list
                already_added = 1'b0;
                for (j = 0; j < temp_len; j = j + 1) begin
                    if (temp_common[j] == list1[i]) begin
                        already_added = 1'b1;
                    end
                end
                
                // If not already added, check if exists in list2
                if (!already_added) begin
                    found_in_list2 = 1'b0;
                    for (k = 0; k < len2; k = k + 1) begin
                        if (list1[i] == list2[k]) begin
                            found_in_list2 = 1'b1;
                        end
                    end
                    
                    // If found in list2, add to common list
                    if (found_in_list2) begin
                        if (temp_len < 8) begin
                            temp_common[temp_len] = list1[i];
                            temp_len = temp_len + 3'd1;
                        end
                    end
                end
            end
        end
        
        // Step 2: Sort using bubble sort (simple and guaranteed to work)
        // Copy to temp_sorted for sorting
        for (i = 0; i < 8; i = i + 1) begin
            temp_sorted[i] = temp_common[i];
        end
        
        // Bubble sort pass
        for (i = 0; i < 7; i = i + 1) begin
            for (j = 0; j < 7 - i; j = j + 1) begin
                if (temp_sorted[j] > temp_sorted[j + 1]) begin
                    swap_temp = temp_sorted[j];
                    temp_sorted[j] = temp_sorted[j + 1];
                    temp_sorted[j + 1] = swap_temp;
                end
            end
        end
        
        // Step 3: Assign to result
        for (i = 0; i < 8; i = i + 1) begin
            if (i < temp_len) begin
                result[i] = temp_sorted[i];
            end else begin
                result[i] = 8'd0;
            end
        end
        result_len = temp_len;
    end
endmodule