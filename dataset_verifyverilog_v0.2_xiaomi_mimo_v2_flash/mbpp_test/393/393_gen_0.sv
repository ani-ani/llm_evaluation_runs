module max_length_list (
    input        [3:0]      valid_mask,
    input        [3:0][3:0][7:0] lists,
    output logic [1:0]      max_length_idx,
    output logic [3:0][7:0] max_list,
    output logic [2:0]      max_length
);

    // Internal signals to store lengths and validity for each list
    logic [2:0] len [0:3]; // Lengths 0 to 4
    logic       valid [0:3];

    // Helper function to count non-zero elements (regardless of valid_mask)
    function automatic logic [2:0] get_len(input [3:0][7:0] l);
        logic [2:0] count;
        count = 3'd0;
        if (l[0] != 8'd0) count = count + 1;
        if (l[1] != 8'd0) count = count + 1;
        if (l[2] != 8'd0) count = count + 1;
        if (l[3] != 8'd0) count = count + 1;
        return count;
    endfunction

    // Step 1: Calculate lengths and check valid_mask
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            // Only consider lists marked as valid in the mask
            if (valid_mask[i]) begin
                len[i] = get_len(lists[i]);
                valid[i] = 1'b1;
            end else begin
                len[i] = 3'd0;
                valid[i] = 1'b0;
            end
        end
    end

    // Step 2: Find max length among valid lists using a tree structure
    // We will implement a comparator tree logic within a combinational block
    // Logic: Compare pairs, then winners, etc. Tie-breaking by lower index.
    
    // Intermediate comparison results
    logic [2:0] max_len_01, max_len_23;
    logic [1:0] idx_01, idx_23;
    logic       valid_01, valid_23;

    // Compare List 0 vs List 1
    always_comb begin
        // Default to list 0
        max_len_01 = len[0];
        idx_01 = 2'b00;
        valid_01 = valid[0];

        // If list 1 is valid
        if (valid[1]) begin
            if (!valid[0] || (len[1] > len[0])) begin
                max_len_01 = len[1];
                idx_01 = 2'b01;
                valid_01 = 1'b1;
            end
            // If equal, keep lower index (0), so no change needed
        end
    end

    // Compare List 2 vs List 3
    always_comb begin
        // Default to list 2
        max_len_23 = len[2];
        idx_23 = 2'b10;
        valid_23 = valid[2];

        // If list 3 is valid
        if (valid[3]) begin
            if (!valid[2] || (len[3] > len[2])) begin
                max_len_23 = len[3];
                idx_23 = 2'b11;
                valid_23 = 1'b1;
            end
            // If equal, keep lower index (2), so no change needed
        end
    end

    // Final Comparison
    always_comb begin
        // Default
        max_length = max_len_01;
        max_length_idx = idx_01;

        if (valid_01 && valid_23) begin
            if (max_len_23 > max_len_01) begin
                max_length = max_len_23;
                max_length_idx = idx_23;
            end
            // If equal, keep lower index (idx_01 is 0-1, idx_23 is 2-3, so idx_01 is always lower if indices are compared numerically)
        end else if (valid_23) begin
            max_length = max_len_23;
            max_length_idx = idx_23;
        end else if (valid_01) begin
            max_length = max_len_01;
            max_length_idx = idx_01;
        end else begin
            // No valid lists
            max_length = 3'd0;
            max_length_idx = 2'b00;
        end
    end

    // Step 3: Select the max list based on the found index
    always_comb begin
        // Default initialization to zeros
        max_list = '{default:0};
        
        case (max_length_idx)
            2'b00: max_list = lists[0];
            2'b01: max_list = lists[1];
            2'b10: max_list = lists[2];
            2'b11: max_list = lists[3];
            default: max_list = '{default:0};
        endcase
    end

endmodule