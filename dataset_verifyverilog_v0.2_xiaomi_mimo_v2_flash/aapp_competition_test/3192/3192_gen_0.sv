module shortest_cycle_finder (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [255:0] adj_matrix_flat,
    output reg [3:0] cycle_len,
    output reg [3:0] cycle_nodes [0:15],
    output reg done
);

    // Internal parameter for max nodes
    localparam MAX_NODES = 16;
    localparam IDX_WIDTH = 4;
    localparam DIST_WIDTH = 5;
    localparam INF = 5'd31; // Max path length is 15, so 31 is sufficient for infinity

    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT_UNPACK = 4'd1;
    localparam FLOYD_LOOP_I = 4'd2;
    localparam FLOYD_LOOP_J = 4'd3;
    localparam FLOYD_LOOP_K = 4'd4;
    localparam FLOYD_UPDATE = 4'd5;
    localparam CHECK_CYCLES = 4'd6;
    localparam BACKTRACK_START = 4'd7;
    localparam BACKTRACK_LOOP = 4'd8;
    localparam DONE_STATE = 4'd9;

    reg [3:0] state, next_state;

    // Internal registers for matrices
    // dist matrix: 16x16, 5 bits each
    reg [DIST_WIDTH-1:0] dist [0:MAX_NODES-1][0:MAX_NODES-1];
    // parent matrix: 16x16, 4 bits each
    reg [IDX_WIDTH-1:0] parent [0:MAX_NODES-1][0:MAX_NODES-1];

    // Loop counters and temporary variables
    reg [3:0] i, j, k; // Indices for loops
    reg [3:0] start_node; // Node with shortest cycle
    reg [3:0] curr_node, prev_node;
    reg [3:0] path_len; // Length of path found during backtrack
    reg [3:0] path_idx; // Index for filling cycle_nodes array
    
    // Helper variables for update logic
    reg [DIST_WIDTH-1:0] sum_dist;
    reg [DIST_WIDTH-1:0] min_dist;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: if (start) next_state = INIT_UNPACK; else next_state = IDLE;
            
            INIT_UNPACK: begin
                // We unpack row by row in one cycle per row to avoid large combinational paths
                if (i < num_nodes) next_state = INIT_UNPACK;
                else next_state = FLOYD_LOOP_I;
            end

            FLOYD_LOOP_I: begin
                if (i < num_nodes) next_state = FLOYD_LOOP_J;
                else next_state = CHECK_CYCLES;
            end

            FLOYD_LOOP_J: begin
                if (j < num_nodes) next_state = FLOYD_LOOP_K;
                else next_state = FLOYD_LOOP_I; // Back to increment i
            end

            FLOYD_LOOP_K: begin
                if (k < num_nodes) next_state = FLOYD_UPDATE;
                else next_state = FLOYD_LOOP_J; // Back to increment j
            end

            FLOYD_UPDATE: begin
                // Always transition back to K loop, logic inside will handle update
                next_state = FLOYD_LOOP_K;
            end

            CHECK_CYCLES: begin
                if (i < num_nodes) next_state = CHECK_CYCLES;
                else begin
                    if (cycle_len != 4'd0) next_state = BACKTRACK_START;
                    else next_state = DONE_STATE;
                end
            end

            BACKTRACK_START: begin
                next_state = BACKTRACK_LOOP;
            end

            BACKTRACK_LOOP: begin
                // Logic to reconstruct path
                if (curr_node != start_node) next_state = BACKTRACK_LOOP;
                else next_state = DONE_STATE; // Path reconstructed
            end

            DONE_STATE: begin
                if (start) next_state = DONE_STATE; // Stay done until reset or new start
                else next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_len <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_len <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                end

                INIT_UNPACK: begin
                    // Unpack flattened adjacency matrix into dist matrix
                    // adj_matrix_flat is row-major: row i is bits [16*i +: 16]
                    if (i < num_nodes) begin
                        for (integer bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1) begin
                            if (bit_idx < num_nodes) begin
                                // Initialize dist with 1 if edge exists, else INF
                                // Self loops are 0 initially, unless explicitly set in adj matrix
                                if (adj_matrix_flat[16*i + bit_idx]) begin
                                    dist[i][bit_idx] <= 5'd1;
                                    parent[i][bit_idx] <= i;
                                end else begin
                                    dist[i][bit_idx] <= INF;
                                    parent[i][bit_idx] <= i; // Undefined initially, but safe
                                end
                            end else begin
                                dist[i][bit_idx] <= INF;
                            end
                        end
                        // Diagonal: dist[i][i] = 0 (no self cycle initially)
                        dist[i][i] <= 5'd0;
                        i <= i + 1;
                    end
                end

                FLOYD_LOOP_I: begin
                    if (i >= num_nodes) begin
                        i <= 4'd0; // Reset for CHECK_CYCLES
                    end else begin
                        j <= 4'd0; // Reset j for inner loop
                    end
                end

                FLOYD_LOOP_J: begin
                    if (j >= num_nodes) begin
                        i <= i + 1; // Increment i
                    end else begin
                        k <= 4'd0; // Reset k for innermost loop
                    end
                end

                FLOYD_LOOP_K: begin
                    if (k >= num_nodes) begin
                        j <= j + 1; // Increment j
                    end
                end

                FLOYD_UPDATE: begin
                    if (k < num_nodes && i < num_nodes && j < num_nodes) begin
                        // Standard Floyd-Warshall update: if dist[i][k] + dist[k][j] < dist[i][j]
                        if (dist[i][k] != INF && dist[k][j] != INF) begin
                            sum_dist <= dist[i][k] + dist[k][j];
                            if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                dist[i][j] <= dist[i][k] + dist[k][j];
                                parent[i][j] <= parent[k][j];
                            end
                        end
                        k <= k + 1;
                    end
                end

                CHECK_CYCLES: begin
                    if (i < num_nodes) begin
                        // Check diagonal element for cycle back to itself
                        if (dist[i][i] != 0 && dist[i][i] != INF) begin
                            // Found a cycle
                            if (cycle_len == 4'd0 || dist[i][i] < cycle_len) begin
                                cycle_len <= dist[i][i];
                                start_node <= i;
                            end
                        end
                        i <= i + 1;
                    end
                end

                BACKTRACK_START: begin
                    // Initialize backtracking variables
                    // We need to find the path: P = (start_node, ..., start_node)
                    // Logic: Go back from start_node using parent pointers until we loop back
                    path_len <= 4'd0;
                    curr_node <= start_node; // We start at the destination
                    // We need the node before start_node in the cycle
                    // The parent of start_node via the cycle path
                    // To reconstruct: 
                    // 1. Push curr to stack (we will do this in loop)
                    // 2. Find prev = parent[start_node][curr_node]
                    // 3. Update curr_node = prev
                    // 4. Repeat until curr_node == start_node
                    // Actually, we need to build the list: Node_i, Node_{i-1}... Node_0
                    // Then reverse.
                    // Let's use the cycle_nodes array directly.
                    // We store the path in reverse order: we push nodes as we backtrack from start_node.
                    // Wait, standard backtracking:
                    // Let u = start_node. We want the cycle u -> ... -> u.
                    // The node immediately preceding u in the cycle is p = parent[u][u].
                    // The node before p is parent[u][p].
                    // ... until we reach u.
                    
                    // Reset the output array
                    for (integer idx = 0; idx < 16; idx = idx + 1) begin
                        cycle_nodes[idx] <= 4'd0;
                    end
                    
                    // Initialize backtrack
                    curr_node <= parent[start_node][start_node]; // The node before start_node
                    cycle_nodes[0] <= start_node;
                    path_len <= 1;
                end

                BACKTRACK_LOOP: begin
                    if (curr_node != start_node && path_len < 16) begin
                        // Append current node to the path
                        if (path_len < 16) begin
                            // We need to fill cycle_nodes in the order of the cycle
                            // But we are going backwards. 
                            // Cycle: u -> ... -> v -> u
                            // Backtrack: u (fixed), then v, then ...
                            // So we append v to the list.
                            // The order in cycle_nodes should be u, ..., v
                            // But we are finding v, then ..., u (which is start_node, stop).
                            // This is tricky without a stack.
                            // We are finding: u (fixed), v, w...
                            // Wait, parent[u][u] = v (v connects to u).
                            // parent[u][v] = w (w connects to v).
                            // ...
                            // So we want cycle_nodes = {u, w, ..., v}? No.
                            // Order: u -> w -> ... -> v -> u.
                            // Backtrack gives us: v (from parent[u][u]), w (from parent[u][v]), ...
                            // So we are finding the nodes in reverse order.
                            // We can fill the array from the end, or reverse later.
                            // Reversing later requires saving all nodes in temporary array.
                            // Or we can shift the array.
                            // Let's just fill `cycle_nodes` such that `cycle_nodes[0]` is `start_node`.
                            // We need to store the rest.
                            // Let's use a temp buffer or fill sequentially if we can calculate length first.
                            // But we don't know length exactly.
                            // We are already calculating length in Floyd.
                            // So we can fill `cycle_nodes` from index 1 to cycle_len-1.
                            // But we are backtracking from v. The order is v, w, ...
                            // The cycle is u, ..., w, v, u.
                            // So the path is u, ..., w, v.
                            // We found v. Next w. 
                            // We need to fill cycle_nodes[cycle_len-1] = v, cycle_nodes[cycle_len-2] = w?
                            // Wait, if cycle_len = L, indices 0..L-1. Indices 0 and L-1 connect to 0.
                            // We know index 0 is u.
                            // We need indices 1..L-1.
                            // Backtracking gives nodes in order: v, w, ...
                            // The path is u -> ... -> w -> v -> u.
                            // So v is the node before u. w is the node before v.
                            // Indices: ... index(L-2)=w, index(L-1)=v.
                            // So we need to fill from the end of the array towards the start.
                            // Let's maintain a counter `count`.
                            // `count` starts at 1 (for u).
                            // We found v. We want to store v at `cycle_len - 1`.
                            // We found w. We want to store w at `cycle_len - 2`.
                            // So `cycle_nodes[cycle_len - count] = curr_node`.
                            // Then `count` increases.
                            
                            cycle_nodes[cycle_len - path_len] <= curr_node;
                            path_len <= path_len + 1;
                            curr_node <= parent[start_node][curr_node];
                        end
                    end else begin
                        // Finished backtracking
                        // Do nothing, transition to DONE
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Remove output registers from sensitivity list to avoid inferring latch in some tools
    // This is just a dummy block to ensure cycle_nodes is treated correctly as an array
    // Verilog arrays of registers usually need to be accessed element by element, which we did.

endmodule
