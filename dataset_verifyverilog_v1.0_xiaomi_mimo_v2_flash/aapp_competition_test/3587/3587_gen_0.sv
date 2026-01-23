module TabooSolver (
    input clk,
    input rst_n,
    input config_mode,
    input config_done,
    input [3:0] num_strings,
    input [2:0] str_len [0:7],
    input [7:0] str_data [0:7],
    input start,
    output reg result_valid,
    output reg result_infinite,
    output reg [15:0] result_string,
    output reg [4:0] result_length
);

    // State definitions
    localparam [2:0] S_RESET      = 3'd0;
    localparam [2:0] S_IDLE       = 3'd1;
    localparam [2:0] S_CONFIG     = 3'd2;
    localparam [2:0] S_BUILD_TRIE = 3'd3;
    localparam [2:0] S_BUILD_FAIL = 3'd4;
    localparam [2:0] S_CHECK_CYCLE = 3'd5;
    localparam [2:0] S_COMPUTE    = 3'd6;
    localparam [2:0] S_OUTPUT     = 3'd7;

    reg [2:0] state, next_state;

    // Node structure
    localparam [4:0] MAX_NODES = 5'd32;
    reg [4:0] node_count;
    reg [4:0] next_node_idx;
    
    // Transitions: 2 children per node (for '0' and '1')
    reg [4:0] trie [0:31]; // trie[2*node + 0] = child for '0', trie[2*node + 1] = child for '1'
    reg [4:0] fail [0:31];
    reg terminal [0:31];
    
    // Input buffer
    reg [3:0] num_str_reg;
    reg [2:0] str_len_reg [0:7];
    reg [7:0] str_data_reg [0:7];
    
    // Configuration variables
    reg [3:0] str_idx;
    reg [2:0] char_idx;
    reg [4:0] curr_node;
    
    // Failure link construction
    reg [4:0] queue [0:31];
    reg [4:0] queue_head;
    reg [4:0] queue_tail;
    reg [4:0] fail_node;
    reg [1:0] fail_symbol;
    reg [4:0] fail_child;
    
    // Cycle detection variables
    reg [4:0] cycle_visited [0:31];
    reg [4:0] cycle_path_idx;
    reg [4:0] cycle_curr;
    reg [4:0] cycle_next;
    reg cycle_found;
    
    // Longest path DP variables
    reg [15:0] best_str [0:31];    // Packed string, LSB first
    reg [4:0] best_len [0:31];     // Length of best string
    reg dp_visited [0:31];         // For DFS memoization
    reg [4:0] dp_stack [0:31];     // Stack for DFS
    reg [4:0] dp_stack_ptr;
    reg [4:0] dp_curr;
    reg [4:0] dp_next;
    reg [1:0] dp_symbol;
    reg [15:0] dp_str_temp;
    reg [4:0] dp_len_temp;
    
    // Result accumulation
    reg [15:0] res_str_temp;
    reg [4:0] res_len_temp;
    reg res_inf_temp;
    reg [15:0] final_str;
    reg [4:0] final_len;
    reg final_inf;
    
    // Loop counters and flags
    integer i, j;
    reg start_compute;
    reg cycle_check_done;
    reg dp_done;
    reg [7:0] cycle_count; // Prevent infinite loops
    localparam [7:0] MAX_CYCLE = 8'd200;

    // State transition and registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RESET;
            node_count <= 5'd0;
            next_node_idx <= 5'd1;
            num_str_reg <= 4'd0;
            str_idx <= 4'd0;
            char_idx <= 3'd0;
            curr_node <= 5'd0;
            queue_head <= 5'd0;
            queue_tail <= 5'd0;
            fail_node <= 5'd0;
            fail_symbol <= 2'd0;
            fail_child <= 5'd0;
            cycle_visited[0] <= 5'd0;
            cycle_path_idx <= 5'd0;
            cycle_curr <= 5'd0;
            cycle_next <= 5'd0;
            cycle_found <= 1'b0;
            dp_stack_ptr <= 5'd0;
            dp_curr <= 5'd0;
            dp_next <= 5'd0;
            dp_symbol <= 2'd0;
            dp_str_temp <= 16'd0;
            dp_len_temp <= 5'd0;
            res_str_temp <= 16'd0;
            res_len_temp <= 5'd0;
            res_inf_temp <= 1'b0;
            final_str <= 16'd0;
            final_len <= 5'd0;
            final_inf <= 1'b0;
            start_compute <= 1'b0;
            cycle_check_done <= 1'b0;
            dp_done <= 1'b0;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            result_infinite <= 1'b0;
            result_string <= 16'd0;
            result_length <= 5'd0;
            // Initialize all nodes
            for (i = 0; i < 32; i = i + 1) begin
                trie[2*i] <= 5'd0;
                trie[2*i+1] <= 5'd0;
                fail[i] <= 5'd0;
                terminal[i] <= 1'b0;
                best_str[i] <= 16'd0;
                best_len[i] <= 5'd0;
                dp_visited[i] <= 1'b0;
                cycle_visited[i] <= 5'd0;
            end
        end else begin
            case (state)
                S_RESET: begin
                    state <= S_IDLE;
                    node_count <= 5'd0;
                    next_node_idx <= 5'd1;
                    // Re-initialize clear
                    for (i = 0; i < 32; i = i + 1) begin
                        trie[2*i] <= 5'd0;
                        trie[2*i+1] <= 5'd0;
                        fail[i] <= 5'd0;
                        terminal[i] <= 1'b0;
                        best_str[i] <= 16'd0;
                        best_len[i] <= 5'd0;
                        dp_visited[i] <= 1'b0;
                        cycle_visited[i] <= 5'd0;
                    end
                end

                S_IDLE: begin
                    result_valid <= 1'b0;
                    result_infinite <= 1'b0;
                    if (config_mode) begin
                        state <= S_CONFIG;
                        str_idx <= 4'd0;
                        str_len_reg[0] <= 3'd0;
                        str_len_reg[1] <= 3'd0;
                        str_len_reg[2] <= 3'd0;
                        str_len_reg[3] <= 3'd0;
                        str_len_reg[4] <= 3'd0;
                        str_len_reg[5] <= 3'd0;
                        str_len_reg[6] <= 3'd0;
                        str_len_reg[7] <= 3'd0;
                        str_data_reg[0] <= 8'd0;
                        str_data_reg[1] <= 8'd0;
                        str_data_reg[2] <= 8'd0;
                        str_data_reg[3] <= 8'd0;
                        str_data_reg[4] <= 8'd0;
                        str_data_reg[5] <= 8'd0;
                        str_data_reg[6] <= 8'd0;
                        str_data_reg[7] <= 8'd0;
                    end
                    if (start) begin
                        start_compute <= 1'b1;
                    end
                end

                S_CONFIG: begin
                    if (config_done) begin
                        num_str_reg <= num_strings;
                        state <= S_BUILD_TRIE;
                        node_count <= 5'd1; // Root is 0
                        next_node_idx <= 5'd1;
                        // Initialize root
                        trie[0] <= 5'd0;
                        trie[1] <= 5'd0;
                        fail[0] <= 5'd0;
                        terminal[0] <= 1'b0;
                    end else begin
                        // Latch configuration data
                        // Note: testbench provides data in parallel, we just latch it
                        // str_len and str_data arrays are inputs, handled by logic
                    end
                end

                S_BUILD_TRIE: begin
                    if (str_idx < num_str_reg) begin
                        if (char_idx < str_len_reg[str_idx]) begin
                            // Get bit
                            curr_node <= curr_node; // keep
                            if (char_idx == 3'd0) curr_node <= 5'd0; // Start at root for new string
                            // Logic moved to combinational block
                        end else begin
                            // String done
                            terminal[curr_node] <= 1'b1;
                            str_idx <= str_idx + 4'd1;
                            char_idx <= 3'd0;
                            curr_node <= 5'd0;
                        end
                    end else begin
                        // Done building trie
                        state <= S_BUILD_FAIL;
                        // Initialize BFS queue for root
                        queue[0] <= 5'd0;
                        queue_head <= 5'd1;
                        queue_tail <= 5'd0;
                        // Reset fail links for children of root
                        if (trie[0] != 5'd0) fail[trie[0]] <= 5'd0;
                        if (trie[1] != 5'd0) fail[trie[1]] <= 5'd0;
                        fail_node <= 5'd0;
                        fail_symbol <= 2'd0;
                    end
                end

                S_BUILD_FAIL: begin
                    if (queue_head != queue_tail) begin
                        // Dequeue
                        fail_node <= queue[queue_tail];
                        queue_tail <= queue_tail + 5'd1;
                        fail_symbol <= 2'd0; // Process '0' then '1'
                    end else begin
                        state <= S_CHECK_CYCLE;
                        cycle_check_done <= 1'b0;
                        cycle_found <= 1'b0;
                        cycle_path_idx <= 5'd0;
                        // Initialize cycle detection
                        for (i = 0; i < 32; i = i + 1) begin
                            cycle_visited[i] <= 5'd0;
                        end
                    end
                end

                S_CHECK_CYCLE: begin
                    if (!cycle_check_done) begin
                        // DFS logic moved to combinational
                    end else begin
                        if (cycle_found) begin
                            final_inf <= 1'b1;
                            final_str <= 16'd0;
                            final_len <= 5'd0;
                            state <= S_OUTPUT;
                        end else begin
                            // Prepare for DP
                            state <= S_COMPUTE;
                            dp_done <= 1'b0;
                            // Initialize DP
                            for (i = 0; i < 32; i = i + 1) begin
                                best_len[i] <= 5'd0;
                                best_str[i] <= 16'd0;
                                dp_visited[i] <= 1'b0;
                            end
                            // Initialize result accumulator
                            res_str_temp <= 16'd0;
                            res_len_temp <= 5'd0;
                            res_inf_temp <= 1'b0;
                            dp_stack_ptr <= 5'd0;
                            dp_curr <= 5'd0; // Start DFS from root
                        end
                    end
                end

                S_COMPUTE: begin
                    if (!dp_done) begin
                        // DP logic moved to combinational
                    end else begin
                        final_inf <= 1'b0;
                        final_str <= res_str_temp;
                        final_len <= res_len_temp;
                        state <= S_OUTPUT;
                    end
                end

                S_OUTPUT: begin
                    result_infinite <= final_inf;
                    result_string <= final_str;
                    result_length <= final_len;
                    result_valid <= 1'b1;
                    state <= S_IDLE;
                    start_compute <= 1'b0;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Combinational logic for Build Trie (Step 3)
    always @(*) begin
        if (state == S_BUILD_TRIE && str_idx < num_str_reg && char_idx < str_len_reg[str_idx]) begin
            if (char_idx == 3'd0) begin
                curr_node = 5'd0;
            end
            // Get bit: str_data[str_idx][char_idx]
            // Note: str_data is unpacked array input
            // To access: str_data[str_idx][char_idx]
            // We need to handle this carefully
            // Since str_data is unpacked, direct indexing might be tricky in always @(*)
            // But let's try standard indexing
            reg bit_val;
            bit_val = str_data[str_idx][char_idx];
            
            // Find next node
            reg [4:0] next;
            if (bit_val == 1'b0) next = trie[2*curr_node];
            else next = trie[2*curr_node + 1];
            
            if (next == 5'd0) begin
                // Create node
                next = next_node_idx;
                // Update trie mapping in sequential block
                // We can't assign to trie here directly in combinational for arrays
                // Handled by next_node_idx and logic below
            end
            // We need to return next_node_idx update to sequential
            // This is complex. Let's simplify:
            // We will use a helper register or logic to advance
        end
    end

    // Revised combinational logic for Build Trie
    // Use a single always block for transitions is hard with unpacked arrays.
    // We will use a small FSM inside S_BUILD_TRIE using additional states or counters.
    // Since the problem allows "bounded cycles", we can use a counter to sequence steps.
    
    // Alternative Approach: Use explicit wires for unpacked array access
    wire [7:0] current_str_data;
    assign current_str_data = str_data[str_idx];
    wire [2:0] current_str_len;
    assign current_str_len = str_len[str_idx];
    
    // Logic for building trie step-by-step
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled in main FSM
        end else begin
            if (state == S_BUILD_TRIE) begin
                if (str_idx < num_str_reg && char_idx < str_len_reg[str_idx]) begin
                    // Access bit
                    reg bit_val;
                    bit_val = str_data_reg[str_idx][char_idx];
                    // If we haven't latched input yet (first cycle of building), do so
                    // Actually, config_mode latched it in S_CONFIG
                    // We need to handle array access. 
                    // Since we can't easily do unpacked array access in always block logic,
                    // we will rely on the fact that inputs are stable.
                    // Let's assume we are in a sequence of cycles.
                    
                    // To avoid unpacked array issues in logic, we will 
                    // manually unroll the logic for 8 strings or use a different approach.
                    // Given constraints (8 strings, 8 bits), we can use a case statement.
                    
                    reg [4:0] next;
                    // Note: str_data is input, not reg. We can read it.
                    // But writing to trie requires seq logic.
                    
                    // Let's calculate next node
                    reg bit_val;
                    bit_val = str_data[str_idx][char_idx];
                    
                    next = trie[2*curr_node + bit_val];
                    
                    if (next == 5'd0) begin
                        next = next_node_idx;
                        // Assign to trie in seq logic? 
                        // We can't do non-blocking in combinational part.
                        // We need to store the update.
                        // Let's use a "pending_update" flag or just do it in seq logic.
                        // But seq logic sees the OLD trie value.
                        // Solution: Use a dedicated register for the "next to be written".
                        
                        // We will use `next_node_idx` to indicate the new node ID.
                        // We need to write `next_node_idx` to the correct slot in `trie`.
                        // But `trie` is an array. We can't index it with a variable in seq logic easily?
                        // Actually, we can: `trie[2*curr_node + bit_val] <= next_node_idx;`
                        // This is valid SV.
                        
                        // BUT: We need to know `curr_node` and `bit_val` for this cycle.
                        // Let's save them in temp registers.
                    end
                    
                    // Advance indices
                    // This needs to happen in seq block.
                end
            end
        end
    end
    
    // Because of the complexity of unpacked arrays and mixed logic,
    // let's create a more robust sequential implementation for Build Trie.
    // We will buffer the input strings into packed registers to avoid 
    // continuous unpacked array access in always blocks.
    
    reg [7:0] packed_str_data [0:7];
    reg [2:0] packed_str_len [0:7];
    
    // We need to handle the input latching properly.
    // In S_CONFIG, we copy inputs to internal regs.
    // But the inputs are unpacked arrays. We must read them element by element.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset
        end else begin
            if (state == S_CONFIG) begin
                // Latch inputs
                packed_str_len[0] <= str_len[0]; packed_str_data[0] <= str_data[0];
                packed_str_len[1] <= str_len[1]; packed_str_data[1] <= str_data[1];
                packed_str_len[2] <= str_len[2]; packed_str_data[2] <= str_data[2];
                packed_str_len[3] <= str_len[3]; packed_str_data[3] <= str_data[3];
                packed_str_len[4] <= str_len[4]; packed_str_data[4] <= str_data[4];
                packed_str_len[5] <= str_len[5]; packed_str_data[5] <= str_data[5];
                packed_str_len[6] <= str_len[6]; packed_str_data[6] <= str_data[6];
                packed_str_len[7] <= str_len[7]; packed_str_data[7] <= str_data[7];
                // Also latch num_strings if needed, though it's usually stable
            end
            
            // Build Trie Logic
            if (state == S_BUILD_TRIE) begin
                if (str_idx < num_str_reg) begin
                    if (char_idx < packed_str_len[str_idx]) begin
                        // Process character
                        reg bit_val;
                        bit_val = packed_str_data[str_idx][char_idx];
                        
                        // Determine next node
                        reg [4:0] child;
                        child = trie[2*curr_node + bit_val];
                        
                        if (child == 5'd0) begin
                            // Create new node
                            if (next_node_idx < MAX_NODES) begin
                                child = next_node_idx;
                                next_node_idx <= next_node_idx + 5'd1;
                                // Initialize new node
                                trie[2*child] <= 5'd0;
                                trie[2*child+1] <= 5'd0;
                                terminal[child] <= 1'b0;
                            end
                            // Update parent link
                            trie[2*curr_node + bit_val] <= child;
                        end
                        curr_node <= child;
                        char_idx <= char_idx + 3'd1;
                    end else begin
                        // String complete
                        terminal[curr_node] <= 1'b1;
                        str_idx <= str_idx + 4'd1;
                        char_idx <= 3'd0;
                        curr_node <= 5'd0;
                    end
                end
            end
            
            // Build Failure Links
            if (state == S_BUILD_FAIL) begin
                if (queue_head != queue_tail) begin
                    // If we are processing a node (fail_node is set in prev cycle or logic)
                    // Actually, we set fail_node in seq block when we pop.
                    // But we need to loop through symbols 0 and 1.
                    
                    // If fail_symbol is 0 or 1, process it
                    if (fail_symbol < 2) begin
                        reg [4:0] node;
                        node = queue[queue_tail]; // Use register or direct? 
                        // Actually, we need to process the node at queue_tail.
                        
                        reg [4:0] next;
                        next = trie[2*node + fail_symbol];
                        
                        if (next != 5'd0) begin
                            // Compute fail link for child
                            reg [4:0] f;
                            f = fail[node];
                            while (trie[2*f + fail_symbol] == 5'd0 && f != 5'd0) begin
                                f = fail[f];
                            end
                            if (trie[2*f + fail_symbol] != 5'd0) f = trie[2*f + fail_symbol];
                            
                            fail[next] <= f;
                            // If fail node is terminal, child is also terminal (or we handle it in reachability)
                            // Problem statement: "avoid terminal states"
                            // So if fail[next] is terminal, next is effectively terminal.
                            // We mark it terminal to simplify.
                            if (terminal[f]) terminal[next] <= 1'b1;
                            
                            // Enqueue child
                            queue[queue_head] <= next;
                            queue_head <= queue_head + 5'd1;
                        end
                        
                        fail_symbol <= fail_symbol + 2'd1;
                    end else begin
                        // Finished symbols for this node
                        // Advance queue is done by popping (using head/tail)
                        // Wait, we used queue_tail to index the node. 
                        // We should increment queue_tail ONLY after processing all symbols.
                        // But we used queue[queue_tail] inside. 
                        // Let's fix the pop logic.
                        // Pop happens here. We process symbols for the popped node.
                        
                        // To fix: 
                        // 1. Pop node from queue (increment tail) at start of processing? No.
                        // 2. Keep tail stationary until symbols done.
                        // 3. Wait, the logic above reads `queue[queue_tail]`. 
                        // If we don't pop, we read same node. 
                        // We need to pop at the END of processing symbols.
                        
                        // Correction for Seq Logic:
                        // We need to track if we are done with a node.
                        // Let's use fail_symbol == 2 to indicate done.
                        if (fail_symbol == 2'd2) begin
                            queue_tail <= queue_tail + 5'd1;
                            fail_symbol <= 2'd0; // Reset for next node (will be picked up next cycle)
                        end
                    end
                end
            end
            
            // Cycle Detection (DFS)
            if (state == S_CHECK_CYCLE && !cycle_check_done) begin
                // We need a DFS stack. 
                // Since we can't use dynamic recursion easily, we use a manual stack in registers.
                // However, managing a stack in seq logic is tedious.
                // Alternative: Recursive function is not synthesizable easily without care.
                // Use a simple iterative DFS with a stack stored in an array.
                
                // Let's use a simple flag `cycle_found`.
                // If we find a cycle, set it and done.
                // If we finish DFS without cycle, set done.
                
                // Since implementing full DFS in a single always block is complex,
                // let's assume we can use a "step-by-step" approach.
                // We need to traverse the graph.
                // Let's use `cycle_visited` as visited array.
                // And `cycle_path_idx` and a stack array.
                
                // Actually, for small graph (32 nodes), we can do:
                // Check for reachable non-terminal nodes.
                // Then check if any of those can reach themselves.
                
                // To simplify: 
                // We will perform a simple DFS starting from root (node 0).
                // We maintain a stack of nodes `dfs_stack[32]` and `dfs_ptr`.
                // We maintain `seen_in_path` array.
                
                // We need registers for the stack.
                reg [4:0] stack [0:31];
                reg [4:0] ptr;
                reg [4:0] curr;
                reg [4:0] next_st;
                
                // Note: We cannot declare new regs inside always block in synthesis.
                // We must use existing registers or define them outside.
                // Let's use existing `dp_stack` and `dp_stack_ptr` for this phase too.
                // And `dp_visited` for "seen in current path".
                
                // We'll use `dp_visited` as `seen_in_path`.
                // We'll use `dp_stack` as DFS stack.
                // We'll use `dp_stack_ptr` as stack pointer.
                
                // Initialization of DFS:
                // This needs to be triggered once.
                // We can use `cycle_check_done` as a "started" flag? 
                // No, we have `cycle_found`. 
                // Let's use a separate variable `dfs_started` or implicit via `dp_stack_ptr`.
                
                // Fix: Reset `dp_stack_ptr` to 0 before entering this block?
                // We did that in S_COMPUTE transition, but we are in S_CHECK_CYCLE.
                // Let's reset it when entering S_CHECK_CYCLE.
                // But `cycle_check_done` is 0 when we enter.
                
                // Logic:
                if (dp_stack_ptr == 5'd0 && !cycle_found) begin
                    // Start DFS from root if reachable (root is non-terminal usually)
                    if (!terminal[0]) begin
                        dp_stack[0] <= 5'd0;
                        dp_stack_ptr <= 5'd1;
                        dp_visited[0] <= 1'b1; // Mark as in path
                    end else begin
                        cycle_check_done <= 1'b1; // No path possible
                    end
                end else if (dp_stack_ptr != 5'd0 && !cycle_found) begin
                    // Pop
                    dp_stack_ptr <= dp_stack_ptr - 5'd1;
                    curr = dp_stack[dp_stack_ptr - 5'd1];
                    
                    // Explore neighbors
                    // We need to iterate neighbors 0 and 1.
                    // Since we can't loop easily in seq block without state,
                    // we will expand neighbors.
                    // If we find a neighbor that is in path (dp_visited == 1), cycle detected.
                    // If neighbor is non-terminal and not visited (globally), push.
                    // But we need to backtrack to restore path.
                    
                    // This is tricky. DFS with backtracking in seq logic.
                    // We need to pop and then restore visited status.
                    // Better: BFS for cycle detection? 
                    // No, DFS is natural for cycles.
                    
                    // Let's use a simpler approach for cycle detection:
                    // Just check if there is any non-terminal node reachable.
                    // And if there is a loop in the graph.
                    // A loop exists if there is a non-terminal node reachable from itself.
                    // We can run a "search for path length > N".
                    // Or just check if any node has a path back to itself.
                    
                    // Given "bounded cycles", we can check for paths of length > 32.
                    // If we can walk > 32 steps without hitting terminal, it's infinite (cycle exists).
                    // Let's do that. It's much simpler.
                    
                    // We will simulate walking.
                    // We need to track current node and current string (or just steps).
                    // Actually, we need to check ALL paths.
                    // If ANY path has a cycle, result is infinite.
                    
                    // Let's stick to DFS but optimized for seq logic.
                    // We will use `dp_visited` to mark nodes in CURRENT path.
                    // We will use `dp_stack` to store the path.
                    
                    // Wait, we popped the node. Now we process neighbors.
                    // We need to push neighbors back.
                    // BUT, we must push the CURRENT node back if we are not done.
                    // This is complex for a single always block.
                    
                    // Alternative for "bounded cycles":
                    // Run a BFS that tracks path length.
                    // If we visit a node with length >= 32, we have a cycle.
                    // Or simply: if we visit a node twice in the same traversal? No.
                    // BFS detects cycles by checking visited.
                    // But "cycle" in graph theory means reachable from itself.
                    // In automaton, a cycle is a loop of states.
                    // If we are in a state and can transition to a state we are already in.
                    // This is guaranteed if graph is strongly connected and non-terminal.
                    
                    // Let's use the DFS with stack.
                    // To make it work in seq logic:
                    // We pop a node.
                    // We check neighbors.
                    // If neighbor is in current path (dp_visited), cycle found.
                    // If neighbor is not in path and non-terminal, push neighbor.
                    // We also need to push the current node back? 
                    // No, standard DFS: explore neighbor. If not done, continue.
                    // We need to know which neighbors we have already processed.
                    // Let's add a counter `dp_symbol` to track 0 or 1.
                    
                    // Let's restart the DFS logic in the block.
                end
                
                // Correct DFS implementation for Cycle Check:
                // We need to store the "next child to explore" for each node on stack.
                // Let's use `dp_visited` as `in_path`. 
                // Let's use `dp_len_temp` to store the child index we are exploring for the top of stack.
                
                // Since we cannot easily manage this in one block without extra registers,
                // let's use a simpler heuristic:
                // Check if any non-terminal node can reach a non-terminal node.
                // Actually, any cycle in the graph of non-terminal nodes implies infinity.
                // We can use Floyd's algorithm or simple DFS.
                
                // Let's use the DFS approach but simplified.
                // We will just search for a node reachable from itself.
                // We can iterate through all nodes, and for each, check if reachable from itself.
                // This takes 32*32 steps. Feasible.
                
                // However, we need to handle the "start" state.
                // Only paths starting from root (0) matter.
                
                // Let's go back to the stack DFS but make it iterative.
                // We need to store the "last seen child" for each stack element.
                // Let's add a `dfs_child_idx` register.
                
                // Since we are already deep, let's assume `dp_symbol` acts as child index.
                // And `dp_stack_ptr` is stack depth.
                
                // Logic:
                // 1. If stack not empty:
                //    curr = stack[ptr-1].
                //    Check child dp_symbol.
                //    If dp_symbol < 2:
                //       next = trie[2*curr + dp_symbol].
                //       If next != 0 and !terminal[next]:
                //          If dp_visited[next]: CYCLE FOUND.
                //          Else: Push next to stack, mark visited, reset dp_symbol, increment ptr.
                //       Else: increment dp_symbol.
                //    Else (done with children):
                //       Unmark visited[curr], pop stack, restore previous dp_symbol.
                
                // We need to implement this.
                // We will need to restore `dp_symbol` of the previous stack frame.
                // We can store `dp_symbol` in `dp_stack` by using negative indices or parallel array.
                // Let's use `dp_visited` as `in_path`.
                // Let's use `best_len` to store the child index for each stack frame? No.
                // Let's use `best_str` as stack storage? No.
                
                // Let's add a register `dfs_child_idx [0:31]` to store child state for each stack depth.
                // Wait, we can't define arrays in always block.
                // We must use existing arrays or define them at top.
                // We have `best_str` and `best_len`. Can we reuse them for DFS?
                // Yes, if we haven't started DP yet.
                // So in S_CHECK_CYCLE, we can reuse `best_str` and `best_len` as scratch.
                // `best_str` can store the child index for each stack level.
                // `best_len` can store the node ID for each stack level? 
                // No, we have `dp_stack` for node IDs.
                // We need a `dfs_child_index` array. 
                // Let's repurpose `best_len` for this.
                // `best_len[stack_depth]` = child index to process next.
                
                // Implementation:
                if (dp_stack_ptr != 5'd0 && !cycle_found) begin
                    reg [4:0] curr_node_dfs;
                    curr_node_dfs = dp_stack[dp_stack_ptr - 5'd1];
                    
                    // Get current child index
                    reg [1:0] child_idx;
                    child_idx = best_len[dp_stack_ptr - 5'd1][1:0]; // Lower 2 bits for 0/1
                    
                    if (child_idx < 2) begin
                        // Process child
                        reg [4:0] next_node;
                        next_node = trie[2*curr_node_dfs + child_idx];
                        
                        if (next_node != 5'd0 && !terminal[next_node]) begin
                            if (dp_visited[next_node]) begin
                                cycle_found <= 1'b1;
                            end else begin
                                // Push to stack
                                dp_stack[dp_stack_ptr] <= next_node;
                                dp_visited[next_node] <= 1'b1;
                                // Reset child index for new node
                                best_len[dp_stack_ptr] <= 5'd0; // child_idx = 0
                                dp_stack_ptr <= dp_stack_ptr + 5'd1;
                            end
                        end
                        // Increment child index for current node
                        best_len[dp_stack_ptr - 5'd1] <= child_idx + 5'd1;
                    end else begin
                        // Pop stack
                        dp_visited[curr_node_dfs] <= 1'b0;
                        dp_stack_ptr <= dp_stack_ptr - 5'd1;
                    end
                end else if (dp_stack_ptr == 5'd0 && !cycle_found) begin
                    // Check if we finished DFS without cycle
                    cycle_check_done <= 1'b1;
                end
            end
            
            // Longest Path DP (S_COMPUTE)
            if (state == S_COMPUTE && !dp_done) begin
                // We need to compute longest path from root avoiding terminals.
                // We can use DFS + Memoization.
                // State: dfs(u) returns (len, str).
                // If terminal[u], return (0, 0).
                // If visited[u], return (best_len[u], best_str[u]).
                // Else:
                //   visited[u] = true.
                //   res1 = dfs(child0) + '0'.
                //   res2 = dfs(child1) + '1'.
                //   Pick better (longer, or lexicographically smaller).
                //   Store in best_len[u], best_str[u].
                //   Return.
                
                // This is a recursive DFS. We can simulate it with a stack.
                // We need a "post-order" traversal.
                // Stack elements need to remember which children were processed.
                // And we need to wait for children results.
                
                // Since we can't easily return values in seq logic without state,
                // let's use a simpler approach: Topological sort?
                // Graph has cycles (we checked). But we checked for cycles IN reachable subgraph.
                // If we are here, no cycles in reachable non-terminal subgraph.
                // So it's a DAG (Directed Acyclic Graph).
                // We can compute longest path in DAG.
                // But we need lexicographical tie-breaking.
                
                // Let's use the same stack DFS approach as cycle check, but with value propagation.
                // We will use `dp_stack` for traversal.
                // We will use `best_str` and `best_len` to store the results.
                // We need to store partial results. 
                // Actually, we can do:
                // 1. Push root.
                // 2. While stack not empty:
                //    peek.
                //    If children processed:
                //       compute result from children.
                //       pop.
                //    Else:
                //       push unprocessed child.
                //       Mark child as processed.
                //       Wait, we need to know if child is computed.
                //       If child is terminal, skip.
                //       If child is not computed, push child.
                //       If child is computed, use value.
                
                // We need a flag `computed` array or check `best_len` > 0 (careful with root 0).
                // Let's use `dp_visited` as `computed` flag.
                
                // We need to store which child we are processing.
                // `best_len[ptr]` can store child index (0, 1, 2 (done)).
                
                // Let's refine the loop.
                if (dp_stack_ptr != 5'd0) begin
                    reg [4:0] u;
                    u = dp_stack[dp_stack_ptr - 5'd1];
                    
                    // If u is terminal (should not happen if reachable and no cycle, but root might be terminal)
                    if (terminal[u]) begin
                        dp_stack_ptr <= dp_stack_ptr - 5'd1;
                        best_len[u] <= 5'd0;
                        best_str[u] <= 16'd0;
                        dp_visited[u] <= 1'b1;
                    end else begin
                        // Check children
                        reg [1:0] c_idx;
                        c_idx = best_len[dp_stack_ptr - 5'd1][1:0]; // Use lower bits
                        
                        if (c_idx < 2) begin
                            // Process child c_idx
                            reg [4:0] v;
                            v = trie[2*u + c_idx];
                            
                            // Increment index for next cycle
                            best_len[dp_stack_ptr - 5'd1] <= c_idx + 5'd1;
                            
                            if (v != 5'd0 && !terminal[v]) begin
                                if (dp_visited[v]) begin
                                    // Child already computed, do nothing (will combine later)
                                end else begin
                                    // Push child to stack
                                    dp_stack[dp_stack_ptr] <= v;
                                    dp_stack_ptr <= dp_stack_ptr + 5'd1;
                                    best_len[dp_stack_ptr] <= 5'd0; // Initialize child's index
                                end
                            end
                        end else begin
                            // Both children processed. Compute result for u.
                            // We need to compare child 0 and child 1 results.
                            // We have v0 = trie[2*u] and v1 = trie[2*u+1].
                            reg [4:0] v0, v1;
                            v0 = trie[2*u];
                            v1 = trie[2*u+1];
                            
                            reg [15:0] res_s0, res_s1;
                            reg [4:0] res_l0, res_l1;
                            
                            // Default to 0 (empty string)
                            res_s0 = 16'd0; res_l0 = 5'd0;
                            res_s1 = 16'd0; res_l1 = 5'd0;
                            
                            if (v0 != 5'd0 && !terminal[v0] && dp_visited[v0]) begin
                                res_l0 = best_len[v0] + 5'd1;
                                // Shift string right by 1 (LSB first) and add '0' (which is 0)
                                res_s0 = best_str[v0]; // '0' is 0, so just append 0 means shift left? 
                                // Wait, LSB first. 
                                // S = s0, s1, s2... (s0 is LSB)
                                // To append '0' to the end (MSB side): S_new = S << 1.
                                // But result_string is packed LSB first.
                                // So if we have string "10" (s0='0', s1='1'), bits are 110...
                                // Wait. LSB is first char.
                                // Char 0 is bit 0. Char 1 is bit 1.
                                // To append '0' (val 0) to end: shift left 1.
                                // To append '1' (val 1) to end: shift left 1, set bit 0? No.
                                // If we shift left 1, bit 0 becomes 0. Bit 1 becomes old bit 0.
                                // This is correct.
                                // So append '0' -> S = S << 1.
                                // Append '1' -> S = (S << 1) | 1.
                                
                                res_s0 = best_str[v0] << 1;
                            end
                            
                            if (v1 != 5'd0 && !terminal[v1] && dp_visited[v1]) begin
                                res_l1 = best_len[v1] + 5'd1;
                                res_s1 = (best_str[v1] << 1) | 16'd1;
                            end
                            
                            // Compare (len, then lex)
                            // Lexicographical order: smaller string is better.
                            // Since we build strings by appending, we compare the final packed strings.
                            // Since lengths are fixed, direct integer comparison works if we assume standard binary order.
                            // "01" < "10"? binary: 10 (2) < 01 (1)? No.
                            // Wait. "01" is s0=1, s1=0. Value: 0b10 = 2.
                            // "10" is s0=0, s1=1. Value: 0b01 = 1.
                            // "10" (1) < "01" (2). Correct.
                            // So smaller integer value = lexicographically smaller (for same length).
                            
                            reg [15:0] best_s;
                            reg [4:0] best_l;
                            
                            // Start with 0
                            best_l = 5'd0;
                            best_s = 16'd0;
                            
                            // Check 0
                            if (res_l0 > 0) begin
                                best_l = res_l0;
                                best_s = res_s0;
                            end
                            // Check 1
                            if (res_l1 > 0) begin
                                if (res_l1 > best_l) begin
                                    best_l = res_l1;
                                    best_s = res_s1;
                                end else if (res_l1 == best_l) begin
                                    if (res_s1 < best_s) begin
                                        best_s = res_s1;
                                    end
                                end
                            end
                            
                            best_len[u] <= best_l;
                            best_str[u] <= best_s;
                            dp_visited[u] <= 1'b1;
                            
                            dp_stack_ptr <= dp_stack_ptr - 5'd1;
                        end
                    end
                end else begin
                    // Stack empty. Done.
                    dp_done <= 1'b1;
                    res_str_temp <= best_str[0];
                    res_len_temp <= best_len[0];
                end
            end
        end
    end

endmodule