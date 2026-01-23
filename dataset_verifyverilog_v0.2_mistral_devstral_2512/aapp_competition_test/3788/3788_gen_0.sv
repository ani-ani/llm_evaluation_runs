module bst_solver_8 (
    input [7:0][15:0] nums,
    output reg possible
);

    // GCD lookup table for numbers 2-1000
    function automatic integer gcd(input integer a, input integer b);
        if (b == 0) begin
            return a;
        end else begin
            return gcd(b, a % b);
        end
    endfunction

    // Precompute valid_edge matrix
    reg [7:0][7:0] valid_edge;
    integer i, j;
    always @* begin
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (i == j) begin
                    valid_edge[i][j] = 1'b0;
                end else begin
                    valid_edge[i][j] = (gcd(nums[i], nums[j]) > 1) ? 1'b1 : 1'b0;
                end
            end
        end
    end

    // DP table: dp[l][r][root_side]
    reg [7:0][7:0][1:0] dp;
    integer l, r, k;
    always @* begin
        // Initialize DP table
        for (l = 0; l < 8; l = l + 1) begin
            for (r = 0; r < 8; r = r + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    dp[l][r][k] = 1'b0;
                end
            end
        end

        // Base case: single node
        for (i = 0; i < 8; i = i + 1) begin
            dp[i][i][0] = 1'b1;
            dp[i][i][1] = 1'b1;
        end

        // Fill DP table for ranges of length > 1
        for (integer len = 2; len <= 8; len = len + 1) begin
            for (l = 0; l <= 8 - len; l = l + 1) begin
                r = l + len - 1;
                for (k = l; k <= r; k = k + 1) begin
                    // Check left subtree
                    reg left_valid = 1'b1;
                    if (k > l) begin
                        left_valid = dp[l][k-1][1] && valid_edge[k][k-1];
                    end

                    // Check right subtree
                    reg right_valid = 1'b1;
                    if (k < r) begin
                        right_valid = dp[k+1][r][0] && valid_edge[k][k+1];
                    end

                    // Update DP table
                    if (left_valid && right_valid) begin
                        dp[l][r][0] = 1'b1;
                        dp[l][r][1] = 1'b1;
                    end
                end
            end
        end

        // Check if entire range [0,7] can form a valid tree
        possible = 1'b0;
        for (k = 0; k < 8; k = k + 1) begin
            reg left_subtree = 1'b1;
            reg right_subtree = 1'b1;
            if (k > 0) begin
                left_subtree = dp[0][k-1][1];
            end
            if (k < 7) begin
                right_subtree = dp[k+1][7][0];
            end
            if (left_subtree && right_subtree) begin
                possible = 1'b1;
            end
        end
    end

endmodule