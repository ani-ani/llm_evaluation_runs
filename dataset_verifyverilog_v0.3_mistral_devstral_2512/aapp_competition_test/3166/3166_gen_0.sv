module ping_pong (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] k,
    input wire [63:0] adj,
    input wire [7:0] s_mask,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_S = 3'd1;
    localparam [2:0] ENUMERATE = 3'd2;
    localparam [2:0] CHECK_SUBSET = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [7:0] s_set;           // Players in S
    reg [7:0] t_set;           // Players in T (complement of S)
    reg [7:0] current_subset;  // Current subset R being checked
    reg [2:0] t_size;          // Current t value (size of subset)
    reg [2:0] t_counter;       // Counter for t
    reg [7:0] subset_counter;  // Counter for subsets
    reg [7:0] v_prime;         // V' = S ∪ (T \ R)
    reg [7:0] reach [0:7];     // Reachability matrix rows
    reg [7:0] temp_reach [0:7];
    reg [2:0] i_reg, j_reg, k_reg;  // Loop counters for Floyd-Warshall
    reg acyclic_s;             // Flag for S acyclicity
    reg acyclic_v_prime;       // Flag for V' acyclicity
    reg found;                 // Flag for found solution

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            s_set <= 8'd0;
            t_set <= 8'd0;
            current_subset <= 8'd0;
            t_size <= 3'd0;
            t_counter <= 3'd0;
            subset_counter <= 8'd0;
            v_prime <= 8'd0;
            for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                reach[i_reg] <= 8'd0;
                temp_reach[i_reg] <= 8'd0;
            end
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            k_reg <= 3'd0;
            acyclic_s <= 1'b0;
            acyclic_v_prime <= 1'b0;
            found <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_S;
                        // Initialize sets
                        s_set <= s_mask;
                        t_set <= ~s_mask & {8{1'b1}};
                        t_counter <= 3'd0;
                        found <= 1'b0;
                    end
                end

                CHECK_S: begin
                    // Check if subgraph induced by S is acyclic
                    // Initialize reachability matrix for S
                    for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                        if (s_set[i_reg]) begin
                            reach[i_reg] <= 8'd0;
                            for (j_reg = 0; j_reg < 8; j_reg = j_reg + 1) begin
                                if (s_set[j_reg]) begin
                                    reach[i_reg][j_reg] <= adj[i_reg * 8 + j_reg];
                                end
                            end
                        end
                    end

                    // Floyd-Warshall for S
                    for (k_reg = 0; k_reg < 8; k_reg = k_reg + 1) begin
                        if (s_set[k_reg]) begin
                            for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                                if (s_set[i_reg]) begin
                                    for (j_reg = 0; j_reg < 8; j_reg = j_reg + 1) begin
                                        if (s_set[j_reg]) begin
                                            reach[i_reg][j_reg] <= reach[i_reg][j_reg] | (reach[i_reg][k_reg] & reach[k_reg][j_reg]);
                                        end
                                    end
                                end
                            end
                        end
                    end

                    // Check for cycles in S
                    acyclic_s <= 1'b1;
                    for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                        if (s_set[i_reg] && reach[i_reg][i_reg]) begin
                            acyclic_s <= 1'b0;
                        end
                    end

                    if (!acyclic_s) begin
                        result <= 8'd255;
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= ENUMERATE;
                    end
                end

                ENUMERATE: begin
                    // Enumerate subsets of T of size t_counter
                    if (t_counter >= k) begin
                        result <= 8'd255;
                        next_state <= DONE_STATE;
                    end else begin
                        subset_counter <= 8'd0;
                        current_subset <= 8'd0;
                        t_size <= 3'd0;
                        next_state <= CHECK_SUBSET;
                    end
                end

                CHECK_SUBSET: begin
                    // Check if current_subset has size t_counter
                    t_size <= 3'd0;
                    for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                        if (current_subset[i_reg]) begin
                            t_size <= t_size + 1'b1;
                        end
                    end

                    if (t_size == t_counter) begin
                        // Compute V' = S ∪ (T \ R)
                        v_prime <= s_set | (t_set & ~current_subset);

                        // Check if subgraph induced by V' is acyclic
                        // Initialize reachability matrix for V'
                        for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                            if (v_prime[i_reg]) begin
                                temp_reach[i_reg] <= 8'd0;
                                for (j_reg = 0; j_reg < 8; j_reg = j_reg + 1) begin
                                    if (v_prime[j_reg]) begin
                                        temp_reach[i_reg][j_reg] <= adj[i_reg * 8 + j_reg];
                                    end
                                end
                            end
                        end

                        // Floyd-Warshall for V'
                        for (k_reg = 0; k_reg < 8; k_reg = k_reg + 1) begin
                            if (v_prime[k_reg]) begin
                                for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                                    if (v_prime[i_reg]) begin
                                        for (j_reg = 0; j_reg < 8; j_reg = j_reg + 1) begin
                                            if (v_prime[j_reg]) begin
                                                temp_reach[i_reg][j_reg] <= temp_reach[i_reg][j_reg] | (temp_reach[i_reg][k_reg] & temp_reach[k_reg][j_reg]);
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        // Check for cycles in V'
                        acyclic_v_prime <= 1'b1;
                        for (i_reg = 0; i_reg < 8; i_reg = i_reg + 1) begin
                            if (v_prime[i_reg] && temp_reach[i_reg][i_reg]) begin
                                acyclic_v_prime <= 1'b0;
                            end
                        end

                        if (acyclic_v_prime) begin
                            result <= t_counter;
                            found <= 1'b1;
                            next_state <= DONE_STATE;
                        end
                    end

                    // Increment subset counter
                    subset_counter <= subset_counter + 8'd1;
                    current_subset <= subset_counter;

                    // Check if all subsets have been checked
                    if (subset_counter == 8'd255) begin
                        t_counter <= t_counter + 3'd1;
                        next_state <= ENUMERATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule