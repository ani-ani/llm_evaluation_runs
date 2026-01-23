module longest_race_path (
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_matrix [8][8],
    output reg [3:0] max_length,
    output reg done
);

    parameter N = 8;
    
    // State Encoding
    localparam IDLE = 4'b0000;
    localparam INIT = 4'b0001;
    localparam SEARCH = 4'b0010;
    localparam UPDATE_MAX = 4'b0011;
    localparam BACKTRACK = 4'b0100;
    localparam DONE = 4'b0101;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal Registers
    reg [2:0] current_node;       // Current node (0-7)
    reg [2:0] next_node_candidate; // Neighbor candidate during search
    reg [7:0] used_edges;         // Bitmask of used edges (up to 8 edges tracked via indices 0-7)
                                  // Assumption: We track used edges by their unique index in a flattened array or 
                                  // map (u,v) to u*N+v, but since N=8, u*8+v is 0-63. 64 bits is too wide for simple FSM.
                                  // Requirement says "Use internal registers... visited edge mask".
                                  // Constraint: "Ensure edge non-repetition logic handles undirected nature".
                                  // With small graph (8 nodes), max edges = 28. 
                                  // However, we are given 'used_edges' as a bitmask. Let's assume we use a 28-bit mask 
                                  // stored in multiple registers or just track visited nodes if we assume simple paths (no node repeat).
                                  // The prompt specifically says "tracks used edges via a bitmask".
                                  // Let's implement a 64-bit mask stored in 4 x 16-bit regs or similar logic.
                                  // But to be efficient in hardware for this specific problem (DFS), usually we track visited nodes or used edges.
                                  // Given the 'used_edges' hint, let's map (u,v) to index 0..27.
    
    // Mapping logic for edge mask (8 nodes, undirected). 
    // Max edges = 28. We can use a 28-bit vector.
    reg [27:0] edge_mask;
    
    // Stack for backtracking (simple linked list simulation or LIFO)
    // Max path length is up to 15 edges, so stack depth 15 is safe.
    reg [2:0] stack_node [14:0];
    reg [27:0] stack_mask [14:0];
    reg [3:0] stack_len [14:0];
    reg [3:0] stack_ptr; // Points to top of stack
    
    reg [3:0] current_length;
    reg [3:0] search_neighbor_idx; // 0 to 7 to iterate neighbors
    
    // Helper to get unique edge index 0-27
    function [4:0] get_edge_idx;
        input [2:0] u;
        input [2:0] v;
        reg [2:0] min_node;
        reg [2:0] max_node;
    begin
        min_node = (u < v) ? u : v;
        max_node = (u > v) ? u : v;
        // Formula: max_node * (max_node-1) / 2 + min_node  (Cantor pairing for undirected graph)
        // For N=8:
        // 0->1: idx 0
        // 0->2: idx 1
        // ...
        // 1->2: idx 7 (0+7)
        // 1->3: idx 8
        // 2->3: idx 14
        // 6->7: idx 27
        case (max_node)
            3'd1: get_edge_idx = min_node; // 0->1 (0)
            3'd2: get_edge_idx = 3'd1 + min_node; // (0->2=1, 1->2=2)
            3'd3: get_edge_idx = 3'd3 + min_node; // (0->3=3, 1->3=4, 2->3=5)
            3'd4: get_edge_idx = 3'd6 + min_node; // (0->4=6...
            3'd5: get_edge_idx = 3'd10 + min_node;
            3'd6: get_edge_idx = 3'd15 + min_node;
            3'd7: get_edge_idx = 3'd21 + min_node;
            default: get_edge_idx = 5'd0;
        endcase
    end
    endfunction

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 4'b0;
            done <= 1'b0;
            edge_mask <= 28'b0;
            stack_ptr <= 4'd0;
            current_length <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize search.
                    // We need to start from every node except 1.
                    // To implement this iteratively without recursion, we reset search parameters 
                    // and start finding paths from 'current_node'. 
                    // We will loop through nodes 0, 2..7 (assuming node 1 is the target/end, and 0 is unused or mapped).
                    // The problem says "exploring simple paths starting from any node (1-7)". 
                    // It also says "ending at node 1". Usually paths start NOT at the target to avoid 0-length loop.
                    // Let's start from 2, then 3, 4, 5, 6, 7, 0 (if valid). 
                    // We need a loop mechanism for start nodes. 
                    // Let's use a register 'search_start_node' to iterate 0..7.
                    // Since we are purely iterative, we treat this as a DFS.
                    
                    // Reset global max
                    max_length <= 4'b0;
                    
                    // Initialize start node iteration (assuming we search from 2,3,4,5,6,7,0)
                    // Or simply reset stack and start DFS. 
                    // We will implement a 'wrapper' loop over start nodes.
                    // Let's use 'current_node' to track the current root of the search.
                    current_node <= 3'd2; // Start trying roots from 2
                    
                    // Clear stack for new search
                    stack_ptr <= 4'd0;
                    edge_mask <= 28'b0;
                    current_length <= 4'd0;
                    
                    // Move to SEARCH to push the first node (or handle logic)
                    // Actually, we need to push the root node first.
                    // Let's handle root node logic in a specific sub-state or just SEARCH.
                    // To keep it simple: 
                    // We will treat 'current_node' as the node we are currently AT.
                    // But to start a search from node X, we push X, then look for neighbors.
                    // However, the path is defined as edges. Starting at X, length 0.
                    
                    state <= SEARCH;
                    search_neighbor_idx <= 3'd0;
                end

                SEARCH: begin
                    // Current logic: We are at 'current_node'.
                    // Look for a valid neighbor 'search_neighbor_idx' (0..7).
                    // Constraints:
                    // 1. adj_matrix[current_node][search_neighbor_idx] == 1
                    // 2. Edge (current_node, search_neighbor_idx) not in edge_mask
                    
                    if (search_neighbor_idx < 3'd8) begin
                        // Check valid neighbor
                        if (adj_matrix[current_node][search_neighbor_idx] && 
                            !edge_mask[get_edge_idx(current_node, search_neighbor_idx)]) begin
                            
                            // Found a valid neighbor. 
                            // PUSH: Save state (current_node, current_mask, current_length) to stack
                            // UPDATE: Move to neighbor, update mask, increment length
                            // Check if we need to update max (if neighbor is node 1)
                            
                            // Wait one cycle for logic or do it in UPDATE_MAX/BACKTRACK?
                            // Let's push and move in this cycle? 
                            // Since it's combinational next state logic, we can do it in UPDATE_MAX if we define it carefully.
                            // Actually, let's make UPDATE_MAX the state where we perform the push and move.
                            
                            next_node_candidate <= search_neighbor_idx; // Store which neighbor we found
                            state <= UPDATE_MAX;
                        end else begin
                            // Try next neighbor
                            search_neighbor_idx <= search_neighbor_idx + 1'b1;
                            state <= SEARCH;
                        end
                    end else begin
                        // No more neighbors. Backtrack.
                        state <= BACKTRACK;
                    end
                end

                UPDATE_MAX: begin
                    // We found a valid edge from 'current_node' to 'next_node_candidate'.
                    // 1. Update max_length if next_node_candidate == 1 and current_length+1 > max_length
                    // 2. Push current state to stack
                    // 3. Update current_node to next_node_candidate
                    // 4. Update edge_mask
                    // 5. Increment current_length
                    // 6. Reset neighbor index to 0 for the new node
                    
                    // Check if path ends at 1
                    if (next_node_candidate == 3'd1) begin
                        if (current_length + 1'b1 > max_length) begin
                            max_length <= current_length + 1'b1;
                        end
                    end
                    
                    // Push to stack
                    if (stack_ptr < 4'd15) begin
                        stack_node[stack_ptr] <= current_node;
                        stack_mask[stack_ptr] <= edge_mask;
                        stack_len[stack_ptr] <= current_length;
                        stack_ptr <= stack_ptr + 1'b1;
                    end
                    
                    // Update state
                    // Update edge mask with the edge (current_node, next_node_candidate)
                    edge_mask[get_edge_idx(current_node, next_node_candidate)] <= 1'b1;
                    
                    // Move to next node
                    current_node <= next_node_candidate;
                    current_length <= current_length + 1'b1;
                    search_neighbor_idx <= 3'd0; // Reset search for new node
                    
                    state <= SEARCH;
                end

                BACKTRACK: begin
                    // We are stuck at current_node (no neighbors or finished checking neighbors).
                    // If stack is empty, we are done with this root path.
                    // If stack has items, pop and go back.
                    
                    if (stack_ptr == 4'd0) begin
                        // Finished current root path. Try next root node.
                        // Move current_node to next root.
                        // Current 'current_node' is the root we just finished (or started with).
                        // Increment current_node to try next.
                        if (current_node < 3'd7) begin
                            current_node <= current_node + 1'b1;
                            // Skip node 1 as start (path to 1 implies start != 1 usually)
                            // If next is 1, skip to 2? Or just logic to 8.
                            // Let's just loop 0..7.
                            // Reset masks and length
                            edge_mask <= 28'b0;
                            current_length <= 4'd0;
                            search_neighbor_idx <= 3'd0;
                            // Check if we reached end of nodes
                            if (current_node == 3'd7) begin
                                // Actually we just incremented to 7. We need to handle 7, then stop.
                                // Let's say we continue until we try 'current_node' = 7 and finish it.
                                // Or simpler: stop when current_node wraps around? 
                                // Let's add a flag or specific node value to stop.
                                // Let's stop when current_node becomes 7 and we finish it.
                                // But here we are BACKTRACKING from 'current_node' (which is finished).
                                // If 'current_node' was 7, we are done.
                                state <= DONE;
                            end else begin
                                state <= SEARCH;
                            end
                        end else begin
                            // Was 7, finished
                            state <= DONE;
                        end
                    end else begin
                        // Pop stack
                        stack_ptr <= stack_ptr - 1'b1;
                        current_node <= stack_node[stack_ptr - 1'b1];
                        edge_mask <= stack_mask[stack_ptr - 1'b1];
                        current_length <= stack_len[stack_ptr - 1'b1];
                        
                        // We popped back to 'current_node'. We were checking neighbors of this node.
                        // We need to resume checking neighbors from the index AFTER the one we just tried.
                        // But we don't store the neighbor index in stack in this simple design.
                        // However, 'search_neighbor_idx' was left at the position where we found the edge.
                        // We need to increment it to continue the loop.
                        // Wait, we are popping from 'UPDATE_MAX' logic which had just found a neighbor.
                        // So the 'search_neighbor_idx' currently points to the neighbor we just took.
                        // We need to increment it to try the next one.
                        // So we pop, restore state, then increment neighbor index.
                        
                        // To do this correctly in a single cycle, we need to know what 'search_neighbor_idx' was at the point of push.
                        // Actually, in iterative DFS, we usually store 'next_node_index' on stack.
                        // Since we don't, let's assume we can recover.
                        // If we are here, 'current_node' is restored. 
                        // The 'search_neighbor_idx' register holds the index that led to the popped state.
                        // We need to increment it.
                        // But wait, the stack restoration overwrites 'current_node' and 'edge_mask'.
                        // We need to increment the neighbor index FOR THE NEWLY RESTORED 'current_node'.
                        // But we lost the neighbor index of the restored node.
                        // Correction: We need to store the 'search_neighbor_idx' in the stack.
                        // Let's add stack_nidx [14:0] reg [2:0].
                        // Or, simpler: When we BACKTRACK, we pop, then we are at 'current_node'.
                        // The logic in SEARCH checks neighbors from 0. 
                        // If we popped back, we have already tried one neighbor. We will try from 0 again, which is duplicate.
                        // So we MUST store the index.
                        
                        // NOTE: I will modify the stack to include the neighbor index.
                        // The code below will assume 'stack_nidx' exists.
                        // Since I am writing the code block, I will declare it in the module header scope.
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // NOTE: The BACKTRACK logic above requires a stack for neighbor indices to be fully correct.
    // Let's refine the code to include that.
    // The code below replaces the incomplete logic in the always block.
    
    // Re-declaring registers to ensure they are in scope if this was split (conceptually)
    reg [2:0] stack_nidx [14:0];
    
    // Corrected Always Block (Replacing the one above for completeness)
    // Using separate block for clarity in the final output string construction
    
    // To ensure the output is a single module, I will write the logic as if the registers above are declared.
    // Since I cannot overwrite the previous block in the thought process easily without confusion, 
    // I will combine the logic into the final single `always` block in the output code string.
    
    // The final code will have:
    // 1. State definitions
    // 2. Internal regs (current_node, edge_mask, stack_node, stack_mask, stack_len, stack_nidx, current_length, search_neighbor_idx)
    // 3. Logic for SEARCH -> UPDATE_MAX -> BACKTRACK -> DONE.
    
endmodule

// Refactoring the logic into the synthesizable module structure:

module final_longest_race_path (
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_matrix [8][8],
    output reg [3:0] max_length,
    output reg done
);

    parameter N = 8;
    
    localparam IDLE = 3'b000, INIT = 3'b001, SEARCH = 3'b010, UPDATE = 3'b011, BACKTRACK = 3'b100, DONE = 3'b101;
    
    reg [2:0] state;
    reg [2:0] current_node;
    reg [2:0] neighbor_idx;
    reg [27:0] edge_mask;
    reg [3:0] current_len;
    
    // Stack for backtracking: stores state when we go down a path
    reg [2:0] stack_node [14:0];
    reg [27:0] stack_edge [14:0];
    reg [3:0] stack_len [14:0];
    reg [2:0] stack_nidx [14:0]; // Store the neighbor index we just took, so we can resume searching next
    reg [3:0] stack_ptr;
    
    // Root node iterator: since we need to try all start nodes (0-7 except 1)
    reg [2:0] root_node;
    reg root_done_flag; // Flag to indicate we finished root_node

    // Helper function for edge indexing
    function [4:0] get_edge_idx;
        input [2:0] u;
        input [2:0] v;
    begin
        if (u < v) get_edge_idx = u + (v * (v - 1)) / 2;
        else get_edge_idx = v + (u * (u - 1)) / 2;
    end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_length <= 4'b0;
            stack_ptr <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= INIT;
                end

                INIT: begin
                    // Initialize search parameters
                    max_length <= 4'b0;
                    root_node <= 3'd0; // Start checking from node 0
                    root_done_flag <= 1'b0;
                    
                    // Initialize the first search
                    current_node <= 3'd0;
                    current_len <= 4'd0;
                    edge_mask <= 28'b0;
                    neighbor_idx <= 3'd0;
                    stack_ptr <= 4'd0;
                    
                    state <= SEARCH;
                end

                SEARCH: begin
                    // Try to find a valid neighbor from current_node
                    // Skip node 1 as start? The problem says "starting from any node (1-7) and ending at node 1".
                    // This implies paths of length >= 1. 
                    // If we are at node 1 immediately (length 0), we should not count it unless we moved there.
                    // Our logic pushes edges. 
                    
                    // If current_len == 0 and current_node == 1, we can't extend? 
                    // Actually we should check all roots. If root is 1, we start at 1. 
                    // Path starting at 1 ending at 1 is just staying there (len 0). 
                    // Usually we want paths from X -> 1 where X != 1. 
                    // Let's enforce: if current_len == 0, we cannot go to 1? Or just ignore length 0 paths.
                    // Let's just follow the graph. 
                    
                    if (neighbor_idx < 3'd8) begin
                        if (adj_matrix[current_node][neighbor_idx] && 
                            !edge_mask[get_edge_idx(current_node, neighbor_idx)]) begin
                            
                            // Valid neighbor found. Move to UPDATE state to handle it.
                            state <= UPDATE;
                        end else begin
                            // Check next neighbor
                            neighbor_idx <= neighbor_idx + 1'b1;
                            state <= SEARCH;
                        end
                    end else begin
                        // No more neighbors, backtrack
                        state <= BACKTRACK;
                    end
                end

                UPDATE: begin
                    // 1. Update max length if we hit node 1
                    if (neighbor_idx == 3'd1 && current_len > 0) begin // End at 1, path length > 0
                        if (current_len + 1'b1 > max_length) begin
                            max_length <= current_len + 1'b1;
                        end
                    end
                    
                    // 2. Push current state to stack
                    if (stack_ptr < 4'd15) begin
                        stack_node[stack_ptr] <= current_node;
                        stack_edge[stack_ptr] <= edge_mask;
                        stack_len[stack_ptr] <= current_len;
                        stack_nidx[stack_ptr] <= neighbor_idx; // Store which neighbor we are taking
                        stack_ptr <= stack_ptr + 1'b1;
                    end
                    
                    // 3. Update current state
                    edge_mask[get_edge_idx(current_node, neighbor_idx)] <= 1'b1;
                    current_node <= neighbor_idx;
                    current_len <= current_len + 1'b1;
                    neighbor_idx <= 3'd0; // Start search from node 0 of new node
                    
                    state <= SEARCH;
                end

                BACKTRACK: begin
                    if (stack_ptr == 4'd0) begin
                        // Finished current root path. Try next root node.
                        if (root_node < 3'd7) begin
                            root_node <= root_node + 1'b1;
                            
                            // Setup next root
                            current_node <= root_node + 1'b1;
                            current_len <= 4'd0;
                            edge_mask <= 28'b0;
                            neighbor_idx <= 3'd0;
                            
                            state <= SEARCH;
                        end else begin
                            // All roots tried
                            state <= DONE;
                        end
                    end else begin
                        // Pop stack
                        stack_ptr <= stack_ptr - 1'b1;
                        current_node <= stack_node[stack_ptr - 1'b1];
                        edge_mask <= stack_edge[stack_ptr - 1'b1];
                        current_len <= stack_len[stack_ptr - 1'b1];
                        
                        // Important: Restore neighbor index to the one we took + 1
                        // The stored index is the neighbor we followed. We need to continue searching AFTER it.
                        neighbor_idx <= stack_nidx[stack_ptr - 1'b1] + 1'b1;
                        
                        state <= SEARCH;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule

// The prompt asks for a module named 'longest_race_path'.
// I will provide the clean, final code based on the 'final_longest_race_path' logic but with the correct name.

module longest_race_path (
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_matrix [8][8],
    output reg [3:0] max_length,
    output reg done
);

    parameter N = 8;
    
    localparam IDLE = 3'b000, INIT = 3'b001, SEARCH = 3'b010, UPDATE = 3'b011, BACKTRACK = 3'b100, DONE = 3'b101;
    
    reg [2:0] state;
    reg [2:0] current_node;
    reg [2:0] neighbor_idx;
    reg [27:0] edge_mask;
    reg [3:0] current_len;
    
    // Stack
    reg [2:0] stack_node [14:0];
    reg [27:0] stack_edge [14:0];
    reg [3:0] stack_len [14:0];
    reg [2:0] stack_nidx [14:0];
    reg [3:0] stack_ptr;
    
    reg [2:0] root_node;

    function [4:0] get_edge_idx;
        input [2:0] u;
        input [2:0] v;
    begin
        if (u < v) get_edge_idx = u + (v * (v - 1)) / 2;
        else get_edge_idx = v + (u * (u - 1)) / 2;
    end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_length <= 4'b0;
            stack_ptr <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= INIT;
                end
                INIT: begin
                    max_length <= 4'b0;
                    root_node <= 3'd0;
                    current_node <= 3'd0;
                    current_len <= 4'd0;
                    edge_mask <= 28'b0;
                    neighbor_idx <= 3'd0;
                    stack_ptr <= 4'd0;
                    state <= SEARCH;
                end
                SEARCH: begin
                    if (neighbor_idx < 3'd8) begin
                        if (adj_matrix[current_node][neighbor_idx] && !edge_mask[get_edge_idx(current_node, neighbor_idx)]) begin
                            state <= UPDATE;
                        end else begin
                            neighbor_idx <= neighbor_idx + 1'b1;
                            state <= SEARCH;
                        end
                    end else begin
                        state <= BACKTRACK;
                    end
                end
                UPDATE: begin
                    if (neighbor_idx == 3'd1 && current_len > 0) begin
                        if (current_len + 1'b1 > max_length) begin
                            max_length <= current_len + 1'b1;
                        end
                    end
                    if (stack_ptr < 4'd15) begin
                        stack_node[stack_ptr] <= current_node;
                        stack_edge[stack_ptr] <= edge_mask;
                        stack_len[stack_ptr] <= current_len;
                        stack_nidx[stack_ptr] <= neighbor_idx;
                        stack_ptr <= stack_ptr + 1'b1;
                    end
                    edge_mask[get_edge_idx(current_node, neighbor_idx)] <= 1'b1;
                    current_node <= neighbor_idx;
                    current_len <= current_len + 1'b1;
                    neighbor_idx <= 3'd0;
                    state <= SEARCH;
                end
                BACKTRACK: begin
                    if (stack_ptr == 4'd0) begin
                        if (root_node < 3'd7) begin
                            root_node <= root_node + 1'b1;
                            current_node <= root_node + 1'b1;
                            current_len <= 4'd0;
                            edge_mask <= 28'b0;
                            neighbor_idx <= 3'd0;
                            state <= SEARCH;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        stack_ptr <= stack_ptr - 1'b1;
                        current_node <= stack_node[stack_ptr - 1'b1];
                        edge_mask <= stack_edge[stack_ptr - 1'b1];
                        current_len <= stack_len[stack_ptr - 1'b1];
                        neighbor_idx <= stack_nidx[stack_ptr - 1'b1] + 1'b1;
                        state <= SEARCH;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
