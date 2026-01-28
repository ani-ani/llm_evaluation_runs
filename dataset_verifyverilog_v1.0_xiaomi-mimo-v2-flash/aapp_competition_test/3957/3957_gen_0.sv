module pairing_distance(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] univ_mask,
    input [63:0] edge_src,
    input [63:0] edge_dst,
    input [3:0] num_edges,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] BUILD_ADJ   = 3'd1;
    localparam [2:0] DFS_ORDER   = 3'd2;
    localparam [2:0] POST_PROCESS = 3'd3;
    localparam [2:0] DONE_STATE  = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] adj_idx [15:0];      // Adjacency list start index for each node
    reg [3:0] adj_end [15:0];      // Adjacency list end index + 1
    reg [3:0] adj_list [30:0];     // Adjacency list storage (max 30 entries for 16 nodes)
    reg [3:0] parent [15:0];       // Parent pointers from DFS
    reg [3:0] order [15:0];        // Processing order (post-order)
    reg [3:0] univ_cnt [15:0];     // University count per subtree
    reg [3:0] i, j, edge_pos, node, child, stack_ptr, order_idx, dfs_node;
    reg [15:0] total_sum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Temporary registers for DFS
    reg [15:0] stack;
    reg [15:0] visited;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = BUILD_ADJ;
            BUILD_ADJ: if (edge_pos >= num_edges) next_state = DFS_ORDER;
            DFS_ORDER: if (stack_ptr == 4'd0) next_state = POST_PROCESS;
            POST_PROCESS: if (order_idx >= n) next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition and output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                adj_idx[i] <= 4'd0;
                adj_end[i] <= 4'd0;
                parent[i] <= 4'd15;
                order[i] <= 4'd0;
                univ_cnt[i] <= 4'd0;
            end
            for (j = 0; j < 31; j = j + 1) begin
                adj_list[j] <= 4'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            edge_pos <= 4'd0;
            node <= 4'd0;
            child <= 4'd0;
            stack_ptr <= 4'd0;
            order_idx <= 4'd0;
            dfs_node <= 4'd0;
            total_sum <= 16'd0;
            stack <= 16'd0;
            visited <= 16'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            done <= 1'b0;
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    total_sum <= 16'd0;
                    // Reset tracking variables
                    i <= 4'd0;
                    j <= 4'd0;
                    edge_pos <= 4'd0;
                    node <= 4'd0;
                    child <= 4'd0;
                    stack_ptr <= 4'd0;
                    order_idx <= 4'd0;
                    dfs_node <= 4'd0;
                    stack <= 16'd0;
                    visited <= 16'd0;
                    // Reset arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        adj_idx[i] <= 4'd0;
                        adj_end[i] <= 4'd0;
                        parent[i] <= 4'd15;
                        univ_cnt[i] <= 4'd0;
                    end
                    for (j = 0; j < 31; j = j + 1) begin
                        adj_list[j] <= 4'd0;
                    end
                end

                BUILD_ADJ: begin
                    // Build adjacency list from edge_src and edge_dst
                    // Each edge is 16 bits: {dst[3:0], src[3:0]} repeated 4 times
                    // edge_src: [7:4] is edge 0 src, [3:0] is edge 0 dst? No, spec says edge_src stores sources
                    // Reading: edge_src[63:0] stores source nodes of edges (4 edges x 16 bits each)
                    // So edge_src[15:12] = source of edge 0, edge_src[11:8] = source of edge 1, etc.
                    // Wait, spec says: "edge_src[63:0]: 64-bit array (4 edges x 16 bits each)"
                    // Means 64 bits / 16 bits per edge = 4 edges. But edges can be more.
                    // Actually: 4 edges * 16 bits each = 64 bits. So each edge is 16 bits.
                    // For edge k: src is edge_src[k*4+3:k*4], dst is edge_dst[k*4+3:k*4]
                    // But 64 bits / 4 bits per node index = 16 positions.
                    // Let's assume edge_src[63:0] means 16 4-bit fields for 16 possible edges.
                    // edge_src[3:0] is src of edge 0, edge_src[7:4] is src of edge 1, etc.
                    // Same for edge_dst.
                    
                    if (edge_pos < num_edges) begin
                        // Extract source and destination for current edge
                        // edge_pos gives edge index, need to shift accordingly
                        // Since each node index is 4 bits, shift by edge_pos * 4
                        reg [3:0] src = edge_src[edge_pos*4 +: 4];
                        reg [3:0] dst = edge_dst[edge_pos*4 +: 4];
                        
                        // Add dst to adj_list of src
                        if (adj_end[src] < 4'd15) begin
                            adj_list[adj_end[src]] <= dst;
                            adj_end[src] <= adj_end[src] + 4'd1;
                        end
                        // Add src to adj_list of dst (undirected tree)
                        if (adj_end[dst] < 4'd15) begin
                            adj_list[adj_end[dst]] <= src;
                            adj_end[dst] <= adj_end[dst] + 4'd1;
                        end
                        
                        edge_pos <= edge_pos + 4'd1;
                    end
                end

                DFS_ORDER: begin
                    // Iterative DFS from root (node 0) to get post-order
                    // Stack contains nodes to visit, also track if children are processed
                    // Use a simple DFS: push children, when popping, add to order
                    // To simplify, we do: visit node, push children (unvisited), record order when popped
                    // But we need post-order. Use a flag to track if node's children processed.
                    // With 16 nodes, we can just process linearly.
                    // Alternative: Pre-order traversal, then process in reverse order.
                    // Pre-order: visit node, then children.
                    // Reverse pre-order is close to post-order for trees.
                    
                    // Let's implement explicit stack DFS for post-order
                    // Stack stores: {node, child_index}
                    // We use stack_ptr to track stack depth
                    // stack is 16 bits, we use it as bit mask for visited
                    
                    if (stack_ptr == 4'd0) begin
                        // Start DFS: push root (0)
                        // We need a stack array, but we don't have dynamic arrays.
                        // Let's use the order array as stack, and track position.
                        // Simpler: recursion simulation.
                        // We need a stack to store {node, next_child_idx}
                        // Let's use a separate array for stack: reg [7:0] dfs_stack[16];
                        // To save registers, we can use a different approach.
                        // Since n <= 16, we can use a state per node.
                        // Let's use a simpler iterative method:
                        // 1. Set parent of root to self or invalid.
                        // 2. Visit nodes in BFS order to get level order, then process reverse.
                        // For trees, reverse BFS gives a valid post-order-like processing.
                        // Actually, just process nodes in reverse order of indices (15 down to 0)
                        // But that's not topological.
                        // Correct way: Build parent array using a queue.
                        // Queue simulation with array.
                        // Let's use the parent array to track visited.
                        // Start with node 0.
                        
                        // Initialize: parent[0] = 0 (or 15 if invalid)
                        // visited bit 0 = 1
                        // queue: head=0, tail=1, queue[0]=0
                        // We don't have dynamic queue, so we use iterative scan.
                        // Standard BFS queue: reg [3:0] queue[16];
                        // We need to declare it.
                    end
                    
                    // To save complexity, we assume the tree is given and connected.
                    // We can simply set parent for all nodes based on edge direction away from root.
                    // Since we have adjacency list, we can do:
                    // Parent of root (0) = 15 (invalid).
                    // For every other node, parent is the neighbor that is closer to root.
                    // Since we don't have distances, we use DFS/BFS.
                    
                    // Implementing simple stack DFS:
                    // We need a stack storage. Let's use 'order' as stack temporarily.
                    // And 'parent' as visited flag.
                    
                    if (dfs_node < n) begin
                        // This part is tricky without arrays.
                        // Let's use a different approach for DFS order.
                        // Since the tree is connected, we can just traverse.
                        // We will use a recursive-like state machine.
                        // But for Icarus Verilog, simple loops are better.
                        
                        // Let's reset parent array for DFS
                        if (dfs_node == 4'd0) begin
                            parent[0] <= 4'd0; // Root parent is 0
                            visited <= 16'b1;
                            stack_ptr <= 4'd1;
                            order[0] <= 4'd0; // Push root to stack
                        end else begin
                            // Process stack
                            if (stack_ptr > 4'd0) begin
                                reg [3:0] curr = order[stack_ptr - 4'd1]; // Peek
                                // Find unvisited child
                                reg [3:0] start_idx = adj_idx[curr];
                                reg [3:0] end_idx = adj_end[curr];
                                reg found_child = 1'b0;
                                reg [3:0] next_child;
                                
                                for (int c = 0; c < 16; c = c + 1) begin
                                    // This loop is synthesis-friendly if limited
                                    // Actually, we need to iterate adj_list
                                end
                                
                                // Manual iteration for 'i'
                                if (i < adj_end[curr]) begin
                                    reg [3:0] neighbor = adj_list[curr * 2 +: 4]; // Adjacency list access issue
                                    // Adjacency list is flat, adj_idx[curr] points to start
                                    // Access: adj_list[adj_idx[curr] + i]
                                    reg [3:0] neighbor_node = adj_list[adj_idx[curr] + i];
                                    if (!visited[neighbor_node]) begin
                                        visited[neighbor_node] <= 1'b1;
                                        parent[neighbor_node] <= curr;
                                        // Push to stack
                                        order[stack_ptr] <= neighbor_node;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        i <= 4'd0; // Reset child iterator for new node
                                        found_child = 1'b1;
                                    end
                                    i <= i + 4'd1;
                                end
                                
                                if (!found_child && i >= adj_end[curr]) begin
                                    // No more children, pop and record in post-order
                                    // We need a separate post-order array
                                    // Let's use univ_cnt as temp stack for order?
                                    // No, use 'order' array itself, but we need to write to another position.
                                    // Let's use 'j' as post-order index.
                                    // Pop means: stack_ptr--, record to post_order[j++]
                                    reg [3:0] popped = order[stack_ptr - 4'd1];
                                    stack_ptr <= stack_ptr - 4'd1;
                                    // We need a post_order array. Let's reuse 'order' array but from the end?
                                    // No, let's declare a separate array or use one.
                                    // Let's use 'order' for pre-order (stack), and 'parent' for post-order? No.
                                    // Let's use 'univ_cnt' array temporarily to store post-order.
                                    // univ_cnt[post_idx] = popped_node
                                    univ_cnt[j] <= popped;
                                    j <= j + 4'd1;
                                    i <= 4'd0; // Reset for new top of stack
                                end
                            end
                        end
                        
                        // Increment dfs_node only when stack is empty
                        if (stack_ptr == 4'd0 && dfs_node < n) begin
                            // Actually we just run until stack empty once.
                            // The loop condition handles it.
                        end
                    end
                    
                    // Correction: The above logic is complex. 
                    // Let's just run DFS until stack empty.
                    // The 'DFS_ORDER' state should loop until stack_ptr == 0.
                    // We don't need a separate counter for DFS.
                    
                    // We need to restructure DFS logic.
                    // Start with stack empty? No, push 0 at start.
                    // If stack not empty:
                    //   curr = stack[top]
                    //   if curr has unvisited child:
                    //       push child
                    //   else:
                    //       pop curr, add to post_order
                    // 
                    // We need to track "next child to check" for each node on stack.
                    // Let's use 'order' array to store stack nodes.
                    // And 'parent' array to store next child index for stack nodes? No.
                    // Let's use a separate array: 'dfs_idx[16]' to store next child index for each node.
                    // Since we only need it for nodes on stack, we can store it in 'order' (the stack itself) with high bits?
                    // 4 bits for node, 4 bits for child index = 8 bits. 'order' is 4 bits.
                    // We can use 'adj_idx' to store the next child index temporarily during DFS.
                    // 
                    // Simpler: Recursive DFS is hard. Iterative is hard without arrays.
                    // Let's use a different post-order generation.
                    // Since it's a tree, we can compute "depth" or just traverse.
                    // But we need to process children before parent.
                    // 
                    // Let's assume the input edges are ordered or we can sort them.
                    // For simplicity in this limited environment, let's use a specific DFS strategy.
                    // We will use 'i' as current node, 'j' as state.
                    // State 0: Initialize root.
                    // State 1: Loop.
                    // 
                    // Actually, let's just use 'order' as the post-order array directly.
                    // We need a stack. Let's use 'stack' (16 bits) as a bitmask for the path? No.
                    // Let's use 'adj_end' as stack storage. It's 16 elements of 4 bits.
                    // We can use 'adj_end' to store the stack content (nodes).
                    // And 'adj_idx' to store the stack pointer (since adj_idx[0] is free).
                    // 
                    // Revised DFS Plan:
                    // Use 'adj_end' as stack storage (push nodes here).
                    // Use 'adj_idx[15]' as stack pointer.
                    // Use 'parent' array to mark visited.
                    // Use 'order' to store post-order.
                    // 
                    // Start: push 0 to stack. parent[0] = 0. visited[0] = 1.
                    // Loop:
                    //   If stack empty: break.
                    //   curr = stack[sp-1].
                    //   Find unvisited child in adj_list[curr].
                    //   If found: push child, mark visited.
                    //   Else: pop curr, order[post_idx++] = curr.
                    // 
                    // We need to store "next child index to check" for each node on stack.
                    // We can use 'univ_cnt' array for that. univ_cnt[node] stores next child index.
                    // Since we haven't computed univ_cnt yet, we can reuse it.
                    // 
                    // Let's implement this step-by-step.
                    
                    // We'll use 'stack_ptr' (which we declared) and 'order' (which we declared as order).
                    // We need a separate post-order array. Let's use 'univ_cnt' to store the post-order traversal.
                    // 'univ_cnt' will hold the node indices in post-order.
                    // 'parent' array holds visited flags (1 if visited).
                    // 'adj_idx' array will hold the next child index to process for each node.
                    
                    if (stack_ptr == 4'd0 && !visited[4'd0]) begin
                        // Initialize DFS
                        stack_ptr <= 4'd1;
                        order[0] <= 4'd0; // Stack storage in 'order' for now
                        parent[0] <= 4'd1; // Mark visited (non-zero means visited)
                        adj_idx[0] <= 4'd0; // Next child index for node 0
                        order_idx <= 4'd0; // Post-order index
                    end else if (stack_ptr > 4'd0) begin
                        reg [3:0] curr = order[stack_ptr - 4'd1];
                        reg [3:0] next_child_idx = adj_idx[curr];
                        reg [3:0] child_node;
                        reg child_found = 1'b0;
                        
                        // Check if there are more children to visit
                        if (next_child_idx < adj_end[curr]) begin
                            child_node = adj_list[adj_idx[curr] * 2 +: 4]; // Hacky access
                            // Need to access adj_list correctly. adj_list is flat array of 4-bit values.
                            // adj_idx[curr] gives index in adj_list.
                            // We need to access adj_list[adj_idx[curr]].
                            // But adj_idx[curr] is 4 bits, adj_list is 31 elements.
                            // We need to use a reg to hold the value.
                            // Since we are in always block, we can't declare new variable inside always.
                            // We need to use a temporary variable declared at top.
                            // Let's use 'child' as temporary.
                            child <= adj_list[next_child_idx];
                            
                            if (parent[child] == 4'd0) begin // Not visited (parent 0 means unvisited, root has parent 0 but we set it to 1)
                                // Wait, root parent is 0. We need different marker.
                                // Let's set visited nodes parent to 15 (invalid).
                                // Init: parent[i] = 15. Root visited: parent[0] = 0.
                                // Check: if (parent[child_node] == 15) then unvisited.
                            end
                            
                            // Correction: visited check
                            // We initialized parent to 4'd15 in IDLE.
                            // Root is 0, parent[0] = 15. Start DFS: parent[0] = 0.
                            // Unvisited nodes have parent == 15.
                            
                            child_node = adj_list[next_child_idx];
                            if (parent[child_node] == 4'd15) begin
                                // Found unvisited child
                                child_found = 1'b1;
                                parent[child_node] <= curr; // Set parent
                                adj_idx[child_node] <= 4'd0; // Reset child index for new node
                                // Push to stack
                                order[stack_ptr] <= child_node;
                                stack_ptr <= stack_ptr + 4'd1;
                            end
                            // Increment child index for current node
                            adj_idx[curr] <= next_child_idx + 4'd1;
                        end
                        
                        if (!child_found && next_child_idx >= adj_end[curr]) begin
                            // No more children, pop and add to post-order
                            // 'univ_cnt' will store post-order
                            univ_cnt[order_idx] <= curr;
                            order_idx <= order_idx + 4'd1;
                            stack_ptr <= stack_ptr - 4'd1;
                        end
                    end
                end

                POST_PROCESS: begin
                    // Process nodes in post-order (stored in univ_cnt[0] to univ_cnt[n-1])
                    // But wait, we used univ_cnt to store post-order.
                    // We need a separate array for university counts.
                    // Let's use 'order' array to store university counts.
                    // 'order' is 4 bits per element, enough for count (max 16).
                    // Wait, univ_cnt was used for post-order.
                    // Let's swap: 'univ_cnt' will store the university count per node.
                    // 'order' was used as stack storage and will be overwritten.
                    // We need to store post-order somewhere.
                    // Let's use 'parent' array to store post-order temporarily? No, parent is needed.
                    // 
                    // Let's redefine usage:
                    // 'adj_idx': during DFS, used as next child index. Post-DFS, free.
                    // 'adj_end': free.
                    // 'stack_ptr': free.
                    // 'order_idx': free.
                    // 
                    // We need to store post-order traversal.
                    // Let's use 'order' array for post-order (node indices).
                    // Let's use 'univ_cnt' array for university counts.
                    // During DFS (state 2), we stored post-order in 'univ_cnt' (bad naming).
                    // Let's fix: during DFS, store post-order in 'order'.
                    // And use 'univ_cnt' for counts.
                    // But 'order' was used as stack.
                    // We need to copy 'order' (stack content) to 'order' (post-order) is not possible.
                    // Let's use 'parent' to store post-order? No.
                    // 
                    // Let's use 'order' as the post-order result array.
                    // During DFS, we need a stack. Let's use 'adj_end' as stack (since it's 4-bit array of 16).
                    // And 'adj_idx' as stack pointer.
                    // 
                    // Revised plan for State 2 (DFS):
                    // Stack: stored in 'adj_end' (16 elements).
                    // Stack pointer: 'adj_idx[15]' (or a separate register).
                    // Post-order: stored in 'order' (16 elements).
                    // Next child index for node: stored in 'parent' array (we can reuse parent temporarily as "next index").
                    // Visited: stored in 'univ_cnt' array (mark with 255).
                    // 
                    // Let's simplify drastically. 
                    // Since we have < 256 cycles, and n <= 16, we can do a naive traversal.
                    // We don't strictly need a perfect post-order if we iterate enough times.
                    // We can accumulate counts repeatedly until stable.
                    // 
                    // Let's stick to the plan but optimize storage.
                    // State 2: 
                    // Use 'adj_end' as stack. 'adj_idx[0]' as stack ptr.
                    // Use 'order' to store post-order.
                    // Use 'parent' as next child index for nodes.
                    // Use 'univ_cnt' as visited flag (1 if visited).
                    
                    // If stack is empty:
                    //   Push 0. visited[0]=1. next_child[0]=0.
                    // If stack not empty:
                    //   curr = stack[sp-1].
                    //   If next_child[curr] < adj_end[curr]:
                    //       child = adj_list[next_child[curr]].
                    //       If !visited[child]:
                    //           Push child. visited[child]=1. next_child[child]=0.
                    //       Increment next_child[curr].
                    //   Else:
                    //       Pop curr. order[post_idx++] = curr.
                    //       post_idx stored in 'stack_ptr' (free) or 'i'.
                    // 
                    // Let's use 'i' as post_idx.
                    // Let's use 'j' as stack_ptr (since adj_idx[0] is free, but we need array).
                    // Let's use 'adj_idx[15]' as stack_ptr.
                    
                    if (adj_idx[15] == 4'd0 && !univ_cnt[4'd0]) begin
                        // Initialize
                        adj_idx[15] <= 4'd1; // Stack ptr = 1
                        adj_end[0] <= 4'd0; // Stack[0] = 0 (use adj_end as stack)
                        univ_cnt[0] <= 4'd1; // Visited flag
                        parent[0] <= 4'd0; // Next child index
                        i <= 4'd0; // Post-order index
                    end else if (adj_idx[15] > 4'd0) begin
                        reg [3:0] curr = adj_end[adj_idx[15] - 4'd1];
                        reg [3:0] next_child = parent[curr];
                        
                        if (next_child < adj_end[curr]) begin
                            reg [3:0] child_node = adj_list[next_child];
                            if (!univ_cnt[child_node]) begin
                                // Push child
                                adj_end[adj_idx[15]] <= child_node;
                                adj_idx[15] <= adj_idx[15] + 4'd1;
                                parent[child_node] <= 4'd0;
                                univ_cnt[child_node] <= 4'd1;
                            end
                            parent[curr] <= next_child + 4'd1;
                        end else begin
                            // Pop
                            order[i] <= curr;
                            i <= i + 4'd1;
                            adj_idx[15] <= adj_idx[15] - 4'd1;
                        end
                    end
                    
                    // Process post-order nodes for university count
                    // We process one node per cycle in POST_PROCESS state.
                    // We need to know when we are done.
                    // 'i' holds the number of nodes in post-order.
                    // 'j' will be used to iterate through them.
                    // If we finished DFS, i == n.
                    // Then we process j from 0 to n-1.
                    // Wait, if we process in the same state, we need to differentiate.
                    // Let's add a sub-state or use 'j' as iterator.
                    // We can check if DFS is done (adj_idx[15] == 0 and i == n).
                    // Actually, once i == n, we are ready for computation.
                    // 
                    // Let's separate the loop.
                    // If i < n: still doing DFS.
                    // If i == n: doing calculation.
                    // We can use 'j' as the calculation iterator.
                    // 
                    // If i < n:
                    //   Do DFS steps above.
                    // If i == n and j < n:
                    //   Process node order[j].
                    //   node = order[j].
                    //   count = 1 if univ[node] else 0.
                    //   sum children counts (from univ_cnt array).
                    //   univ_cnt[node] = total count.
                    //   contribution = min(count, 2*k - count). (Only if node != 0)
                    //   total_sum += contribution.
                    //   j++.
                    // 
                    // We need to store children counts. We overwrote univ_cnt with visited flags.
                    // This is getting messy with register reuse.
                    // 
                    // Let's dedicate registers properly.
                    // 'univ_cnt' array: will store the final university count per node.
                    // 'parent' array: during DFS, stores next child index.
                    // 'order' array: stores post-order traversal.
                    // 'adj_end': used as stack during DFS.
                    // 'adj_idx[15]': stack pointer.
                    // 'i': post-order index (or done flag).
                    // 'j': iterator for post-process.
                    // 'k_reg': stores 2*k.
                    // 
                    // Phase 1: DFS to get order.
                    // Phase 2: Process order.
                    // 
                    // Let's use 'k' (input) directly, but 2*k might be needed. Let's store in 'k_reg' (reuse 'i' if not used?).
                    // Let's use 'k' as is.
                    // 
                    // Reset 'univ_cnt' array to 0 first.
                    // Use 'j' to reset.
                    // If j < n: univ_cnt[j] <= 0; j++.
                    // If j == n: j <= 0; (go to DFS).
                    // 
                    // Refined POST_PROCESS logic:
                    // Part A: Init univ_cnt to 0.
                    // Part B: DFS.
                    // Part C: Accumulate.
                    // 
                    // Actually, we can combine DFS and accumulation.
                    // When we pop a node (post-order), we can immediately calculate its count.
                    // But we need to read children's counts.
                    // Since we pop children before parents, children's counts are ready in 'univ_cnt'.
                    // So we can do it during the DFS pop phase.
                    // 
                    // Let's reorganize POST_PROCESS state.
                    // We will run a loop until all nodes processed.
                    // 
                    // Let's use 'j' as the state machine control.
                    // j=0: Reset univ_cnt array.
                    // j=1: DFS loop.
                    // j=2: Done.
                    // 
                    // But we need to store post-order to process for contribution.
                    // Actually, during DFS pop:
                    //   count = (univ_mask >> node) & 1 ? 1 : 0.
                    //   for each child of node:
                    //       count += univ_cnt[child].
                    //   univ_cnt[node] = count.
                    //   If node != 0: total_sum += min(count, 2k - count).
                    //   (We need adjacency list to know children).
                    //   
                    //   To know children, we need to iterate adj_list[node].
                    //   If adj_list[node][i] == parent[node], skip.
                    //   Else it's a child.
                    // 
                    // This requires parent array.
                    // During DFS (push), we set parent[child] = curr.
                    // During pop, we know curr.
                    // We need to iterate adj_list[curr] to find children.
                    // 
                    // This is getting complex for one state.
                    // Let's use multiple states or sub-states.
                    // 
                    // Let's stick to the original plan: separate DFS and Accumulation.
                    // DFS State: Store post-order in 'order' array.
                    // Accumulate State: Iterate 'order' array, compute counts, sum.
                    // 
                    // We need to fix the DFS storage conflict.
                    // 
                    // Final Storage Plan:
                    // - adj_list[30:0]: 4-bit nodes. (Fixed)
                    // - adj_idx[15:0]: start index for each node's list. (Fixed)
                    // - adj_end[15:0]: end index (exclusive). (Fixed)
                    // - parent[15:0]: used for DFS parent tracking AND next child index.
                    //   - During DFS: parent[node] stores next child index to check.
                    //   - After DFS: parent[node] stores the actual parent (or we don't need it if we iterate adj_list).
                    //   - To save registers, we can store parent in a bit-packed way or just use it.
                    //   - We need actual parent to identify children in accumulation phase.
                    //   - So let's use 'parent' for actual parent. 
                    //   - We need another array for next child index during DFS.
                    //   - Let's use 'univ_cnt' array for next child index during DFS.
                    //   - And 'order' for post-order.
                    //   - 'adj_end' for stack.
                    //   - 'adj_idx' for stack pointer.
                    // 
                    // Revised DFS (in POST_PROCESS state):
                    //   - Stack: 'adj_end' (16 slots).
                    //   - Stack ptr: 'adj_idx[15]' (since adj_idx is 16x4 bits, we use the last element for ptr).
                    //   - Next child index: 'univ_cnt[node]'.
                    //   - Parent: 'parent[node]'.
                    //   - Post-order: 'order' array.
                    //   - Post-order index: 'i'.
                    // 
                    // Steps in POST_PROCESS:
                    //   1. Reset 'univ_cnt' (next child index) to 0 for all.
                    //      Use 'j' as counter. If j < n: univ_cnt[j] = 0; j++. Else go to step 2.
                    //   2. DFS Loop.
                    //      If stack empty and not visited 0: Push 0. parent[0] = 0 (or 15). Mark visited (parent[0] = 0 is valid for root).
                    //      If stack not empty:
                    //        curr = stack[sp-1].
                    //        If univ_cnt[curr] < adj_end[curr]:
                    //          child = adj_list[univ_cnt[curr]].
                    //          If child != parent[curr] (and for root, parent is 0, so check child != 0):
                    //             Actually, standard DFS: mark visited. 
                    //             We need a visited array. Let's use 'order' array to mark visited? No.
                    //             Let's use 'parent' array. parent[node] = actual parent. 
                    //             When pushing child: parent[child] = curr.
                    //             When looking at neighbor: if neighbor == parent[curr] skip.
                    //             
                    //             We need to check if 'child' is the parent of 'curr'.
                    //             If curr == 0: no parent.
                    //             
                    //             Logic:
                    //             child = adj_list[univ_cnt[curr]]
                    //             if (curr == 0) {
                    //                 if (child has parent set (i.e. visited)) skip
                    //                 else push.
                    //             } else {
                    //                 if (child == parent[curr]) skip
                    //                 else push.
                    //             }
                    //             
                    //             To check if visited: parent[child] != 0 (except root).
                    //             Let's initialize parent array to 15 (invalid).
                    //             Root: parent[0] = 0. 
                    //             When checking child:
                    //               if (parent[child] != 15) visited.
                    //               
                    //             Push logic:
                    //               if (parent[child] == 15) {
                    //                 parent[child] = curr;
                    //                 push child.
                    //               }
                    //             Increment univ_cnt[curr] (next child index).
                    //        Else (no more children):
                    //          Pop curr.
                    //          order[i++] = curr.
                    //          
                    //   3. Accumulate.
                    //      Loop j from 0 to n-1 (using 'j').
                    //      curr = order[j].
                    //      count = (univ_mask >> curr) & 1 ? 1 : 0.
                    //      For each neighbor in adj_list[curr]:
                    //         If neighbor == parent[curr]: skip.
                    //         Else: count += univ_cnt[neighbor]. (Note: univ_cnt was used for next child index, but now DFS is done. We can reuse 'univ_cnt' to store the subtree counts!)
                    //      Store count in univ_cnt[curr].
                    //      If curr != 0:
                    //         contribution = min(count, 2k - count).
                    //         total_sum += contribution.
                    //      
                    //      This requires iterating adj_list again. 
                    //      We can do this in the same state, using 'i' for the inner loop.
                    //      
                    //      This is getting complex for a single always block.
                    //      Let's split into sub-states or use multi-cycle operations.
                    //      
                    //      We will use 'j' to track the main phase.
                    //      j = 0..2: phases.
                    //      
                    //      Phase 0 (Reset): Init univ_cnt to 0.
                    //      Phase 1 (DFS): Run DFS.
                    //      Phase 2 (Accumulate): Run accumulation.
                    //      
                    //      Inside Phase 1 (DFS):
                    //        We need to run until stack empty.
                    //        This might take many cycles. 
                    //        We can just do 1 step per cycle.
                    //        
                    //      Inside Phase 2 (Accumulate):
                    //        Loop j from 0 to n-1.
                    //        For each j, we need to scan adj_list.
                    //        Inner loop: i from 0 to adj_end[curr].
                    //        
                    //      To avoid nested loops in Verilog (hard to code in one block),
                    //      we can linearize.
                    //      
                    //      Let's use 'i' as the "action pointer".
                    //      We can just process nodes in order 0 to n-1.
                    //      But we need post-order.
                    //      
                    //      Let's just use the 'order' array filled by DFS.
                    //      
                    //      Let's implement the DFS carefully.
                    
                    // START OF POST_PROCESS LOGIC
                    
                    // We will use 'i' as the accumulator for total_sum.
                    // We will use 'j' as the phase/state selector.
                    // j=0: Init arrays.
                    // j=1: DFS traversal.
                    // j=2: Compute counts and contributions.
                    // j=3: Finish.
                    
                    // Phase 0: Init
                    if (j == 4'd0) begin
                        if (i < n) begin
                            univ_cnt[i] <= 4'd0; // Clear univ_cnt (reuse for next child index)
                            parent[i] <= 4'd15;  // Mark unvisited
                            i <= i + 4'd1;
                        end else begin
                            i <= 4'd0;
                            j <= 4'd1;
                            // Initialize DFS root
                            stack_ptr <= 4'd1;
                            adj_end[0] <= 4'd0; // Stack[0] = 0 (reusing adj_end as stack)
                            parent[0] <= 4'd0;  // Root parent = 0
                            // Note: we need to differentiate "visited" from "parent=0".
                            // Let's set parent[0] = 0. Unvisited = 15.
                            // Visited nodes have parent != 15.
                            // When checking child, if parent[child] != 15, skip.
                        end
                    end
                    
                    // Phase 1: DFS
                    else if (j == 4'd1) begin
                        if (stack_ptr > 4'd0) begin
                            reg [3:0] curr = adj_end[stack_ptr - 4'd1];
                            reg [3:0] next_child = univ_cnt[curr];
                            
                            if (next_child < adj_end[curr]) begin
                                // Check child
                                reg [3:0] child_node = adj_list[adj_idx[curr] * 2 +: 4]; // Wait, adj_idx[curr] is start index.
                                // Access: adj_list[adj_idx[curr] + next_child]
                                // We need to know adj_idx[curr].
                                // adj_idx array is used for start index.
                                // We need to access it.
                                reg [3:0] child_node = adj_list[adj_idx[curr] + next_child];
                                
                                // Check if visited (parent != 15)
                                if (parent[child_node] == 4'd15) begin
                                    // Visit
                                    parent[child_node] <= curr;
                                    // Push
                                    adj_end[stack_ptr] <= child_node;
                                    stack_ptr <= stack_ptr + 4'd1;
                                end
                                
                                univ_cnt[curr] <= next_child + 4'd1;
                            end else begin
                                // Pop
                                order[i] <= curr;
                                i <= i + 4'd1;
                                stack_ptr <= stack_ptr - 4'd1;
                            end
                        end else begin
                            // DFS Done
                            j <= 4'd2;
                            i <= 4'd0; // Reset i for accumulation loop
                        end
                    end
                    
                    // Phase 2: Accumulate
                    else if (j == 4'd2) begin
                        // We process nodes in post-order (order[0] to order[n-1])
                        // But we need to compute subtree counts.
                        // We can just iterate 0 to n-1 (which is post-order from DFS).
                        // For each node:
                        //   count = is_univ ? 1 : 0
                        //   for neighbor in adj_list:
                        //      if neighbor != parent[node]: count += univ_cnt[neighbor]
                        //   univ_cnt[node] = count
                        //   if node != 0: total_sum += min(count, 2k - count)
                        
                        // We need an inner loop for neighbors.
                        // Let's use 'stack_ptr' for inner loop index.
                        // 
                        // If i < n:
                        //   curr = order[i]
                        //   If stack_ptr == 0: Initialize count.
                        //     count_temp = univ_mask[curr] ? 1 : 0
                        //     stack_ptr = 1 (start iterating)
                        //   If stack_ptr <= adj_end[curr]:
                        //     neighbor = adj_list[adj_idx[curr] + stack_ptr - 1]
                        //     if neighbor != parent[curr]: count_temp += univ_cnt[neighbor]
                        //     stack_ptr++
                        //   Else: // Done with neighbors
                        //     univ_cnt[curr] = count_temp
                        //     if curr != 0: total_sum += min(count_temp, 2k - count_temp)
                        //     i++
                        //     stack_ptr = 0
                        
                        // We need a temporary register for count_temp.
                        // Let's use 'child' (which is a reg [3:0]).
                        // But count can be up to 16 (4 bits).
                        // 'child' is 4 bits, sufficient.
                        // 
                        // We also need to check univ_mask bit.
                        // univ_mask[curr] means (univ_mask >> curr) & 1.
                        // 
                        // If i < n:
                        if (i < n) begin
                            reg [3:0] curr = order[i];
                            
                            if (stack_ptr == 4'd0) begin
                                // Init count
                                child <= ((univ_mask >> curr) & 1) ? 4'd1 : 4'd0;
                                stack_ptr <= 4'd1;
                            end else if (stack_ptr <= adj_end[curr]) begin
                                // Iterate neighbors
                                reg [3:0] neighbor = adj_list[adj_idx[curr] + stack_ptr - 4'd1];
                                // Check if neighbor is parent
                                // parent[curr] is stored.
                                // For root (curr=0), parent[0] = 0.
                                // If neighbor == parent[curr], skip.
                                if (neighbor != parent[curr]) begin
                                    child <= child + univ_cnt[neighbor];
                                end
                                stack_ptr <= stack_ptr + 4'd1;
                            end else begin
                                // Done with neighbors
                                univ_cnt[curr] <= child; // Store count
                                
                                // Calculate contribution
                                if (curr != 4'd0) begin
                                    // min(child, 2k - child)
                                    // 2k = k << 1. k is 4 bits. 2k is 5 bits.
                                    // result fits in 16 bits.
                                    // We need to compute 2k.
                                    reg [4:0] two_k = {k, 1'b0}; // k * 2
                                    reg [4:0] diff = two_k - child;
                                    reg [4:0] min_val;
                                    if (child < diff) min_val = child;
                                    else min_val = diff;
                                    
                                    total_sum <= total_sum + min_val;
                                end
                                
                                i <= i + 4'd1;
                                stack_ptr <= 4'd0;
                            end
                        end else begin
                            // Done
                            result <= total_sum;
                            j <= 4'd3;
                        end
                    end
                    
                    // Phase 3: Finish
                    else if (j == 4'd3) begin
                        // Done
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Result is already set in POST_PROCESS
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
                done <= 1'b1;
                result <= 16'hFFFF;
            end
        end
    end

endmodule