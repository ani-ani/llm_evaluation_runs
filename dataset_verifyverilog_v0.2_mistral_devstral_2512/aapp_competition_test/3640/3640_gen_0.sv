module meow_factor (
    input clk,
    input rst_n,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output [7:0] meow_factor,
    output valid
);

    // Constants
    localparam MAX_LEN = 8;
    localparam TARGET_LEN = 4;
    localparam MAX_COST = 15;

    // Target string 'meow' in ASCII
    localparam [7:0] TARGET [0:TARGET_LEN-1] = '{8'h6d, 8'h65, 8'h6f, 8'h77};

    // Input string array
    wire [7:0] input_str [0:MAX_LEN-1] = '{char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7};

    // DP matrix: dp[i][j] = min operations to match first j chars of target using first i chars of input
    logic [3:0] dp [0:MAX_LEN][0:TARGET_LEN];

    // Initialize DP matrix
    always_comb begin
        // Base case: dp[0][0] = 0 (empty string to empty string)
        dp[0][0] = 4'd0;

        // First column: cost to match empty target (delete all input chars)
        for (int i = 1; i < MAX_LEN; i++) begin
            dp[i][0] = dp[i-1][0] + 1;
        end

        // First row: cost to match target with empty input (insert all target chars)
        for (int j = 1; j < TARGET_LEN; j++) begin
            dp[0][j] = dp[0][j-1] + 1;
        end

        // Fill DP matrix
        for (int i = 1; i < MAX_LEN; i++) begin
            for (int j = 1; j < TARGET_LEN; j++) begin
                logic [3:0] match_cost, replace_cost, insert_cost, delete_cost, swap_cost;

                // Match or replace
                if (input_str[i] == TARGET[j]) begin
                    match_cost = dp[i-1][j-1];
                end else begin
                    match_cost = dp[i-1][j-1] + 1; // Replace cost
                end

                // Insert and delete
                insert_cost = dp[i][j-1] + 1;
                delete_cost = dp[i-1][j] + 1;

                // Swap (only if we have previous characters)
                if (i > 1 && j > 1) begin
                    if (input_str[i] == TARGET[j-1] && input_str[i-1] == TARGET[j]) begin
                        swap_cost = dp[i-2][j-2] + 1;
                    end else begin
                        swap_cost = 4'd15; // Invalid swap
                    end
                end else begin
                    swap_cost = 4'd15; // No swap possible
                end

                // Take minimum of all operations
                dp[i][j] = match_cost;
                if (insert_cost < dp[i][j]) dp[i][j] = insert_cost;
                if (delete_cost < dp[i][j]) dp[i][j] = delete_cost;
                if (swap_cost < dp[i][j]) dp[i][j] = swap_cost;
            end
        end
    end

    // Find minimum cost across all possible alignments
    logic [3:0] min_cost = 4'd15;
    always_comb begin
        // Check all possible starting positions where 'meow' could fit
        for (int i = 0; i <= MAX_LEN - TARGET_LEN; i++) begin
            if (dp[i+TARGET_LEN-1][TARGET_LEN-1] < min_cost) begin
                min_cost = dp[i+TARGET_LEN-1][TARGET_LEN-1];
            end
        end

        // Also check partial matches at end of string
        for (int i = MAX_LEN - TARGET_LEN + 1; i < MAX_LEN; i++) begin
            if (dp[i][TARGET_LEN-1] < min_cost) begin
                min_cost = dp[i][TARGET_LEN-1];
            end
        end

        // Saturate at MAX_COST
        if (min_cost > MAX_COST) begin
            min_cost = MAX_COST;
        end
    end

    // Output
    assign meow_factor = min_cost;
    assign valid = 1'b1;

endmodule