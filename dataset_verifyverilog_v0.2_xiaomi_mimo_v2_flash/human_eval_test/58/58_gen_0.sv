module common_elements(
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    output logic [7:0] result [0:7],
    output logic [3:0] count
);

    // Internal signals
    logic [7:0] common [0:7]; // Raw common elements (up to 8)
    logic [7:0] unique [0:7]; // Deduplicated elements (sorted intermediate)
    logic [3:0] common_count;
    logic [3:0] unique_count;

    // Step 1: Find all elements present in both lists
    // We iterate through list1 and check against list2
    always_comb begin
        common_count = 0;
        for (int i = 0; i < 8; i++) begin
            common[i] = 0;
            for (int j = 0; j < 8; j++) begin
                if (list1[i] == list2[j]) begin
                    common[common_count] = list1[i];
                    common_count = common_count + 1;
                    break; // Found match, move to next element in list1
                end
            end
        end
    end

    // Step 2: Remove duplicates
    // We check if the current element has appeared before in the common array
    always_comb begin
        unique_count = 0;
        for (int i = 0; i < 8; i++) begin
            unique[i] = 0;
        end
        
        for (int i = 0; i < common_count; i++) begin
            logic is_duplicate;
            is_duplicate = 0;
            for (int j = 0; j < i; j++) begin
                if (common[i] == common[j]) begin
                    is_duplicate = 1;
                    break;
                end
            end
            
            if (!is_duplicate) begin
                unique[unique_count] = common[i];
                unique_count = unique_count + 1;
            end
        end
    end

    // Step 3 & 4: Sort (Bubble Sort) and Output assignment
    // Unrolled Bubble Sort for 8 elements (max)
    // We sort the unique array and place into result
    // Unused result positions are 0 by default
    always_comb begin
        logic [7:0] s [0:7];
        
        // Initialize with unique elements
        s = unique;

        // Pass 1
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        if (s[2] > s[3]) begin s[2] = s[3]; s[3] = s[2]; end
        if (s[3] > s[4]) begin s[3] = s[4]; s[4] = s[3]; end
        if (s[4] > s[5]) begin s[4] = s[5]; s[5] = s[4]; end
        if (s[5] > s[6]) begin s[5] = s[6]; s[6] = s[5]; end
        if (s[6] > s[7]) begin s[6] = s[7]; s[7] = s[6]; end
        // Pass 2
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        if (s[2] > s[3]) begin s[2] = s[3]; s[3] = s[2]; end
        if (s[3] > s[4]) begin s[3] = s[4]; s[4] = s[3]; end
        if (s[4] > s[5]) begin s[4] = s[5]; s[5] = s[4]; end
        if (s[5] > s[6]) begin s[5] = s[6]; s[6] = s[5]; end
        // Pass 3
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        if (s[2] > s[3]) begin s[2] = s[3]; s[3] = s[2]; end
        if (s[3] > s[4]) begin s[3] = s[4]; s[4] = s[3]; end
        if (s[4] > s[5]) begin s[4] = s[5]; s[5] = s[4]; end
        // Pass 4
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        if (s[2] > s[3]) begin s[2] = s[3]; s[3] = s[2]; end
        if (s[3] > s[4]) begin s[3] = s[4]; s[4] = s[3]; end
        // Pass 5
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        if (s[2] > s[3]) begin s[2] = s[3]; s[3] = s[2]; end
        // Pass 6
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end
        if (s[1] > s[2]) begin s[1] = s[2]; s[2] = s[1]; end
        // Pass 7
        if (s[0] > s[1]) begin s[0] = s[1]; s[1] = s[0]; end

        // Assign sorted values to result and reset unused
        for (int k = 0; k < 8; k++) begin
            if (k < unique_count) begin
                result[k] = s[k];
            end else begin
                result[k] = 8'h00;
            end
        end
    end

    assign count = unique_count;

endmodule