module list_difference(
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    output reg [7:0] difference [0:15]
);

    integer i, j, k;
    reg [7:0] temp_diff1 [0:7];
    reg [7:0] temp_diff2 [0:7];
    reg found;
    reg duplicate;
    
    always @(*) begin
        // Initialize temporary arrays with sentinel
        for (i = 0; i < 8; i = i + 1) begin
            temp_diff1[i] = 8'hFF;
            temp_diff2[i] = 8'hFF;
        end
        
        // Process list1: find elements not in list2
        k = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (list1[i] != 8'hFF) begin
                found = 1'b0;
                for (j = 0; j < 8; j = j + 1) begin
                    if (list2[j] == list1[i]) begin
                        found = 1'b1;
                    end
                end
                
                if (!found) begin
                    // Check for duplicates in temp_diff1
                    duplicate = 1'b0;
                    for (j = 0; j < 8; j = j + 1) begin
                        if (temp_diff1[j] == list1[i]) begin
                            duplicate = 1'b1;
                        end
                    end
                    
                    if (!duplicate && k < 8) begin
                        temp_diff1[k] = list1[i];
                        k = k + 1;
                    end
                end
            end
        end
        
        // Process list2: find elements not in list1
        k = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (list2[i] != 8'hFF) begin
                found = 1'b0;
                for (j = 0; j < 8; j = j + 1) begin
                    if (list1[j] == list2[i]) begin
                        found = 1'b1;
                    end
                end
                
                if (!found) begin
                    // Check for duplicates in temp_diff2
                    duplicate = 1'b0;
                    for (j = 0; j < 8; j = j + 1) begin
                        if (temp_diff2[j] == list2[i]) begin
                            duplicate = 1'b1;
                        end
                    end
                    
                    if (!duplicate && k < 8) begin
                        temp_diff2[k] = list2[i];
                        k = k + 1;
                    end
                end
            end
        end
        
        // Combine results into output array
        for (i = 0; i < 8; i = i + 1) begin
            difference[i] = temp_diff1[i];
        end
        for (i = 0; i < 8; i = i + 1) begin
            difference[8 + i] = temp_diff2[i];
        end
    end

endmodule