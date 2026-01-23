module common_in_nested_lists (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    output reg [63:0] common_elements,
    output reg [2:0] count
);

    integer i, j, k;
    reg [7:0] common_list [0:7];
    reg found_in_list2;
    reg found_in_list3;
    reg is_duplicate;

    always @(*) begin
        // Initialize outputs
        common_elements = 64'b0;
        count = 3'b0;
        
        // Initialize common_list to zeros
        for (int idx = 0; idx < 8; idx = idx + 1) begin
            common_list[idx] = 8'b0;
        end
        
        // Check each element of list1
        for (i = 0; i < 8; i = i + 1) begin
            found_in_list2 = 1'b0;
            found_in_list3 = 1'b0;
            
            // Check if list1[i] exists in list2
            for (j = 0; j < 8; j = j + 1) begin
                if (list1[i] == list2[j]) begin
                    found_in_list2 = 1'b1;
                end
            end
            
            // Check if list1[i] exists in list3
            for (k = 0; k < 8; k = k + 1) begin
                if (list1[i] == list3[k]) begin
                    found_in_list3 = 1'b1;
                end
            end
            
            // If found in all three lists
            if (found_in_list2 && found_in_list3) begin
                // Check for duplicates in already added elements
                is_duplicate = 1'b0;
                for (int m = 0; m < count; m = m + 1) begin
                    if (list1[i] == common_list[m]) begin
                        is_duplicate = 1'b1;
                    end
                end
                
                // Add to result if not duplicate and we have space
                if (!is_duplicate && (count < 8)) begin
                    common_list[count] = list1[i];
                    count = count + 1;
                end
            end
        end
        
        // Pack elements into 64-bit output (LSB = first found element)
        for (int n = 0; n < 8; n = n + 1) begin
            if (n < count) begin
                common_elements[n*8 +: 8] = common_list[n];
            end else begin
                common_elements[n*8 +: 8] = 8'b0;
            end
        end
    end

endmodule
