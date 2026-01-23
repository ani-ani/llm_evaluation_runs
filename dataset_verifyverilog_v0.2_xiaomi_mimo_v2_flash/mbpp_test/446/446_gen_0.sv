module count_occurrence (
    input [7:0] tuple_data,
    input [2:0] tuple_len,
    input [7:0] list_data,
    input [2:0] list_len,
    output reg [3:0] result
);

    // Intermediate storage for individual elements
    reg [7:0] tuple_elem [0:7];
    reg [7:0] list_elem [0:7];
    
    // Match matrix: tuple_idx x list_idx
    wire match [0:7][0:7];
    
    // Validity flags for elements based on length
    reg valid_tuple [0:7];
    reg valid_list [0:7];
    
    integer i, j;
    
    // Extract elements from packed inputs
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            tuple_elem[i] = tuple_data[i*8 +: 8];
            list_elem[i] = list_data[i*8 +: 8];
        end
    end
    
    // Determine validity of elements
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            valid_tuple[i] = (i < tuple_len);
            valid_list[i] = (i < list_len);
        end
    end
    
    // Parallel comparators for all combinations
    generate
        genvar ti, li;
        for (ti = 0; ti < 8; ti = ti + 1) begin : tuple_gen
            for (li = 0; li < 8; li = li + 1) begin : list_gen
                // Match if both are valid and values are equal
                assign match[ti][li] = valid_tuple[ti] && valid_list[li] && (tuple_elem[ti] == list_elem[li]);
            end
        end
    endgenerate
    
    // Count matches for each tuple element (OR reduction across list elements)
    // Then sum them up
    always @(*) begin
        reg [3:0] count;
        reg tuple_match;
        
        count = 4'b0000;
        
        for (i = 0; i < 8; i = i + 1) begin
            tuple_match = 1'b0;
            
            // Check if this tuple element matched any list element
            if (valid_tuple[i]) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (valid_list[j] && match[i][j]) begin
                        tuple_match = 1'b1;
                    end
                end
            end
            
            // Only count distinct tuple elements that have at least one match
            // Since we're counting occurrences of tuple elements in the list,
            // we count 1 for each tuple element if it appears in the list
            if (tuple_match) begin
                count = count + 1;
            end
        end
        
        result = count;
    end

endmodule