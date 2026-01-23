module license_scheduling (
    input [2:0] n,
    input [5:0] s1,
    input [5:0] s2,
    input [7:0][5:0] t,
    output reg [2:0] max_customers
);

    integer i, j, k;
    reg [8:0][64:0][64:0] dp;

    always @(*) begin
        // Initialize DP table
        for (i = 0; i <= 8; i = i + 1) begin
            for (j = 0; j <= 64; j = j + 1) begin
                for (k = 0; k <= 64; k = k + 1) begin
                    dp[i][j][k] = 1'b0;
                end
            end
        end
        dp[0][0][0] = 1'b1;

        // Iterate through customers
        for (i = 0; i < n; i = i + 1) begin
            // Iterate through all possible counter times
            for (j = 0; j <= s1; j = j + 1) begin
                for (k = 0; k <= s2; k = k + 1) begin
                    if (dp[i][j][k]) begin
                        // Option 1: Assign to Counter 1
                        if (j + t[i] <= s1) begin
                            dp[i + 1][j + t[i]][k] = 1'b1;
                        end
                        // Option 2: Assign to Counter 2
                        if (k + t[i] <= s2) begin
                            dp[i + 1][j][k + t[i]] = 1'b1;
                        end
                        // Option 3: Customer leaves (stop processing)
                        // This implicitly means we don't update dp for further customers
                    end
                end
            end
        end

        // Find maximum number of customers served
        max_customers = 3'b000;
        for (i = n; i >= 0; i = i - 1) begin
            for (j = 0; j <= s1; j = j + 1) begin
                for (k = 0; k <= s2; k = k + 1) begin
                    if (dp[i][j][k]) begin
                        max_customers = i[2:0];
                        // Break loops (verilog doesn't support break, so we use flag checks or rely on priority)
                        // Since we iterate downwards, the first valid i is the max
                        // We can exit early by checking if max_customers is already set to current i
                        // But Verilog requires all loops to complete. 
                        // For combinational logic, we rely on the fact that higher 'i' overwrites lower ones in the loop.
                        // Wait, we iterate downwards, so the first hit is the maximum. 
                        // However, 'for' loops in always @(*) execute fully. 
                        // We need a way to stop or ensure the highest value is kept.
                        // Since we loop i downwards, the FIRST time we enter the inner loops with dp[i] true, we assign max_customers.
                        // But we can't break. 
                        // Alternative: Calculate a 'valid' flag for each i, then priority encode.
                    end
                end
            end
        end
        
        // Correction: The nested loops above will assign max_customers multiple times.
        // Since we iterate i from n down to 0, the highest 'i' processed first will assign the value.
        // But since Verilog loops run completely, we can't rely on order of assignment effectively for breaking.
        // Let's use a 'found' flag to make it robust.
        
        // Revised Logic for finding max_customers
        reg found;
        found = 0;
        max_customers = 3'b000;
        
        for (i = 8; i >= 0; i = i - 1) begin
            if (!found && i <= n) begin
                for (j = 0; j <= 64; j = j + 1) begin
                    if (!found && j <= s1) begin
                        for (k = 0; k <= 64; k = k + 1) begin
                            if (!found && k <= s2) begin
                                if (dp[i][j][k]) begin
                                    max_customers = i[2:0];
                                    found = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

endmodule