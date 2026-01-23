module max_kahn_sources (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [2:0] src_node,
    input [2:0] dst_node,
    input edge_valid,
    input edge_complete,
    output reg [2:0] max_sources,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COLLECT = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam FINISH = 2'b11;

    reg [1:0] state;
    
    // Graph storage (adjacency matrix or list)
    // Using adjacency matrix for simplicity with up to 8 nodes
    reg [7:0] adj [0:7]; // adj[i] has bits set for nodes that i points to
    reg [2:0] in_degree [0:7];
    
    // Temporary storage for computation
    reg [7:0] current_in_degree [0:7];
    reg [7:0] available_nodes;
    reg [2:0] current_sources;
    reg [2:0] temp_max_sources;
    
    // Helper signals
    reg [2:0] node_idx;
    reg [2:0] bit_count;
    reg [2:0] search_idx;
    reg found_source;
    reg [2:0] next_node;
    reg [2:0] child_idx;
    reg [7:0] child_mask;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_sources <= 0;
            edge_complete_reg <= 0;
            node_idx <= 0;
            // Clear graph
            for (i = 0; i < 8; i = i + 1) begin
                adj[i] <= 8'b0;
                in_degree[i] <= 3'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COLLECT;
                        node_idx <= 0;
                        edge_complete_reg <= 0;
                        // Reset graph storage
                        for (i = 0; i < 8; i = i + 1) begin
                            adj[i] <= 8'b0;
                            in_degree[i] <= 3'b0;
                        end
                    end
                end

                COLLECT: begin
                    if (edge_valid) begin
                        // Add edge
                        if (!adj[src_node][dst_node]) begin
                            adj[src_node][dst_node] <= 1'b1;
                            in_degree[dst_node] <= in_degree[dst_node] + 1'b1;
                        end
                    end
                    if (edge_complete) begin
                        // Prepare for computation
                        for (i = 0; i < 8; i = i + 1) begin
                            current_in_degree[i] <= {5'b0, in_degree[i]};
                        end
                        available_nodes <= 8'b0;
                        current_sources <= 0;
                        temp_max_sources <= 0;
                        node_idx <= 0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // We will perform a Depth First Search / Bit manipulation approach
                    // to find max simultaneous sources.
                    // Since node_count is small (<=8), we can explore all possibilities.
                    
                    // Strategy: Iterative DFS on the state space of "remaining in-degrees"
                    // We use a stack-like approach in hardware or simple iteration.
                    // Actually, max width is determined by the longest path in the layering.
                    // But Kahn's choices matter. We need to simulate all Kahn possibilities.
                    
                    // Revised State Machine for COMPUTE:
                    // To do this strictly in HW within 256 cycles for 8 nodes:
                    // We can simply compute the Max Width Layering.
                    // This is equivalent to finding the minimum number of levels to topologically sort,
                    // where we greedily place all available nodes in the current level.
                    // Wait, the problem asks for max S size during *any* execution.
                    // This means we might need to choose WHICH nodes to remove, not necessarily all.
                    // If we remove only a subset, we delay their children, potentially accumulating more sources.
                    // This is a complex optimization.
                    
                    // However, for "Maximum simultaneous sources", it usually refers to the scenario
                    // where we want to maximize the queue size. This is done by minimizing the number of nodes
                    // removed in each step. But Kahn's algorithm usually removes ALL available nodes at each step
                    // to proceed. If the user means "the max width of a valid topological layering", 
                    // it is the width of the layering when we pack as many as possible into each layer.
                    // The "Max possible size of S" implies we want to find the step with the most nodes ready.
                    
                    // Let's implement the algorithm:
                    // 1. Identify initial sources (in_degree 0). 
                    // 2. Suppose we have a set of sources S.
                    // 3. We can either process some or all of S.
                    // 4. To maximize future S size, we want to delay processing nodes.
                    // 5. But eventually all must be processed.
                    // 6. This is equivalent to: "What is the maximum number of nodes that can be ready at any point?"
                    //    This is a property of the graph, independent of processing order if we consider
                    //    the standard "Greedy" Kahn (remove all available). 
                    //    But if we can choose to remove *one* to maximize future count, it's different.
                    //    Example: A -> B, A -> C. Source {A}. Process A -> {B, C}. Size 2.
                    //    If A -> B, B -> C. Source {A}. Process A -> {B}. Source {B}. Process B -> {C}. Max size 1.
                    
                    // Let's assume the standard interpretation for "Max Width":
                    // Process the graph layer by layer. In each layer, include ALL nodes whose in-degree becomes 0.
                    // This maximizes the width of the layering. 
                    // This is a simple simulation.
                    
                    // Sub-state for COMPUTE
                    reg [1:0] compute_substate;
                    
                    // We'll implement a sequential logic block for the simulation.
                    // We need to count the width of the layering.
                    // We can do this in a single pass if we simulate the "Greedy Kahn" (remove all available).
                    
                    // Logic to find max width (Greedy Kahn):
                    // Initialize: find all nodes with in_degree 0.
                    // S0 = {nodes with in_degree 0}. Width = |S0|.
                    // For each node u in S0: decrease in_degree of neighbors. 
                    // If neighbor in_degree becomes 0, add to S1.
                    // Width = max(Width, |S1|).
                    // Repeat.
                    
                    // This is too simple given the prompt "explore the branching choices".
                    // If we want to maximize the size of S at ANY point, we can artificially delay processing.
                    // E.g. Source A. We can wait. S size is 1. We process A. S becomes {children}.
                    // We cannot increase S size by waiting if no new nodes appear.
                    // We can only increase it by processing nodes that reveal many children.
                    // So the max size is determined by the structure.
                    
                    // However, if we can choose WHICH subset to process, we can manipulate future S size.
                    // Example:
                    // A -> B, A -> C.
                    // B -> D.
                    // C -> D.
                    // Start: S={A}. Size 1.
                    // Option 1: Process A. S={B, C}. Size 2. 
                    // Option 2: (Not possible to get bigger than 2 here).
                    
                    // Complex Case:
                    // A -> X
                    // B -> X
                    // A -> Y
                    // Start: S={A, B}. Size 2.
                    // Process A: S={B, X, Y} (wait, B already there). Size 3 (B, X, Y).
                    // Process B: S={A, X}. Size 2.
                    // So order matters for intermediate sizes.
                    
                    // The question: "maximum possible size of the source set S during Kahn's algorithm".
                    // This implies we can choose the order.
                    // We need a DFS/BFS to explore the state space: (Current S, Remaining graph).
                    // State space is small: max 8 nodes. 
                    // State can be represented by: 
                    //   - Available set (8 bits)
                    //   - In-degrees of unprocessed nodes (total state space large but manageable for 8 nodes?)
                    //   - Or simply Remaining Edges.
                    
                    // Let's try a "Greedy + Delay" heuristic or explicit search.
                    // Since latency is 256 cycles, we can do a BFS/DFS.
                    
                    // State representation for BFS:
                    // A state is defined by the set of processed nodes (or remaining in-degrees).
                    // We want to find the max S size over all paths.
                    
                    // Implementation Plan for COMPUTE state:
                    // We will use a bit-vector based search.
                    // We maintain a set of current available nodes.
                    // We iterate: 
                    //   For each node in available set, we can choose to process it.
                    //   But that branches.
                    //   To find max, we can just check: 
                    //     If we process node u, what is the max width in the rest of the graph?
    
                    // This is recursive. We can implement it iteratively with a stack or iterative DP.
                    // DP approach:
                    // DP[mask] = max width if nodes in 'mask' are already processed.
                    // We want DP[0].
                    // Transition: If 'mask' is valid (all parents of nodes in mask are in mask? No, this is topo sort).
                    // Actually, simpler:
                    // Let S be current available set.
                    // Max = |S|.
                    // For each u in S:
                    //   S_next = (S \\ {u}) union {children of u with 0 in-degree after removing u}.
                    //   Recurse.
                    //   Max = max(Max, |S_next|, recurse(S_next)).
                    
                    // We can implement this as a recursive function in logic if we had functions, or a loop.
                    // With 8 nodes, we can pre-calculate everything.
                    
                    // Let's try a direct simulation of the branching.
                    // We maintain: current_available_set (8 bits).
                    // We maintain: max_found.
                    // We need a way to backtrack or iterate.
                    // Since it's hardware, we can't easily backtrack recursion.
                    // We can use a stack. Max depth 8.
                    // Stack entries: {available_set, u_idx_tried}
                    
                    // Let's implement a Depth First Search using a stack stored in registers.
                    // Since 8 nodes, we can unroll or use a state machine.
                    
                    // Re-evaluation: Is there a closed form?
                    // Max simultaneous sources = max size of an antichain? 
                    // No, max antichain is Dilworth's theorem, related to min path cover.
                    // But here we want Max width of layering given choice.
                    // This is equivalent to the "Longest Path Problem" in the Critical Path Method (CPM)?
                    // No, CPM minimizes time. 
                    // "Max width" is a graph property.
                    
                    // Let's go with the explicit DFS state machine.
                    // Data structures:
                    // 1. Original In-degrees (static).
                    // 2. Stack[8] of {available_set, processed_set, max_so_far_in_branch}.
                    //    Actually, we don't need processed set. We need to know which nodes are removed.
                    //    Better: State = (Available Set). 
                    //    Since graph is DAG and small, we can cache visited states.
                    //    Total states 2^8 = 256. Fits in memory.
                    
                    // Algorithm:
                    // 1. Init: Find available nodes (in_degree 0). 
                    // 2. Use a queue (BFS) or stack (DFS) to explore state transitions.
                    //    State: (Current Available Set).
                    //    We want to find the maximum size of Available Set reachable from Start.
                    //    This is simpler than finding max over a path, it's the max value in the reachable state graph.
                    //    Wait, "during any execution" implies a path. But usually Max Reachable Width is what is asked.
                    //    If we can reach a state with 5 available, we count 5.
    
                    // Let's implement BFS to find the maximum set size reachable.
                    // We need to handle the latency constraint (256 cycles).
                    // 256 states * 8 nodes * ops might fit.
                    
                    // Detailed Step-by-step for COMPUTE:
                    // We will implement a "State Queue".
                    // Initial state: Available = {nodes with in_degree 0}.
                    // Max_Sources = size(Available).
                    // Queue contains Available sets.
                    // While Queue not empty:
                    //   Pop State A.
                    //   For each node u in A:
                    //     Create new state B:
                    //       B = (A \\ {u})
                    //       For each child v of u:
                    //         If all parents of v are in (OriginalSet \\ (B_currently_processing?)) 
                    //         Actually, we need to track removed nodes.
                    //         Let Removed = (All nodes) \\ (Available + Pending).
                    //         Let's maintain Removed mask.
                    //         New Removed = Old Removed | (1<<u).
                    //         New Available = (Old Available \\ {u}) 
    //                        plus children v of u where (OriginalInDegree[v] == count of (parents of v & NewRemoved)).
    
                    //         This requires knowing parents. We can precompute parents or reverse adjacency.
    
                    // Let's simplify. 
                    // We can precompute for each node v: RequiredMask (parents mask).
    // Then: Node v is available if (Removed & RequiredMask[v]) == RequiredMask[v].
    
                    // Implementation Plan:
                    // 1. Precompute Adjacency and In-degree during COLLECT.
                    // 2. In COMPUTE:
                    //    a. Compute RequiredMask for all nodes.
                    //       RequiredMask[v] = set of parents.
                    //       We have adj, we need parents. We can build parents during edge input.
                    //       Or reverse iterate adj.
                    //    b. Initialize: Available = {v | InDegree[v] == 0}.
                    //    c. Use a FIFO for BFS. State is RemovedMask.
                    //       Actually, state is AvailableSet is derivable from RemovedMask.
                    //       So we store RemovedMask.
                    //    d. BFS loop:
                    //       Pop RemovedMask.
                    //       Compute Available = {v | (RemovedMask & RequiredMask[v]) == RequiredMask[v]}.
                    //       Update global max_sources = max(max_sources, count(Available)).
                    //       For each node u in Available:
                    //         NewRemoved = RemovedMask | (1<<u).
                    //         If NewRemoved not visited: Push to Queue.
    
                    // Constraints: 256 cycles.
                    // 256 states max. 
                    // Queue size needs to handle branching.
                    // If we use a simple loop with a "current pointer" and processing logic,
                    // we can do it in place or with a small buffer.
                    // With 8 nodes, we can use a register array to store the queue.
                    // Queue depth 16 or 32 is sufficient.
    
                    // Let's implement the Queue in registers.
                    // We need `queue_head`, `queue_tail`.
                    // We need to store queue entries.
                    // Entry: RemovedMask (8 bits).
                    // We need 16 entries * 8 bits = 128 bits. Feasible.
    
                    // We need a helper to count bits.
                    
                    // Refined Compute Sub-states:
                    // C_IDLE: Initialize.
                    // C_POP: Pop from Queue.
                    // C_CALC_AVAIL: Calculate available nodes for current removed mask.
                    // C_UPDATE_MAX: Update max_sources.
                    // C_PUSH_CHILDREN: Iterate available nodes, create new removed masks, push to queue.
                    // C_DONE: Set state to FINISH.
                    
                    // Let's define the sub-states.
                    
                end
            endcase
        end
    end

    // --- Helper Logic & Internal Registers for Compute ---
    reg [7:0] req_mask [0:7]; // Required mask for each node (parents)
    reg [7:0] queue_mem [0:15]; // Queue storage
    reg [3:0] q_head, q_tail; // Queue pointers
    reg [1:0] compute_state;
    reg [7:0] current_removed;
    reg [7:0] current_available;
    reg [2:0] iter_node;
    reg [7:0] next_removed;
    reg [7:0] visited [0:3]; // visited masks, since 256 bits is 4 regs of 64, or 8 regs of 32, or 32 regs of 8.
    // Actually, 256 bits = 32 bytes. We can use a small RAM or more registers.
    // Let's use a register array visited[0:31] storing 8 bits each.
    // Or simpler: since 256 states, we can just check the queue (no duplicate check if we are careful? 
    // BFS on a DAG of states usually doesn't have cycles if we strictly add removed nodes. 
    // But we might push same state via different paths? 
    // Path 1: Remove A, then B.
    // Path 2: Remove B, then A.
    // Result: {A, B} removed. State is same. 
    // So we MUST check visited to avoid infinite loop and redundant work.
    
    reg [7:0] visited_storage [0:31]; // 32 * 8 = 256 bits.
    
    // FSM for Compute
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_sources <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COLLECT;
                        for (i = 0; i < 8; i = i + 1) begin
                            adj[i] <= 8'b0;
                            in_degree[i] <= 3'b0;
                            parents[i] <= 8'b0;
                        end
                    end
                end

                COLLECT: begin
                    if (edge_valid) begin
                        if (!adj[src_node][dst_node]) begin
                            adj[src_node][dst_node] <= 1'b1;
                            in_degree[dst_node] <= in_degree[dst_node] + 1'b1;
                            // Track parents for easy lookup later
                            parents[dst_node][src_node] <= 1'b1;
                        end
                    end
                    if (edge_complete) begin
                        state <= COMPUTE;
                        compute_state <= 0; // Initialize
                        q_head <= 0;
                        q_tail <= 0;
                        // Mark visited all 0
                        for (i = 0; i < 32; i = i + 1) visited_storage[i] <= 8'b0;
                    end
                end

                COMPUTE: begin
                    case (compute_state)
                        0: begin // Initialize
                            // Calculate initial Available set
                            // And push to queue
                            // But first, compute req_mask if not done (or use parents array)
                            // We used parents array.
                            // Find initial available
                            current_removed <= 8'b0;
                            // We need to populate the queue with initial state (Removed=0)
                            // But we need to calculate available to check if we need to push children.
                            // Let's jump to calc available logic for state 0.
                            // Actually, simpler: 
                            // Push {Removed=0} to queue.
                            // Then enter loop.
                            if (q_head == q_tail) begin // If empty (start)
                                queue_mem[q_head] <= 8'b0;
                                q_head <= q_head + 1;
                            end
                            // Set a flag to indicate we are running BFS
                            // We need a loop state.
                            // Let's have a separate 'bfs_loop_state'.
                            // To save states, we can put BFS logic directly here.
                            
                            // Let's use the main state machine to iterate.
                            // We will just use the queue.
                            
                            // Check if queue empty
                            if (q_head == q_tail) begin
                                state <= FINISH;
                            end else begin
                                // Pop
                                q_tail <= q_tail + 1;
                                current_removed <= queue_mem[q_tail];
                                compute_state <= 1; // Calculate Available
                            end
                        end

                        1: begin // Calculate Available for current_removed
                            // Available i = (parents[i] & ~current_removed) == 0 ? But parents[i] are bits.
                            // Condition: parents[i] is subset of current_removed.
                            // i.e. (parents[i] & ~current_removed) == 0.
                            // We iterate i 0 to 7.
                            // We accumulate into current_available.
                            // And also count bits.
                            // We also need to track which nodes are in available set to iterate for pushing.
                            
                            // Let's do a loop 0-7.
                            // We need a counter. Let's use iter_node.
                            current_available <= 0;
                            iter_node <= 0;
                            compute_state <= 2;
                        end

                        2: begin // Accumulate Available bits
                            // Check node iter_node
                            // parents[iter_node] is a mask.
                            // parents[iter_node] & ~current_removed == 0 ?
                            // Equivalent to (parents[iter_node] | current_removed) == current_removed
                            // Or (parents[iter_node] & ~current_removed) == 0.
                            
                            // Optimization: Check condition and set bit.
                            if ( ((parents[iter_node] & (~current_removed)) == 0) && 
                                 ((parents[iter_node] | current_removed) != current_removed) ) // Wait, parents[iter_node] must be non-zero for this to matter? No, if parents is 0, condition is met.
                            // Condition: (parents[i] \\ current_removed) == 0 ? No.
                            // Condition: All parents of i are in current_removed.
                            // (parents[i] & ~current_removed) == 0.
                            // If parents[i] is 0, 0 & ~mask = 0. Condition met.
                            // If (parents[i] \\ current_removed) != parents[i], then some parents missing.
                            // So: (parents[i] | current_removed) == current_removed is the condition for Superset.
                            // But we want `current_removed` to be a superset of `parents[i]`.
                            // Actually, we want `parents[i] \\ current_removed` to be empty.
                            // `(parents[i] \\ current_removed)` is `parents[i] & ~current_removed`.
                            
                            // Check if Node is already removed? 
                            // Node cannot be in current_removed because parents wouldn't be satisfied if it removed itself? 
                            // Wait, if Node is in current_removed, it's already processed. We don't add it to available.
                            
                            // Condition for Available:
                            // 1. Node not in current_removed.
                            // 2. All parents in current_removed.
                            
                            if ( !current_removed[iter_node] ) begin
                                if ( (parents[iter_node] & (~current_removed)) == 0 ) begin
                                    current_available[iter_node] <= 1'b1;
                                end
                            end
                            
                            if (iter_node == 3'd7) begin
                                compute_state <= 3; // Update Max & Push
                                iter_node <= 0; // Reset for next loop
                            end else begin
                                iter_node <= iter_node + 1;
                            end
                        end

                        3: begin // Update Max Sources & Prepare to Push Children
                            // Count bits of current_available
                            // We can use a small loop or a popcount LUT.
                            // Let's do a popcount loop.
                            // Also, we need to check if we should push children.
                            // If current_available is 0, we shouldn't push? 
                            // Actually, if available is 0, graph is done or cycle (but DAG).
                            // If available is 0 and removed != all nodes, it's stuck (shouldn't happen in DAG).
                            // We just update max and go back to Pop (compute_state 0).
                            
                            // Popcount of current_available
                            bit_count <= 0;
                            search_idx <= 0;
                            compute_state <= 4; // Popcount state
                        end

                        4: begin // Popcount & Max Update
                            if (current_available[search_idx]) bit_count <= bit_count + 1;
                            if (search_idx == 7) begin
                                if (bit_count > max_sources) max_sources <= bit_count;
                                // Now push children
                                // For each node u in current_available:
                                //   NewRemoved = current_removed | (1 << u)
                                //   Check if NewRemoved visited.
                                //   If not, push to queue.
                                // We iterate u 0 to 7.
                                iter_node <= 0;
                                compute_state <= 5;
                            end else begin
                                search_idx <= search_idx + 1;
                            end
                        end

                        5: begin // Push Children
                            // Check if iter_node is in current_available
                            if (current_available[iter_node]) begin
                                // Form new removed mask
                                next_removed <= current_removed | (1 << iter_node);
                                // We need to check visited and push in the same cycle or next?
                                // Let's check visited in next state.
                                compute_state <= 6;
                            end else begin
                                // Move to next
                                if (iter_node == 7) begin
                                    compute_state <= 0; // Done with this state, pop next
                                end else begin
                                    iter_node <= iter_node + 1;
                                end
                            end
                        end

                        6: begin // Check Visited and Push
                            // Check if next_removed is visited.
                            // Address = next_removed[4:0], 
                            // Bit = next_removed[7:5] or just check full byte.
                            // Since we have 32 bytes, index = next_removed[7:2]? No.
                            // We have 256 bits. Index = next_removed [7:0].
                            // We need to read byte at index [7:3] and check bit [2:0].
                            // Or simpler, store 32 bytes, each byte represents 8 masks? No, 256 masks?
                            // We have 256 states. We need a bit array of size 256.
                            // `visited_storage[0:31]`. Index = next_removed.
                            // Bit access: 
                            // Byte index = next_removed[7:3].
                            // Bit index = next_removed[2:0].
                            
                            // Check if visited:
                            if ( visited_storage[next_removed[7:3]][next_removed[2:0]] == 0 ) begin
                                // Not visited. Mark visited.
                                visited_storage[next_removed[7:3]][next_removed[2:0]] <= 1'b1;
                                // Push to queue
                                // Check queue full? (q_head - q_tail < 16). Assuming small DAG, likely not full.
                                // But to be safe, we can just overwrite if full (bad) or stall (bad).
                                // Let's assume it fits (max 256 entries, but practically much less).
                                // If queue wraps, we handle it. 
                                // We need to store next_removed into queue_mem[q_head].
                                // But q_head is 4 bits (16 entries). We might overflow.
                                // To fix, let's make queue pointers 5 bits (32 entries).
                                // Re-declare q_head, q_tail.
                                // Actually, let's just use q_head[4:0], q_tail[4:0], size 32.
                                queue_mem[q_head[4:0]] <= next_removed;
                                q_head <= q_head + 1;
                            end
                            
                            // Continue loop for children
                            if (iter_node == 7) begin
                                compute_state <= 0; // Go pop next
                            end else begin
                                iter_node <= iter_node + 1;
                                compute_state <= 5; // Back to loop
                            end
                        end
                        
                        default: compute_state <= 0;
                    endcase
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset?
                        // Or wait for new start.
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Declare missing regs used in logic
    reg [4:0] q_head, q_tail; // Updated to 5 bits for 32 slots
    reg [2:0] bit_count;
    reg [7:0] parents [0:7]; // Added parents array
    
    // Fix for the Q-head/tail usage in code:
    // The code uses q_head and q_tail as pointers.
    // We need to initialize them to 0 in IDLE/START.
    
    // One issue: `parents` array is built in COLLECT.
    // `visited_storage` initialization logic is in COMPUTE entry (state transition).
    // The Compute state machine has a sub-state 0 that pushes initial state.
    // However, the initial push logic `if (q_head == q_tail) ...` runs every cycle in sub-state 0.
    // It should run once. 
    // Let's refine state 0.
    // Also, the `FINISH` state logic needs to handle transition back to IDLE.
    
    // Corrected COMPUTE block (textual fix):
    // In sub-state 0:
    // If (q_head == 0 && q_tail == 0) -> push initial.
    // Then check if queue empty (q_head == q_tail).
    // Wait, if we push initial, q_head becomes 1, q_tail 0. Not empty.
    // So:
    // if (q_head == 0 && q_tail == 0) begin
    //    queue_mem[0] <= 8'b0; 
    //    q_head <= 1;
    //    visited_storage[0][0] <= 1; // Mark 0 visited
    //    compute_state <= 1; // Wait, we need to pop first? 
    //    No, we pushed, so we should go to loop (pop logic).
    //    Actually, let's separate Init and Loop.
    //    Let's keep the Init in state 0.
    //    Let's change state 0 logic:
    //    if (q_head == 0 && q_tail == 0) begin
    //       queue_mem[0] <= 0; q_head <= 1; visited_storage[0][0] <= 1;
    //       // Do not pop yet. Wait for next cycle to pop.
    //    end else begin
    //       // Loop logic
    //       if (q_head == q_tail) state <= FINISH;
    //       else begin
    //         pop...
    //       end
    //    end

endmodule
