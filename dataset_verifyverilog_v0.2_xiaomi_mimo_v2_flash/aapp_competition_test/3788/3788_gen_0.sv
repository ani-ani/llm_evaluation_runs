module bst_solver_8(
    input [7:0][15:0] nums,
    output reg possible
);
    // Internal signals and registers for DP
    // dp[l][r][0]: range [l, r] can be a left subtree (parent index is l-1)
    // dp[l][r][1]: range [l, r] can be a right subtree (parent index is r+1)
    reg dp[7:0][7:0][1:0];
    
    // Valid edge matrix
    reg valid_edge[7:0][7:0];
    
    // Helper signals for GCD calculation
    // Using simple Euclidean algorithm logic or LUT for small range
    // Since inputs are up to 1000, we can compute GCDs.
    // To ensure combinational logic is efficient, we precompute valid edges.
    
    // GCD function
    function automatic integer gcd;
        input integer a;
        input integer b;
        integer t;
        begin
            t = a;
            a = b;
            b = t;
            while (b != 0) begin
                t = b;
                b = a % b;
                a = t;
            end
            gcd = a;
        end
    endfunction
    
    integer i, j, k, l, r;
    integer g;
    
    always @(*) begin
        // 1. Generate GCD Matrix
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (i == j) begin
                    valid_edge[i][j] = 0;
                end else begin
                    g = gcd(nums[i], nums[j]);
                    valid_edge[i][j] = (g > 1);
                end
            end
        end
        
        // 2. Dynamic Programming
        // Initialize all to 0
        for (l = 0; l < 8; l = l + 1) begin
            for (r = 0; r < 8; r = r + 1) begin
                dp[l][r][0] = 0;
                dp[l][r][1] = 0;
            end
        end
        
        // Base cases: Length 1 ranges (Single nodes)
        // A single node i can form a left subtree if it connects to parent l-1 (which is i-1 in range [i, i])
        // Actually, for [i, i] to be left subtree, parent is i-1. Valid if edge(i, i-1).
        // For [i, i] to be right subtree, parent is i+1. Valid if edge(i, i+1).
        for (i = 0; i < 8; i = i + 1) begin
            // Check dp[i][i][0] (left subtree condition)
            if (i > 0)
                dp[i][i][0] = valid_edge[i][i-1];
            else
                dp[i][i][0] = 0; // No parent on left for index 0
                
            // Check dp[i][i][1] (right subtree condition)
            if (i < 7)
                dp[i][i][1] = valid_edge[i][i+1];
            else
                dp[i][i][1] = 0; // No parent on right for index 7
        end
        
        // DP for lengths 2 to 8
        // Iterate length of range
        for (int len = 2; len <= 8; len = len + 1) begin
            // Iterate start index l
            for (l = 0; l <= 8 - len; l = l + 1) begin
                r = l + len - 1;
                
                // Check if [l, r] can be a left subtree (parent is l-1)
                if (l > 0) begin
                    // Try every node k in [l, r] as the root
                    for (k = l; k <= r; k = k + 1) begin
                        // Root k must connect to parent l-1
                        if (valid_edge[k][l-1]) begin
                            // Left child of k: range [l, k-1] must be valid right subtree relative to k
                            // This means for range [l, k-1], the parent is k (r+1 of that range)
                            // So we need dp[l][k-1][1] to be true.
                            // Right child of k: range [k+1, r] must be valid left subtree relative to k
                            // This means for range [k+1, r], the parent is k (l-1 of that range)
                            // So we need dp[k+1][r][0] to be true.
                            
                            // Edge cases for empty ranges
                            bit left_ok, right_ok;
                            left_ok = (l > k-1) ? 1'b1 : dp[l][k-1][1];
                            right_ok = (k+1 > r) ? 1'b1 : dp[k+1][r][0];
                            
                            if (left_ok && right_ok) begin
                                dp[l][r][0] = 1;
                                break; // Found valid config
                            end
                        end
                    end
                end
                
                // Check if [l, r] can be a right subtree (parent is r+1)
                if (r < 7) begin
                    for (k = l; k <= r; k = k + 1) begin
                        // Root k must connect to parent r+1
                        if (valid_edge[k][r+1]) begin
                            // Left child: [l, k-1] needs to be valid right subtree for k
                            // i.e. dp[l][k-1][1]
                            // Right child: [k+1, r] needs to be valid left subtree for k
                            // i.e. dp[k+1][r][0]
                            
                            bit left_ok, right_ok;
                            left_ok = (l > k-1) ? 1'b1 : dp[l][k-1][1];
                            right_ok = (k+1 > r) ? 1'b1 : dp[k+1][r][0];
                            
                            if (left_ok && right_ok) begin
                                dp[l][r][1] = 1;
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        // 3. Final Check
        // Check if entire range [0, 7] forms a valid tree.
        // We need to find a root k such that:
        // - Left [0, k-1] is valid right subtree (connected to k)
        // - Right [k+1, 7] is valid left subtree (connected to k)
        possible = 0;
        for (k = 0; k < 8; k = k + 1) begin
            // No parent needed for the whole tree, so we just check internal connections.
            // We can reuse dp logic. The full range [0, 7] is a valid tree if there is a root k
            // such that left part [0, k-1] is a valid RIGHT subtree (relative to k)
            // and right part [k+1, 7] is a valid LEFT subtree (relative to k).
            
            bit left_ok, right_ok;
            left_ok = (k == 0) ? 1'b1 : dp[0][k-1][1];
            right_ok = (k == 7) ? 1'b1 : dp[k+1][7][0];
            
            if (left_ok && right_ok) begin
                possible = 1;
                break;
            end
        end
    end

endmodule
