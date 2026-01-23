module unique_sorter (
    input [7:0][15:0] numbers,
    output reg [7:0][15:0] result
);
    // Stage 1: Sorting network (bitonic merge sort network for 8 elements)
    // Step 1: Sort pairs
    wire [15:0] sorted0[0:7];
    assign sorted0[0] = (numbers[0] < numbers[1]) ? numbers[0] : numbers[1];
    assign sorted0[1] = (numbers[0] < numbers[1]) ? numbers[1] : numbers[0];
    assign sorted0[2] = (numbers[2] < numbers[3]) ? numbers[2] : numbers[3];
    assign sorted0[3] = (numbers[2] < numbers[3]) ? numbers[3] : numbers[2];
    assign sorted0[4] = (numbers[4] < numbers[5]) ? numbers[4] : numbers[5];
    assign sorted0[5] = (numbers[4] < numbers[5]) ? numbers[5] : numbers[4];
    assign sorted0[6] = (numbers[6] < numbers[7]) ? numbers[6] : numbers[7];
    assign sorted0[7] = (numbers[6] < numbers[7]) ? numbers[7] : numbers[6];
    
    // Step 2: Sort 4-element groups (bitonic merge)
    wire [15:0] sorted1[0:7];
    // Compare across groups
    assign sorted1[0] = (sorted0[0] < sorted0[2]) ? sorted0[0] : sorted0[2];
    assign sorted1[1] = (sorted0[1] < sorted0[3]) ? sorted0[1] : sorted0[3];
    assign sorted1[2] = (sorted0[0] < sorted0[2]) ? sorted0[2] : sorted0[0];
    assign sorted1[3] = (sorted0[1] < sorted0[3]) ? sorted0[3] : sorted0[1];
    assign sorted1[4] = (sorted0[4] < sorted0[6]) ? sorted0[4] : sorted0[6];
    assign sorted1[5] = (sorted0[5] < sorted0[7]) ? sorted0[5] : sorted0[7];
    assign sorted1[6] = (sorted0[4] < sorted0[6]) ? sorted0[6] : sorted0[4];
    assign sorted1[7] = (sorted0[5] < sorted0[7]) ? sorted0[7] : sorted0[5];
    
    // Step 3: Sort within groups
    wire [15:0] sorted2[0:7];
    // First group (0-3)
    assign sorted2[0] = (sorted1[0] < sorted1[1]) ? sorted1[0] : sorted1[1];
    assign sorted2[1] = (sorted1[0] < sorted1[1]) ? sorted1[1] : sorted1[0];
    assign sorted2[2] = (sorted1[2] < sorted1[3]) ? sorted1[2] : sorted1[3];
    assign sorted2[3] = (sorted1[2] < sorted1[3]) ? sorted1[3] : sorted1[2];
    // Second group (4-7)
    assign sorted2[4] = (sorted1[4] < sorted1[5]) ? sorted1[4] : sorted1[5];
    assign sorted2[5] = (sorted1[4] < sorted1[5]) ? sorted1[5] : sorted1[4];
    assign sorted2[6] = (sorted1[6] < sorted1[7]) ? sorted1[6] : sorted1[7];
    assign sorted2[7] = (sorted1[6] < sorted1[7]) ? sorted1[7] : sorted1[6];
    
    // Step 4: Final merge (merge the two 4-element sorted groups)
    wire [15:0] sorted3[0:7];
    // Bitonic merge of groups 0-3 and 4-7
    assign sorted3[0] = (sorted2[0] < sorted2[4]) ? sorted2[0] : sorted2[4];
    assign sorted3[1] = (sorted2[1] < sorted2[5]) ? sorted2[1] : sorted2[5];
    assign sorted3[2] = (sorted2[2] < sorted2[6]) ? sorted2[2] : sorted2[6];
    assign sorted3[3] = (sorted2[3] < sorted2[7]) ? sorted2[3] : sorted2[7];
    assign sorted3[4] = (sorted2[0] < sorted2[4]) ? sorted2[4] : sorted2[0];
    assign sorted3[5] = (sorted2[1] < sorted2[5]) ? sorted2[5] : sorted2[1];
    assign sorted3[6] = (sorted2[2] < sorted2[6]) ? sorted2[6] : sorted2[2];
    assign sorted3[7] = (sorted2[3] < sorted2[7]) ? sorted2[7] : sorted2[3];
    
    // Step 5: Final sort within the merged result
    wire [15:0] sorted[0:7];
    // Compare and swap adjacent pairs in the sorted result
    assign sorted[0] = (sorted3[0] < sorted3[1]) ? sorted3[0] : sorted3[1];
    assign sorted[1] = (sorted3[0] < sorted3[1]) ? sorted3[1] : sorted3[0];
    assign sorted[2] = (sorted3[2] < sorted3[3]) ? sorted3[2] : sorted3[3];
    assign sorted[3] = (sorted3[2] < sorted3[3]) ? sorted3[3] : sorted3[2];
    assign sorted[4] = (sorted3[4] < sorted3[5]) ? sorted3[4] : sorted3[5];
    assign sorted[5] = (sorted3[4] < sorted3[5]) ? sorted3[5] : sorted3[4];
    assign sorted[6] = (sorted3[6] < sorted3[7]) ? sorted3[6] : sorted3[7];
    assign sorted[7] = (sorted3[6] < sorted3[7]) ? sorted3[7] : sorted3[6];
    
    // Stage 2: Duplicate removal (combinational logic)
    // We need to compact unique values to the left
    // Step 1: Mark duplicates
    reg [0:7] is_duplicate;
    integer i;
    
    always @(*) begin
        // Initialize all to not duplicate
        is_duplicate[0] = 1'b0;
        is_duplicate[1] = (sorted[1] == sorted[0]) ? 1'b1 : 1'b0;
        is_duplicate[2] = (sorted[2] == sorted[0] || sorted[2] == sorted[1]) ? 1'b1 : 1'b0;
        is_duplicate[3] = 1'b0;
        is_duplicate[4] = 1'b0;
        is_duplicate[5] = 1'b0;
        is_duplicate[6] = 1'b0;
        is_duplicate[7] = 1'b0;
        
        // Check against all previous unique values
        for (i = 1; i < 8; i = i + 1) begin
            if (!is_duplicate[i]) begin
                is_duplicate[i] = 1'b0;
                // Check if this value appears earlier in the array
                for (int j = 0; j < i; j = j + 1) begin
                    if (!is_duplicate[j] && sorted[i] == sorted[j]) begin
                        is_duplicate[i] = 1'b1;
                    end
                end
            end
        end
    end
    
    // Step 2: Compact unique values to the left
    reg [15:0] temp_result[0:7];
    integer write_idx;
    
    always @(*) begin
        // Initialize temp_result to zero
        for (int k = 0; k < 8; k = k + 1) begin
            temp_result[k] = 16'd0;
        end
        
        write_idx = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!is_duplicate[i]) begin
                temp_result[write_idx] = sorted[i];
                write_idx = write_idx + 1;
            end
        end
    end
    
    // Stage 3: Assign to output
    always @(*) begin
        for (int k = 0; k < 8; k = k + 1) begin
            result[k] = temp_result[k];
        end
    end
    
endmodule