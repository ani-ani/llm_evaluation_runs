module cycpattern_check (
    input [63:0] a,
    input [63:0] b,
    input [3:0] len_a,
    input [3:0] len_b,
    output reg result
);

    // Internal variables for rotated strings (8 potential rotations)
    reg [63:0] rot_b [0:7];
    
    // Combinational logic block
    always @(*) begin
        // Initialize rotation array
        // b is stored in little-endian: b[7:0] is char 0, b[15:8] is char 1, ...
        // rot_b[i] is b rotated left by i positions
        
        rot_b[0] = b;
        rot_b[1] = {b[55:0], b[63:56]};
        rot_b[2] = {b[47:0], b[63:48]};
        rot_b[3] = {b[39:0], b[63:40]};
        rot_b[4] = {b[31:0], b[63:32]};
        rot_b[5] = {b[23:0], b[63:24]};
        rot_b[6] = {b[15:0], b[63:16]};
        rot_b[7] = {b[7:0], b[63:8]};
        
        // Default result
        result = 0;
        
        // Only check if b is not longer than a and lengths are valid (>0)
        if (len_b <= len_a && len_b != 0) begin
            // Check each rotation
            // Unrolled loop for synthesis efficiency
            
            // Rotation 0
            if (!result) begin
                // Check all valid start positions in a
                if (len_a >= len_b) begin
                    // Check position 0
                    if (len_b >= 1 && a[7:0] != rot_b[0][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[0][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[0][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[0][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[0][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[0][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[0][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[0][63:56]) begin end
                    else result = 1;
                    
                    // Check position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[0][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[0][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[0][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[0][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[0][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[0][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Check position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[0][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[0][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[0][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[0][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[0][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Check position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[0][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[0][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[0][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[0][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Check position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[0][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[0][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[0][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Check position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[0][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[0][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Check position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[0][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[0][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Check position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[0][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 1
            if (!result && len_b >= 2) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[1][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[1][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[1][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[1][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[1][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[1][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[1][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[1][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[1][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[1][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[1][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[1][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[1][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[1][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[1][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[1][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[1][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[1][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[1][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[1][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[1][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[1][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[1][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[1][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[1][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[1][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[1][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[1][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[1][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[1][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[1][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 2
            if (!result && len_b >= 3) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[2][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[2][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[2][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[2][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[2][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[2][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[2][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[2][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[2][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[2][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[2][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[2][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[2][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[2][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[2][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[2][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[2][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[2][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[2][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[2][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[2][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[2][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[2][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[2][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[2][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[2][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[2][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[2][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[2][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[2][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[2][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 3
            if (!result && len_b >= 4) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[3][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[3][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[3][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[3][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[3][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[3][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[3][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[3][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[3][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[3][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[3][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[3][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[3][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[3][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[3][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[3][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[3][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[3][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[3][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[3][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[3][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[3][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[3][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[3][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[3][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[3][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[3][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[3][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[3][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[3][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[3][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 4
            if (!result && len_b >= 5) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[4][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[4][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[4][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[4][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[4][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[4][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[4][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[4][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[4][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[4][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[4][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[4][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[4][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[4][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[4][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[4][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[4][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[4][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[4][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[4][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[4][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[4][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[4][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[4][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[4][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[4][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[4][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[4][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[4][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[4][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[4][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 5
            if (!result && len_b >= 6) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[5][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[5][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[5][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[5][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[5][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[5][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[5][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[5][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[5][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[5][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[5][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[5][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[5][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[5][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[5][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[5][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[5][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[5][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[5][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[5][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[5][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[5][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[5][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[5][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[5][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[5][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[5][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[5][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[5][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[5][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[5][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 6
            if (!result && len_b >= 7) begin
                // Position 0
                if (len_a >= len_b) begin
                    if (len_b >= 1 && a[7:0] != rot_b[6][7:0]) begin end
                    else if (len_b >= 2 && a[15:8] != rot_b[6][15:8]) begin end
                    else if (len_b >= 3 && a[23:16] != rot_b[6][23:16]) begin end
                    else if (len_b >= 4 && a[31:24] != rot_b[6][31:24]) begin end
                    else if (len_b >= 5 && a[39:32] != rot_b[6][39:32]) begin end
                    else if (len_b >= 6 && a[47:40] != rot_b[6][47:40]) begin end
                    else if (len_b >= 7 && a[55:48] != rot_b[6][55:48]) begin end
                    else if (len_b >= 8 && a[63:56] != rot_b[6][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= len_b + 1) begin
                        if (len_b >= 1 && a[15:8] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[23:16] != rot_b[6][15:8]) begin end
                        else if (len_b >= 3 && a[31:24] != rot_b[6][23:16]) begin end
                        else if (len_b >= 4 && a[39:32] != rot_b[6][31:24]) begin end
                        else if (len_b >= 5 && a[47:40] != rot_b[6][39:32]) begin end
                        else if (len_b >= 6 && a[55:48] != rot_b[6][47:40]) begin end
                        else if (len_b >= 7 && a[63:56] != rot_b[6][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= len_b + 2) begin
                        if (len_b >= 1 && a[23:16] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[31:24] != rot_b[6][15:8]) begin end
                        else if (len_b >= 3 && a[39:32] != rot_b[6][23:16]) begin end
                        else if (len_b >= 4 && a[47:40] != rot_b[6][31:24]) begin end
                        else if (len_b >= 5 && a[55:48] != rot_b[6][39:32]) begin end
                        else if (len_b >= 6 && a[63:56] != rot_b[6][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= len_b + 3) begin
                        if (len_b >= 1 && a[31:24] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[39:32] != rot_b[6][15:8]) begin end
                        else if (len_b >= 3 && a[47:40] != rot_b[6][23:16]) begin end
                        else if (len_b >= 4 && a[55:48] != rot_b[6][31:24]) begin end
                        else if (len_b >= 5 && a[63:56] != rot_b[6][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= len_b + 4) begin
                        if (len_b >= 1 && a[39:32] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[47:40] != rot_b[6][15:8]) begin end
                        else if (len_b >= 3 && a[55:48] != rot_b[6][23:16]) begin end
                        else if (len_b >= 4 && a[63:56] != rot_b[6][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= len_b + 5) begin
                        if (len_b >= 1 && a[47:40] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[55:48] != rot_b[6][15:8]) begin end
                        else if (len_b >= 3 && a[63:56] != rot_b[6][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= len_b + 6) begin
                        if (len_b >= 1 && a[55:48] != rot_b[6][7:0]) begin end
                        else if (len_b >= 2 && a[63:56] != rot_b[6][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= len_b + 7) begin
                        if (len_b >= 1 && a[63:56] != rot_b[6][7:0]) begin end
                        else result = 1;
                    end
                end
            end
            
            // Rotation 7
            if (!result && len_b == 8) begin
                // Position 0
                if (len_a >= 8) begin
                    if (a[7:0] != rot_b[7][7:0]) begin end
                    else if (a[15:8] != rot_b[7][15:8]) begin end
                    else if (a[23:16] != rot_b[7][23:16]) begin end
                    else if (a[31:24] != rot_b[7][31:24]) begin end
                    else if (a[39:32] != rot_b[7][39:32]) begin end
                    else if (a[47:40] != rot_b[7][47:40]) begin end
                    else if (a[55:48] != rot_b[7][55:48]) begin end
                    else if (a[63:56] != rot_b[7][63:56]) begin end
                    else result = 1;
                    
                    // Position 1
                    if (!result && len_a >= 9) begin // Impossible for 8-char a, but kept for consistency
                        if (a[15:8] != rot_b[7][7:0]) begin end
                        else if (a[23:16] != rot_b[7][15:8]) begin end
                        else if (a[31:24] != rot_b[7][23:16]) begin end
                        else if (a[39:32] != rot_b[7][31:24]) begin end
                        else if (a[47:40] != rot_b[7][39:32]) begin end
                        else if (a[55:48] != rot_b[7][47:40]) begin end
                        else if (a[63:56] != rot_b[7][55:48]) begin end
                        else result = 1;
                    end
                    
                    // Position 2
                    if (!result && len_a >= 10) begin
                        if (a[23:16] != rot_b[7][7:0]) begin end
                        else if (a[31:24] != rot_b[7][15:8]) begin end
                        else if (a[39:32] != rot_b[7][23:16]) begin end
                        else if (a[47:40] != rot_b[7][31:24]) begin end
                        else if (a[55:48] != rot_b[7][39:32]) begin end
                        else if (a[63:56] != rot_b[7][47:40]) begin end
                        else result = 1;
                    end
                    
                    // Position 3
                    if (!result && len_a >= 11) begin
                        if (a[31:24] != rot_b[7][7:0]) begin end
                        else if (a[39:32] != rot_b[7][15:8]) begin end
                        else if (a[47:40] != rot_b[7][23:16]) begin end
                        else if (a[55:48] != rot_b[7][31:24]) begin end
                        else if (a[63:56] != rot_b[7][39:32]) begin end
                        else result = 1;
                    end
                    
                    // Position 4
                    if (!result && len_a >= 12) begin
                        if (a[39:32] != rot_b[7][7:0]) begin end
                        else if (a[47:40] != rot_b[7][15:8]) begin end
                        else if (a[55:48] != rot_b[7][23:16]) begin end
                        else if (a[63:56] != rot_b[7][31:24]) begin end
                        else result = 1;
                    end
                    
                    // Position 5
                    if (!result && len_a >= 13) begin
                        if (a[47:40] != rot_b[7][7:0]) begin end
                        else if (a[55:48] != rot_b[7][15:8]) begin end
                        else if (a[63:56] != rot_b[7][23:16]) begin end
                        else result = 1;
                    end
                    
                    // Position 6
                    if (!result && len_a >= 14) begin
                        if (a[55:48] != rot_b[7][7:0]) begin end
                        else if (a[63:56] != rot_b[7][15:8]) begin end
                        else result = 1;
                    end
                    
                    // Position 7
                    if (!result && len_a >= 15) begin
                        if (a[63:56] != rot_b[7][7:0]) begin end
                        else result = 1;
                    end
                end
            end
        end
    end

endmodule
