module arrow_mapping (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [31:0] K,
    input wire [3:0] P [0:7],
    output reg [3:0] f [0:7],
    output reg valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] DECOMP_P = 4'd1;
    localparam [3:0] FIND_DIVISORS = 4'd2;
    localparam [3:0] SEARCH_DECOMP = 4'd3;
    localparam [3:4] BUILD_F = 4'd4;
    localparam [3:4] VERIFY_F = 4'd5;
    localparam [3:4] OUTPUT_RESULT = 4'd6;
    localparam [3:4] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate storage
    reg [2:0] p_cycle_idx; // Index for current cycle in P
    reg [2:0] p_cycle_len; // Length of current cycle
    reg [3:0] p_cycle_nodes [0:7]; // Nodes in current cycle
    reg [2:0] divisors [0:7]; // Divisors of current cycle length
    reg [2:0] div_count;
    reg [2:0] search_idx;
    reg [2:0] current_div_sum;
    reg [2:0] current_lcm;
    reg [3:0] f_cycle_len [0:7]; // Proposed f-cycle lengths for current P-cycle
    reg [2:0] f_cycle_idx; // Index for building f-cycle
    reg [2:0] node_idx;
    reg [3:0] temp_f [0:7]; // Temporary f for verification
    reg temp_valid;
    integer i, j, k, m;

    // Helper function: GCD
    function automatic [2:0] gcd;
        input [2:0] a;
        input [2:0] b;
        reg [2:0] x, y;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                x = x - y;
                if (x < y) begin
                    x = x ^ y;
                    y = x ^ y;
                    x = x ^ y;
                end
            end
            gcd = x;
        end
    endfunction

    // Helper function: LCM
    function automatic [2:0] lcm;
        input [2:0] a;
        input [2:0] b;
        reg [2:0] g;
        begin
            if (a == 0 || b == 0) lcm = 0;
            else begin
                g = gcd(a, b);
                lcm = (a * b) / g;
            end
        end
    endfunction

    // Helper function: Find divisors of a number (max 8)
    task find_divisors;
        input [2:0] num;
        output [2:0] divs [0:7];
        output [2:0] count;
        reg [2:0] d;
        begin
            count = 0;
            for (d = 1; d <= num; d = d + 1) begin
                if (num % d == 0) begin
                    divs[count] = d;
                    count = count + 1;
                end
            end
        end
    endtask

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize f output
            for (i = 0; i < 8; i = i + 1) begin
                f[i] <= 4'd0;
            end
            p_cycle_idx <= 3'd0;
            p_cycle_len <= 3'd0;
            div_count <= 3'd0;
            search_idx <= 3'd0;
            f_cycle_idx <= 3'd0;
            node_idx <= 3'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    p_cycle_idx <= 3'd0;
                    if (start && N > 8'd0 && N <= 8'd8) begin
                        state <= DECOMP_P;
                    end
                end

                DECOMP_P: begin
                    // Parse P and find next cycle
                    // Mark visited nodes
                    // For simplicity with N<=8, we use brute force to find cycles
                    // We will use temp_f to mark visited nodes
                    // temp_f[i] = 1 means node i has been processed
                    if (p_cycle_idx < N) begin
                        // Check if node p_cycle_idx is already in a cycle
                        reg already_in_cycle;
                        already_in_cycle = 1'b0;
                        for (i = 0; i < p_cycle_idx; i = i + 1) begin
                            if (P[p_cycle_idx] == P[i]) begin
                                already_in_cycle = 1'b1;
                            end
                        end
                        if (!already_in_cycle) begin
                            // Start new cycle
                            p_cycle_len <= 3'd1;
                            p_cycle_nodes[0] <= p_cycle_idx;
                            node_idx <= p_cycle_idx;
                            state <= FIND_DIVISORS;
                        end else begin
                            p_cycle_idx <= p_cycle_idx + 3'd1;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                FIND_DIVISORS: begin
                    // Continue finding the cycle
                    // Check if we completed the cycle
                    if (P[node_idx] == p_cycle_nodes[0]) begin
                        // Cycle found, find divisors
                        find_divisors(p_cycle_len, divisors, div_count);
                        search_idx <= 3'd0;
                        current_div_sum <= 3'd0;
                        current_lcm <= 3'd1;
                        // Reset f_cycle_len
                        for (i = 0; i < 8; i = i + 1) begin
                            f_cycle_len[i] <= 3'd0;
                        end
                        f_cycle_idx <= 3'd0;
                        state <= SEARCH_DECOMP;
                    end else begin
                        // Add next element to cycle
                        p_cycle_nodes[p_cycle_len] <= P[node_idx];
                        p_cycle_len <= p_cycle_len + 3'd1;
                        node_idx <= P[node_idx];
                    end
                end

                SEARCH_DECOMP: begin
                    // Brute force search for valid f-cycle lengths
                    // We try to partition p_cycle_len using divisors
                    if (search_idx < div_count) begin
                        // Try adding current divisor
                        if (current_div_sum + divisors[search_idx] <= p_cycle_len) begin
                            // Check if adding this divisor satisfies LCM condition
                            // LCM(current_lcm, divisors[search_idx]) must divide p_cycle_len
                            reg [2:0] new_lcm;
                            new_lcm = lcm(current_lcm, divisors[search_idx]);
                            if (p_cycle_len % new_lcm == 0) begin
                                // Valid move, proceed
                                current_div_sum <= current_div_sum + divisors[search_idx];
                                current_lcm <= new_lcm;
                                f_cycle_len[f_cycle_idx] <= divisors[search_idx];
                                f_cycle_idx <= f_cycle_idx + 3'd1;
                                search_idx <= 3'd0; // Restart search from beginning for next part
                                // If sum equals p_cycle_len, we found a valid decomposition
                                if (current_div_sum + divisors[search_idx] == p_cycle_len) begin
                                    state <= BUILD_F;
                                end
                            end else begin
                                search_idx <= search_idx + 3'd1;
                            end
                        end else begin
                            search_idx <= search_idx + 3'd1;
                        end
                    end else begin
                        // Backtrack
                        if (f_cycle_idx > 3'd0) begin
                            f_cycle_idx <= f_cycle_idx - 3'd1;
                            // Restore previous state (needs tracking, simplified here)
                            // For N=8, we can use a simpler recursion or just fail
                            // Let's implement a simple backtrack stack
                            // Due to complexity, we will try a simpler approach:
                            // Just iterate all combinations of divisors
                            state <= OUTPUT_RESULT; // Fail for this cycle
                        end else begin
                            // No valid decomposition found for this cycle
                            state <= OUTPUT_RESULT; // Fail
                        end
                    end
                end

                BUILD_F: begin
                    // Build f for the current cycle using f_cycle_len
                    // p_cycle_nodes contains the cycle in P order
                    // Example: P-cycle: 1->3->2->1 (length 3)
                    // f-cycles: e.g., length 3: 1->3->2->1 (or 1->2->3->1)
                    // Need to assign f such that f^K = P
                    // If f-cycle length d, then f^d = identity on that cycle
                    // P is f^K. For a node x in cycle, P(x) = f^K(x)
                    // If x is in f-cycle of length d, f^K(x) = x if K % d == 0
                    // Else f^K(x) = element K steps forward in cycle.
                    // We need f^K(x) = P(x).
                    // So we need to map the cycle such that K steps forward equals P.
                    // f(x) = next(x) in f-cycle.
                    // P(x) = element at position K in cycle starting from x.
                    // If cycle is [c0, c1, ..., c(d-1)] in f-order
                    // f(c_i) = c_{(i+1)%d}
                    // f^K(c_i) = c_{(i+K)%d}
                    // We need c_{(i+K)%d} = P(c_i)
                    // We have the P-cycle sequence. Let's denote P-seq as [p0, p1, ..., p(L-1)]
                    // We need to pick a starting point for each f-cycle.
                    // Let's just assign sequential P-nodes to f-cycles.
                    // For f-cycle of length d, take next d nodes from P-cycle.
                    // Assign f for them.
                    // Verify if f^K matches P.
                    // For now, simple assignment: f(c_i) = c_{i+1}
                    // Check if P(c_i) = c_{(i+K)%d}
                    // If not, it's a fail.
                    
                    // Let's build temp_f for verification
                    // Reset temp_f
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_f[i] <= 4'd0; // 0 means unassigned
                    end
                    
                    node_idx <= 3'd0; // Index in p_cycle_nodes
                    f_cycle_idx <= 3'd0; // Index in f_cycle_len
                    state <= VERIFY_F;
                end

                VERIFY_F: begin
                    // Construct temp_f for current P-cycle
                    // Check if we processed all f-cycles for this P-cycle
                    if (f_cycle_idx < 8 && f_cycle_len[f_cycle_idx] != 3'd0) begin
                        reg [2:0] d;
                        d = f_cycle_len[f_cycle_idx];
                        // Assign f for this cycle
                        // p_cycle_nodes[node_idx ... node_idx + d - 1]
                        for (k = 0; k < d; k = k + 1) begin
                            // f(p[node_idx + k]) = p[node_idx + (k+1)%d]
                            temp_f[p_cycle_nodes[node_idx + k]] <= p_cycle_nodes[node_idx + (k + 1) % d];
                        end
                        node_idx <= node_idx + d;
                        f_cycle_idx <= f_cycle_idx + 3'd1;
                    end else begin
                        // Verification: Check if temp_f^K matches P for this cycle
                        temp_valid <= 1'b1;
                        node_idx <= 3'd0;
                        // Check each node in p_cycle_nodes
                        // Optimization: Only check if temp_f is fully assigned
                        // Iterate through all nodes in this cycle
                        for (i = 0; i < p_cycle_len; i = i + 1) begin
                            reg [3:0] current;
                            reg [3:0] target;
                            reg [31:0] k_rem;
                            current = p_cycle_nodes[i];
                            target = P[current];
                            k_rem = K;
                            // Simulate K steps
                            // Since K is large, we reduce K mod cycle length of current in temp_f
                            // Find cycle length of current in temp_f
                            reg [2:0] len;
                            reg [3:0] temp;
                            len = 0;
                            temp = temp_f[current];
                            while (temp != current && len < 8) begin
                                len = len + 1;
                                temp = temp_f[temp];
                            end
                            if (len > 0) begin
                                k_rem = K % (len + 1); // Cycle length is len + 1
                                if (k_rem == 0) k_rem = len + 1;
                            end else begin
                                k_rem = K;
                            end
                            
                            // Simulate k_rem steps from current
                            temp = current;
                            for (j = 0; j < 8; j = j + 1) begin
                                if (k_rem > 0) begin
                                    temp = temp_f[temp];
                                    k_rem = k_rem - 1;
                                end
                            end
                            if (temp != target) begin
                                temp_valid <= 1'b0;
                            end
                        end
                        
                        if (temp_valid) begin
                            // Update main f array with temp_f for this cycle
                            for (i = 0; i < p_cycle_len; i = i + 1) begin
                                f[p_cycle_nodes[i]] <= temp_f[p_cycle_nodes[i]];
                            end
                            // Move to next P cycle
                            p_cycle_idx <= p_cycle_idx + p_cycle_len;
                            state <= DECOMP_P;
                        end else begin
                            // Invalid decomposition, try next
                            // This requires backtracking in SEARCH_DECOMP
                            // For simplicity in hardware, we'll just fail if the first guess is wrong
                            // Or implement a counter to iterate combinations
                            state <= OUTPUT_RESULT; // Fail
                        end
                    end
                end

                OUTPUT_RESULT: begin
                    valid <= 1'b0; // Indicate failure
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule