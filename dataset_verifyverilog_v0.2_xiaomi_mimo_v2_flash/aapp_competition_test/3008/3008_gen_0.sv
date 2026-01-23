module max_ranks (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] k,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam BUILD_GRAPH = 3'b001;
    localparam MATCH_START_U = 3'b010;
    localparam MATCH_DFS = 3'b011;
    localparam MATCH_BACKTRACK = 3'b100;
    localparam FINALIZE = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    
    // Graph storage: Adjacency matrix row as bitmask
    reg [7:0] adj [0:7];
    
    // Matching storage
    reg [2:0] match_R [0:7]; // match_R[v] = u (matched left node), 3'b111 if free
    reg [2:0] match_L [0:7]; // match_L[u] = v (matched right node), 3'b111 if free
    
    // DFS/Stack variables
    reg [2:0] u_idx;           // Current left node in outer loop
    reg [2:0] dfs_u;           // Current left node in DFS
    reg [2:0] dfs_v;           // Current right node iterator
    reg [7:0] visited_right;   // Visited flags for right nodes
    
    // Stack for augmenting path backtracking
    // Stores {u, v} where u is the node, v is the edge used
    reg [2:0] stack_u [0:7];
    reg [2:0] stack_v [0:7];
    reg [2:0] stack_ptr;
    
    // Graph building counters
    reg [2:0] build_i, build_j;
    
    // Success flag for DFS
    reg dfs_success;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            match_R[0] <= 3'b111; match_R[1] <= 3'b111; match_R[2] <= 3'b111; match_R[3] <= 3'b111;
            match_R[4] <= 3'b111; match_R[5] <= 3'b111; match_R[6] <= 3'b111; match_R[7] <= 3'b111;
            match_L[0] <= 3'b111; match_L[1] <= 3'b111; match_L[2] <= 3'b111; match_L[3] <= 3'b111;
            match_L[4] <= 3'b111; match_L[5] <= 3'b111; match_L[6] <= 3'b111; match_L[7] <= 3'b111;
            adj[0] <= 0; adj[1] <= 0; adj[2] <= 0; adj[3] <= 0;
            adj[4] <= 0; adj[5] <= 0; adj[6] <= 0; adj[7] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= BUILD_GRAPH;
                end

                BUILD_GRAPH: begin
                    if (build_i < 8'd8 && build_j < 8'd8) begin
                        // We only care if indices are less than n, but we clear adj for all 8x8 to be safe
                        if (build_i < n && build_j < n && build_i != build_j) begin
                            if ((a[build_i] + k < a[build_j]) || (b[build_i] + k < b[build_j])) begin
                                adj[build_i][build_j] <= 1'b1;
                            end else begin
                                adj[build_i][build_j] <= 1'b0;
                            end
                        end else begin
                            adj[build_i][build_j] <= 1'b0;
                        end
                        
                        if (build_j == 8'd7) begin
                            build_j <= 0;
                            if (build_i == 8'd7) begin
                                state <= MATCH_START_U;
                                u_idx <= 0;
                            end else begin
                                build_i <= build_i + 1;
                            end
                        end else begin
                            build_j <= build_j + 1;
                        end
                    end else begin
                        state <= MATCH_START_U;
                        u_idx <= 0;
                    end
                end

                MATCH_START_U: begin
                    visited_right <= 8'b0;
                    dfs_u <= u_idx;
                    dfs_v <= 0;
                    stack_ptr <= 0;
                    
                    if (u_idx < n) begin
                        state <= MATCH_DFS;
                    end else begin
                        state <= FINALIZE;
                    end
                end

                MATCH_DFS: begin
                    if (dfs_v < n) begin
                        // Check edge and visited
                        if (adj[dfs_u][dfs_v] && !visited_right[dfs_v]) begin
                            visited_right[dfs_v] <= 1'b1;
                            
                            if (match_R[dfs_v] == 3'b111) begin
                                // Free node found - Match it
                                match_R[dfs_v] <= dfs_u;
                                match_L[dfs_u] <= dfs_v;
                                dfs_success <= 1'b1;
                                state <= MATCH_BACKTRACK;
                            end else begin
                                // Node matched - Recurse
                                // Push current state to stack
                                stack_u[stack_ptr] <= dfs_u;
                                stack_v[stack_ptr] <= dfs_v;
                                stack_ptr <= stack_ptr + 1;
                                
                                // Move to the matched node
                                dfs_u <= match_R[dfs_v];
                                dfs_v <= 0;
                                // Stay in MATCH_DFS
                            end
                        end else begin
                            // Check next neighbor
                            dfs_v <= dfs_v + 1;
                        end
                    end else begin
                        // No more neighbors for this node - fail
                        dfs_success <= 1'b0;
                        state <= MATCH_BACKTRACK;
                    end
                end

                MATCH_BACKTRACK: begin
                    if (stack_ptr == 0) begin
                        // No more stack - return to outer loop
                        u_idx <= u_idx + 1;
                        state <= MATCH_START_U;
                    end else begin
                        // Pop stack
                        stack_ptr <= stack_ptr - 1;
                        // Note: We need to read the popped values before decrementing if we were using them in same cycle,
                        // but since we decrement `stack_ptr` and `stack_ptr` is used as index, we need to be careful.
                        // Actually, we read `stack_u[stack_ptr-1]`.
                        
                        if (dfs_success) begin
                            // Update match for the popped edge
                            // `dfs_u` is currently the node that found a match (or propagated match)
                            // We want to match the popped u to the popped v
                            match_R[stack_v[stack_ptr - 1]] <= stack_u[stack_ptr - 1];
                            match_L[stack_u[stack_ptr - 1]] <= stack_v[stack_ptr - 1];
                            
                            // Return to popped u
                            dfs_u <= stack_u[stack_ptr - 1];
                            // dfs_success remains 1
                            // Continue backtracking
                        end else begin
                            // Failed to find match for current dfs_u
                            // Restore state to popped u and try next v
                            dfs_u <= stack_u[stack_ptr - 1];
                            dfs_v <= stack_v[stack_ptr - 1] + 1;
                            // Unmark visited for the popped v? 
                            // Yes, because that edge failed.
                            visited_right[stack_v[stack_ptr - 1]] <= 1'b0;
                            // Go back to DFS
                            state <= MATCH_DFS;
                        end
                    end
                end

                FINALIZE: begin
                    // Calculate result: N - matching_size
                    // matching_size is count of items in match_R that are not 3'b111
                    // Since N is small, we can do this in one cycle with a loop (combinational)
                    // But verilog in always block needs explicit assignment or a separate combinational block.
                    // We can use a variable to count in previous states, or do it here.
                    // Let's compute it here using a temporary loop variable logic (expanded or hardcoded).
                    
                    // Count matches
                    result <= n - (
                        (match_R[0] != 3'b111) + (match_R[1] != 3'b111) + 
                        (match_R[2] != 3'b111) + (match_R[3] != 3'b111) + 
                        (match_R[4] != 3'b111) + (match_R[5] != 3'b111) + 
                        (match_R[6] != 3'b111) + (match_R[7] != 3'b111)
                    );
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule