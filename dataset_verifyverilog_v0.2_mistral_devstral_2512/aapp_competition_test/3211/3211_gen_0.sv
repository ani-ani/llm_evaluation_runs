module voting_optimizer (
    input [7:0][2:0] citizens,
    input [2:0] n,
    output reg [3:0] min_swaps,
    output reg win_possible
);

    reg [3:0] current_min_swaps;
    reg current_win_possible;
    integer i, j, k, swap_cost, p1_score, p2_score, teller_pos, voter_pos;
    reg [2:0] temp_citizens [0:7];
    reg [2:0] original_tellers [0:7];
    reg [2:0] new_tellers [0:7];
    integer num_tellers, teller_indices [0:7], new_teller_indices [0:7];

    always @* begin
        current_min_swaps = 15;
        current_win_possible = 0;

        // Extract original teller positions
        num_tellers = 0;
        for (i = 0; i < n; i = i + 1) begin
            if (citizens[i] == 3'b100) begin
                original_tellers[num_tellers] = i;
                teller_indices[num_tellers] = i;
                num_tellers = num_tellers + 1;
            end
        end

        // Generate all possible permutations of teller positions
        for (i = 0; i < (1 << num_tellers); i = i + 1) begin
            // Initialize new teller positions
            for (j = 0; j < num_tellers; j = j + 1) begin
                new_teller_indices[j] = teller_indices[j];
            end

            // Calculate swap cost for this permutation
            swap_cost = 0;
            for (j = 0; j < num_tellers; j = j + 1) begin
                if (i[j] == 1) begin
                    // Move teller right if possible
                    if (new_teller_indices[j] < n - 1 && citizens[new_teller_indices[j] + 1] != 3'b100) begin
                        new_teller_indices[j] = new_teller_indices[j] + 1;
                        swap_cost = swap_cost + 1;
                    end
                end else begin
                    // Move teller left if possible
                    if (new_teller_indices[j] > 0 && citizens[new_teller_indices[j] - 1] != 3'b100) begin
                        new_teller_indices[j] = new_teller_indices[j] - 1;
                        swap_cost = swap_cost + 1;
                    end
                end
            end

            // Check if swap cost exceeds limit
            if (swap_cost > 15) begin
                continue;
            end

            // Simulate voting process with new teller positions
            p1_score = 0;
            p2_score = 0;
            for (j = 0; j < n; j = j + 1) begin
                if (citizens[j] == 3'b001) begin
                    p1_score = p1_score + 1;
                end else if (citizens[j] == 3'b010) begin
                    p2_score = p2_score + 1;
                end else if (citizens[j] == 3'b100) begin
                    // Teller awards point to party with more votes at this moment
                    if (p1_score > p2_score) begin
                        p1_score = p1_score + 1;
                    end else if (p2_score > p1_score) begin
                        p2_score = p2_score + 1;
                    end
                end
            end

            // Check if Party 1 wins
            if (p1_score > p2_score) begin
                if (swap_cost < current_min_swaps) begin
                    current_min_swaps = swap_cost;
                    current_win_possible = 1;
                end
            end
        end

        // Output results
        min_swaps = current_min_swaps;
        win_possible = current_win_possible;
    end

endmodule