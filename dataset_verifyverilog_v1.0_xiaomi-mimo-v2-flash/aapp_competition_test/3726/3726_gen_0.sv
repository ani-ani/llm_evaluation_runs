module FlipCards (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] group_parity,
    input wire [255:0] adj_matrix,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] MATCHING = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Registers
    reg [2:0] state;
    reg [3:0] even_count;
    reg [3:0] odd_count;
    reg [3:0] f_match;
    reg [3:0] match_size;
    reg [3:0] remaining_even;
    reg [3:0] remaining_odd;
    
    // Matching algorithm registers
    reg [3:0] u; // current even node
    reg [3:0] v; // current odd node
    reg [3:0] visited_mask;
    reg [3:0] pair_u [0:15]; // match for even node
    reg [3:0] pair_v [0:15]; // match for odd node
    reg [3:0] queue [0:15];
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [3:0] pred [0:15];
    reg [3:0] match_idx;
    reg found_path;
    reg [7:0] cycles;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper signals
    wire [3:0] e_count;
    wire [3:0] o_count;
    wire is_even;
    wire is_prime_edge;
    wire [3:0] neighbor;
    
    assign e_count = even_count;
    assign o_count = odd_count;
    assign is_even = (u < even_count); // Simplified parity check
    
    // Prime edge check: adj_matrix is indexed by [even_node * 16 + odd_node]
    assign is_prime_edge = adj_matrix[u * 16 + v];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            even_count <= 4'd0;
            odd_count <= 4'd0;
            f_match <= 4'd0;
            match_size <= 4'd0;
            u <= 4'd0;
            v <= 4'd0;
            visited_mask <= 4'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            match_idx <= 4'd0;
            found_path <= 1'b0;
            cycles <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                pair_u[i] <= 4'd15; // 15 means no match
                pair_v[i] <= 4'd15;
                queue[i] <= 4'd0;
                pred[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycles <= 8'd0;
                    if (start) begin
                        state <= COUNT;
                        even_count <= 4'd0;
                        odd_count <= 4'd0;
                        u <= 4'd0;
                    end
                end

                COUNT: begin
                    // Count even (1) and odd (0) groups
                    if (group_parity[u]) begin
                        even_count <= even_count + 4'd1;
                    end else begin
                        odd_count <= odd_count + 4'd1;
                    end
                    
                    if (u == 4'd15) begin
                        state <= MATCHING;
                        u <= 4'd0;
                        v <= 4'd0;
                        match_size <= 4'd0;
                        // Reset matching arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            pair_u[i] <= 4'd15;
                            pair_v[i] <= 4'd15;
                        end
                    end else begin
                        u <= u + 4'd1;
                    end
                end

                MATCHING: begin
                    // Simplified bipartite matching (DFS-like approach for small graphs)
                    // We iterate through all even nodes and try to find augmenting paths
                    
                    cycles <= cycles + 8'd1;
                    
                    // Check if we processed all even nodes or reached cycle limit
                    if (u >= even_count || cycles >= MAX_CYCLES) begin
                        state <= COMPUTE;
                        f_match <= match_size;
                        u <= 4'd0;
                    end else begin
                        // Attempt to find augmenting path from node u
                        // Use a simple search: check all odd nodes
                        
                        if (v < odd_count) begin
                            // Check if edge exists and if v is not already matched
                            if (adj_matrix[u * 16 + v]) begin
                                if (pair_v[v] == 4'd15) begin
                                    // Found augmenting path (direct match)
                                    pair_u[u] <= v;
                                    pair_v[v] <= u;
                                    match_size <= match_size + 4'd1;
                                    u <= u + 4'd1; // Move to next even node
                                    v <= 4'd0;
                                end else if (pair_v[v] != 4'd15) begin
                                    // Try to reassign (steal match)
                                    // This is a simplified version; full Hopcroft-Karp would be more complex
                                    // For this problem size, we use a greedy approach with simple backtracking
                                    // Check if current match for v can be moved
                                    reg [3:0] current_match = pair_v[v];
                                    reg can_steal = 1'b0;
                                    // Look for alternative for current_match
                                    if (current_match < even_count) begin
                                        for (int k = 0; k < odd_count; k = k + 1) begin
                                            if (k != v && adj_matrix[current_match * 16 + k] && pair_v[k] == 4'd15) begin
                                                can_steal = 1'b1;
                                            end
                                        end
                                    end
                                    
                                    if (can_steal) begin
                                        // Perform steal
                                        // Find the alternative for current_match
                                        for (int k = 0; k < odd_count; k = k + 1) begin
                                            if (k != v && adj_matrix[current_match * 16 + k] && pair_v[k] == 4'd15) begin
                                                pair_v[k] <= current_match;
                                                pair_u[current_match] <= k;
                                            end
                                        end
                                        pair_u[u] <= v;
                                        pair_v[v] <= u;
                                        match_size <= match_size + 4'd1;
                                        u <= u + 4'd1;
                                        v <= 4'd0;
                                    end else begin
                                        v <= v + 4'd1;
                                    end
                                end
                            end else begin
                                v <= v + 4'd1;
                            end
                        end else begin
                            // No more odd nodes to check for this u
                            u <= u + 4'd1;
                            v <= 4'd0;
                        end
                    end
                end

                COMPUTE: begin
                    remaining_even <= even_count - f_match;
                    remaining_odd <= odd_count - f_match;
                    
                    // Calculate answer
                    // answer = f + 2*((remaining_even >> 1) + (remaining_odd >> 1)) + 3*(remaining_even & 1)
                    result <= f_match + 
                              2 * ((remaining_even >> 1) + (remaining_odd >> 1)) +
                              3 * (remaining_even[0]); // remaining_even & 1
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule