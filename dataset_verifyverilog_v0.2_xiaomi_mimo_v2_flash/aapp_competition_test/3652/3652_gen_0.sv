module chemistry_table(
    input [7:0] row1_val_0, row1_val_1, row1_val_2, row1_val_3, row1_val_4, row1_val_5, row1_val_6, row1_val_7,
    input [7:0] row2_val_0, row2_val_1, row2_val_2, row2_val_3, row2_val_4, row2_val_5, row2_val_6, row2_val_7,
    input [7:0] row3_val_0, row3_val_1, row3_val_2, row3_val_3, row3_val_4, row3_val_5, row3_val_6, row3_val_7,
    output [3:0] min_deletions
);

    // Combinational logic to find max subset size where all 3 rows have same multiset of values
    reg [3:0] max_popcount;
    
    integer mask;
    reg [2:0] freq_r1 [1:8];
    reg [2:0] freq_r2 [1:8];
    reg [2:0] freq_r3 [1:8];
    reg valid;
    reg [3:0] popcnt;
    integer i, j;
    
    always @(*) begin
        max_popcount = 0;
        
        // Try all 256 possible column subsets
        for (mask = 0; mask < 256; mask = mask + 1) begin
            // Initialize frequencies to 0
            for (i = 1; i <= 8; i = i + 1) begin
                freq_r1[i] = 0;
                freq_r2[i] = 0;
                freq_r3[i] = 0;
            end
            
            // Count population of mask
            popcnt = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (mask[i]) popcnt = popcnt + 1;
            end
            
            // Skip if not larger than current max
            if (popcnt > max_popcount) begin
                // Count frequencies for each row based on mask
                if (mask[0]) begin
                    freq_r1[row1_val_0] = freq_r1[row1_val_0] + 1;
                    freq_r2[row2_val_0] = freq_r2[row2_val_0] + 1;
                    freq_r3[row3_val_0] = freq_r3[row3_val_0] + 1;
                end
                if (mask[1]) begin
                    freq_r1[row1_val_1] = freq_r1[row1_val_1] + 1;
                    freq_r2[row2_val_1] = freq_r2[row2_val_1] + 1;
                    freq_r3[row3_val_1] = freq_r3[row3_val_1] + 1;
                end
                if (mask[2]) begin
                    freq_r1[row1_val_2] = freq_r1[row1_val_2] + 1;
                    freq_r2[row2_val_2] = freq_r2[row2_val_2] + 1;
                    freq_r3[row3_val_2] = freq_r3[row3_val_2] + 1;
                end
                if (mask[3]) begin
                    freq_r1[row1_val_3] = freq_r1[row1_val_3] + 1;
                    freq_r2[row2_val_3] = freq_r2[row2_val_3] + 1;
                    freq_r3[row3_val_3] = freq_r3[row3_val_3] + 1;
                end
                if (mask[4]) begin
                    freq_r1[row1_val_4] = freq_r1[row1_val_4] + 1;
                    freq_r2[row2_val_4] = freq_r2[row2_val_4] + 1;
                    freq_r3[row3_val_4] = freq_r3[row3_val_4] + 1;
                end
                if (mask[5]) begin
                    freq_r1[row1_val_5] = freq_r1[row1_val_5] + 1;
                    freq_r2[row2_val_5] = freq_r2[row2_val_5] + 1;
                    freq_r3[row3_val_5] = freq_r3[row3_val_5] + 1;
                end
                if (mask[6]) begin
                    freq_r1[row1_val_6] = freq_r1[row1_val_6] + 1;
                    freq_r2[row2_val_6] = freq_r2[row2_val_6] + 1;
                    freq_r3[row3_val_6] = freq_r3[row3_val_6] + 1;
                end
                if (mask[7]) begin
                    freq_r1[row1_val_7] = freq_r1[row1_val_7] + 1;
                    freq_r2[row2_val_7] = freq_r2[row2_val_7] + 1;
                    freq_r3[row3_val_7] = freq_r3[row3_val_7] + 1;
                end
                
                // Check if all three rows have matching frequencies
                valid = 1;
                for (i = 1; i <= 8; i = i + 1) begin
                    if (freq_r1[i] != freq_r2[i] || freq_r2[i] != freq_r3[i]) begin
                        valid = 0;
                        break;
                    end
                end
                
                if (valid) begin
                    max_popcount = popcnt;
                end
            end
        end
    end
    
    assign min_deletions = 8 - max_popcount;

endmodule