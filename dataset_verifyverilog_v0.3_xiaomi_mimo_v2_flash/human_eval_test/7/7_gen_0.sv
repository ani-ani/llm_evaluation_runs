module filter_by_substring (
    input [7:0] strings [0:3],
    input [7:0] substring [0:3],
    input [2:0] substring_len,
    output reg [3:0] mask
);

    // Helper signals for matching
    reg match [0:3];  // match per string
    reg [7:0] char_cmp [0:3][0:7][0:3];  // char_cmp[string][pos][sub_idx]
    reg pos_match [0:3][0:7];  // pos_match[string][start_pos]
    
    integer i, j, k;
    
    always @(*) begin
        // Initialize
        for (i = 0; i < 4; i = i + 1) begin
            match[i] = 1'b0;
            for (j = 0; j < 8; j = j + 1) begin
                pos_match[i][j] = 1'b0;
                for (k = 0; k < 4; k = k + 1) begin
                    char_cmp[i][j][k] = 8'd0;
                end
            end
        end
        mask = 4'b0000;
        
        // Handle edge case: substring_len = 0
        if (substring_len == 3'd0) begin
            mask = 4'b0000;
        end else begin
            // Check each string
            for (i = 0; i < 4; i = i + 1) begin
                // Check each starting position in string
                for (j = 0; j < 8; j = j + 1) begin
                    // Check if substring fits at position j
                    if ((j + substring_len) <= 8) begin
                        // Compare substring characters
                        reg all_chars_match;
                        all_chars_match = 1'b1;
                        for (k = 0; k < 4; k = k + 1) begin
                            if (k < substring_len) begin
                                // Compare character at position j+k with substring[k]
                                if (strings[i][(j+k)*8 +: 8] != substring[k]) begin
                                    all_chars_match = 1'b0;
                                end
                            end
                        end
                        pos_match[i][j] = all_chars_match;
                    end
                end
                
                // OR reduce all position matches for this string
                match[i] = pos_match[i][0] | pos_match[i][1] | pos_match[i][2] | pos_match[i][3] |
                          pos_match[i][4] | pos_match[i][5] | pos_match[i][6] | pos_match[i][7];
                
                // Set mask bit
                mask[i] = match[i];
            end
        end
    end

endmodule