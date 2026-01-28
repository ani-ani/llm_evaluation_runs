module ball_arrangement(
    input [1:0] count1, count2,
    input [1:0] forbidden,
    input [1:0] pattern_length,
    input [1:0] pattern0,
    input [1:0] pattern1,
    output reg [31:0] result
);

    reg [1:0] perms [0:11][0:3];
    reg [11:0] valid_perms;
    reg [3:0] pattern_counts [0:11];
    reg [3:0] max_pattern_count;
    reg [3:0] count_valid;
    integer i, j, k, perm_count, total_balls;
    
    always @(*) begin
        perm_count = 0;
        total_balls = {1'b0, count1} + {1'b0, count2};
        result = 0;
        max_pattern_count = 0;
        count_valid = 0;
        valid_perms = 12'b0;
        
        // Initialize all permutations
        for (i = 0; i < 12; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                perms[i][j] = 2'd0;
            end
            pattern_counts[i] = 4'd0;
        end
        
        // Generate permutations
        if (count1 == 2'd0 && count2 == 2'd0) begin
            perm_count = 1;
        end else if (count1 == 2'd1 && count2 == 2'd0) begin
            perms[0][0] = 2'd1;
            perm_count = 1;
        end else if (count1 == 2'd0 && count2 == 2'd1) begin
            perms[0][0] = 2'd2;
            perm_count = 1;
        end else if (count1 == 2'd2 && count2 == 2'd0) begin
            perms[0][0] = 2'd1;
            perms[0][1] = 2'd1;
            perm_count = 1;
        end else if (count1 == 2'd0 && count2 == 2'd2) begin
            perms[0][0] = 2'd2;
            perms[0][1] = 2'd2;
            perm_count = 1;
        end else if (count1 == 2'd1 && count2 == 2'd1) begin
            perms[0][0] = 2'd1;
            perms[0][1] = 2'd2;
            perms[1][0] = 2'd2;
            perms[1][1] = 2'd1;
            perm_count = 2;
        end else if (count1 == 2'd3 && count2 == 2'd0) begin
            perms[0][0] = 2'd1;
            perms[0][1] = 2'd1;
            perms[0][2] = 2'd1;
            perm_count = 1;
        end else if (count1 == 2'd0 && count2 == 2'd3) begin
            perms[0][0] = 2'd2;
            perms[0][1] = 2'd2;
            perms[0][2] = 2'd2;
            perm_count = 1;
        end else if (count1 == 2'd2 && count2 == 2'd1) begin
            perms[0][0] = 2'd1;
            perms[0][1] = 2'd1;
            perms[0][2] = 2'd2;
            perms[1][0] = 2'd1;
            perms[1][1] = 2'd2;
            perms[1][2] = 2'd1;
            perms[2][0] = 2'd2;
            perms[2][1] = 2'd1;
            perms[2][2] = 2'd1;
            perm_count = 3;
        end else if (count1 == 2'd1 && count2 == 2'd2) begin
            perms[0][0] = 2'd2;
            perms[0][1] = 2'd2;
            perms[0][2] = 2'd1;
            perms[1][0] = 2'd2;
            perms[1][1] = 2'd1;
            perms[1][2] = 2'd2;
            perms[2][0] = 2'd1;
            perms[2][1] = 2'd2;
            perms[2][2] = 2'd2;
            perm_count = 3;
        end else if (count1 == 2'd2 && count2 == 2'd2) begin
            perms[0][0] = 2'd1;
            perms[0][1] = 2'd1;
            perms[0][2] = 2'd2;
            perms[0][3] = 2'd2;
            perms[1][0] = 2'd1;
            perms[1][1] = 2'd2;
            perms[1][2] = 2'd1;
            perms[1][3] = 2'd2;
            perms[2][0] = 2'd1;
            perms[2][1] = 2'd2;
            perms[2][2] = 2'd2;
            perms[2][3] = 2'd1;
            perms[3][0] = 2'd2;
            perms[3][1] = 2'd1;
            perms[3][2] = 2'd1;
            perms[3][3] = 2'd2;
            perms[4][0] = 2'd2;
            perms[4][1] = 2'd1;
            perms[4][2] = 2'd2;
            perms[4][3] = 2'd1;
            perms[5][0] = 2'd2;
            perms[5][1] = 2'd2;
            perms[5][2] = 2'd1;
            perms[5][3] = 2'd1;
            perm_count = 6;
        end
        
        // Check each permutation
        for (i = 0; i < 12; i = i + 1) begin
            if (i < perm_count) begin
                // Check adjacency constraints
                valid_perms[i] = 1'b1;
                for (j = 0; j < total_balls - 1; j = j + 1) begin
                    if (((perms[i][j] == 2'd1 && forbidden[0]) || 
                         (perms[i][j] == 2'd2 && forbidden[1])) &&
                        ((perms[i][j+1] == 2'd1 && forbidden[0]) ||
                         (perms[i][j+1] == 2'd2 && forbidden[1]))) begin
                        valid_perms[i] = 1'b0;
                    end
                end
                
                // Count pattern occurrences
                pattern_counts[i] = 4'd0;
                if (pattern_length == 2'd1) begin
                    for (j = 0; j < total_balls; j = j + 1) begin
                        if (perms[i][j] == pattern0) begin
                            pattern_counts[i] = pattern_counts[i] + 4'd1;
                        end
                    end
                end else if (pattern_length == 2'd2) begin
                    for (j = 0; j < total_balls - 1; j = j + 1) begin
                        if (perms[i][j] == pattern0 && perms[i][j+1] == pattern1) begin
                            pattern_counts[i] = pattern_counts[i] + 4'd1;
                        end
                    end
                end
                
                // Update max pattern count
                if (valid_perms[i] && pattern_counts[i] > max_pattern_count) begin
                    max_pattern_count = pattern_counts[i];
                end
            end
        end
        
        // Count arrangements achieving max pattern count
        for (i = 0; i < 12; i = i + 1) begin
            if (i < perm_count && valid_perms[i] && pattern_counts[i] == max_pattern_count) begin
                count_valid = count_valid + 4'd1;
            end
        end
        
        result = {28'd0, count_valid};
    end
endmodule