module list_filter (
    input [23:0] list1,
    input [23:0] list2,
    input [2:0] valid2,
    output reg [23:0] result,
    output reg [2:0] result_valid
);

    // Define unpacked arrays for easier indexing
    wire [7:0] l1 [2:0];
    wire [7:0] l2 [2:0];
    
    // Map packed inputs to unpacked arrays
    assign l1[0] = list1[7:0];
    assign l1[1] = list1[15:8];
    assign l1[2] = list1[23:16];
    
    assign l2[0] = list2[7:0];
    assign l2[1] = list2[15:8];
    assign l2[2] = list2[23:16];

    // Generate comparison matrix: compare_list1[i][j] is high if l1[i] == l2[j] AND l2[j] is valid
    wire compare_list1 [2:0][2:0];
    
    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin : comp_row
            for (j = 0; j < 3; j = j + 1) begin : comp_col
                // Compare only if list2 entry is valid
                assign compare_list1[i][j] = (l1[i] == l2[j]) & valid2[j];
            end
        end
    endgenerate

    // For each list1 element, OR reduce its comparisons to see if it matches any valid list2 element
    wire match_found [2:0];
    
    generate
        for (i = 0; i < 3; i = i + 1) begin : match_or
            assign match_found[i] = compare_list1[i][0] | compare_list1[i][1] | compare_list1[i][2];
        end
    endgenerate

    // Output logic: element is kept if NO match is found (match_found[i] is low)
    // If match_found[i] is high, result is 0 and valid bit is 0.
    
    always @(*) begin
        // Default assignments
        result = 24'b0;
        result_valid = 3'b0;
        
        // Check each element of list1
        if (!match_found[0]) begin
            result[7:0] = l1[0];
            result_valid[0] = 1'b1;
        end
        
        if (!match_found[1]) begin
            result[15:8] = l1[1];
            result_valid[1] = 1'b1;
        end
        
        if (!match_found[2]) begin
            result[23:16] = l1[2];
            result_valid[2] = 1'b1;
        end
    end

endmodule
