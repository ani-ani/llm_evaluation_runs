module graph_orientability(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_nodes,
    input [3:0] n_edges,
    input [2:0] edge_u [0:5],
    input [2:0] edge_v [0:5],
    output reg possible,
    output reg [2:0] out_u [0:5],
    output reg [2:0] out_v [0:5],
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam BUILD = 3'b001;
    localparam CHECK_EDGE = 3'b010;
    localparam CONNECTIVITY = 3'b011;
    localparam ANALYZE = 3'b100;
    localparam COMPLETE = 3'b101;

    reg [2:0] state, next_state;

    // Control Registers
    reg [3:0] current_edge_idx;
    reg [2:0] start_node;
    reg [2:0] edge_removal_idx;
    
    // Connectivity Check Registers (DFS)
    reg [3:0] visited_nodes;
    reg [3:0] stack [0:15]; // Stack for DFS
    reg [3:0] stack_ptr;
    reg [3:0] head_ptr;
    reg [3:0] reached_count;
    reg [2:0] current_node;
    reg [3:0] pop_counter;

    // Adjacency Matrix (4x4 bit vector packed)
    reg [15:0] adj_matrix;
    reg [15:0] temp_adj_matrix;

    // Edge processing registers
    reg [2:0] edge_u_reg [0:5];
    reg [2:0] edge_v_reg [0:5];
    reg [3:0] bridge_mask; // Bit mask indicating if edge at index is a bridge
    reg possible_reg;

    // Variables for loops
    integer i, j, k;
    reg [2:0] u, v;
    reg [15:0] temp_mask;
    reg [3:0] temp_idx;
    reg [2:0] temp_node;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = BUILD;
                else next_state = IDLE;
            end
            BUILD: begin
                next_state = CHECK_EDGE;
            end
            CHECK_EDGE: begin
                next_state = CONNECTIVITY;
            end
            CONNECTIVITY: begin
                // If stack empty or visited count matches n_nodes, go to analyze
                // Wait for DFS logic to complete (controlled by pop_counter logic)
                if (stack_ptr == head_ptr) next_state = ANALYZE;
                else next_state = CONNECTIVITY;
            end
            ANALYZE: begin
                if (current_edge_idx < n_edges) begin
                    next_state = CHECK_EDGE;
                end else begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            possible <= 0;
            valid <= 0;
            done <= 0;
            // Reset outputs
            for (i = 0; i < 6; i = i + 1) begin
                out_u[i] <= 0;
                out_v[i] <= 0;
            end
            adj_matrix <= 0;
            temp_adj_matrix <= 0;
            bridge_mask <= 0;
            possible_reg <= 0;
            current_edge_idx <= 0;
            edge_removal_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        // Store inputs locally to prevent changes during processing
                        for (i = 0; i < 6; i = i + 1) begin
                            edge_u_reg[i] <= edge_u[i];
                            edge_v_reg[i] <= edge_v[i];
                        end
                        current_edge_idx <= 0;
                        bridge_mask <= 0;
                        possible_reg <= 1;
                    end
                end

                BUILD: begin
                    // Construct adjacency matrix
                    adj_matrix <= 0;
                    // We iterate via unrolled loops or sequential logic. Since this is a small state,
                    // we execute once. We need to handle the 6 edges sequentially within BUILD state
                    // effectively or break into sub-states. Given the requirements, we can do it
                    // in one cycle using combinational logic or sequential within BUILD.
                    // Let's do it sequentially on rising edge of BUILD transition or use a counter.
                    // To keep it strictly sequential, we will use a separate counter.
                    // However, without explicit sub-states, we will build it fully inside this state transition.
                    // To be safe and synthesizable without combinational loops, we will assume
                    // it takes 1 cycle and handles all edges.
                    
                    // Since this is a clocked block, we compute next value.
                    // We need to preserve inputs, so we assume edge_u_reg/v_reg are stable.
                    // We calculate the matrix based on n_edges.
                    // Using an always block inside is not allowed. We do it here.
                    // We must clear first.
                    adj_matrix <= 0;
                    
                    // This part is tricky in one cycle. We will rely on the fact that BUILD takes exactly 1 cycle
                    // and we handle the logic via combinational next state logic or just do it here.
                    // Let's use combinational logic for BUILD in the next_state block? No, instructions say sequential.
                    // We will break BUILD into sub-steps if needed, but let's try to fit in 1 cycle
                    // by unrolling the logic for 6 edges.
                end
                
                // To make BUILD robust, we actually need to iterate 6 times or use a counter.
                // Let's add a counter logic inside BUILD state implicitly or use a flag.
                // Given strict instruction for sequential module and specific states, let's assume BUILD happens in 1 cycle
                // and we use a separate combinational block to derive the matrix value.
                // Since I cannot write combinational block explicitly for `adj_matrix` inside `always` 
                // without `assign` or `always @(*)`, I will calculate the next value of `adj_matrix` inside the sequential block.
                // For simplicity and correctness, I will use a generate-like approach by explicitly listing edges.
                // But wait, the inputs are variable count. I need to loop `n_edges`.
                // I will add a `build_done` flag to handle this state over multiple cycles if n_edges > 0.
                // Actually, to strictly follow the states given (BUILD -> CHECK_EDGE), I will do:
                // In IDLE, I capture `n_edges` and `edge_reg`. In BUILD, I construct `adj_matrix`.
                // I will calculate `adj_matrix` using combinational logic implicitly inside the sequential block.
                // I'll use a `for` loop. Synthesizable `for` loops are unrolled.
                    
                    // Since we are in a sequential block, I can't use `always @(*)` inside. 
                    // I will use a separate combinational block outside to calculate the matrix values,
                    // and assign them here, or do it directly.
                    // Let's do it directly in sequential block, but it must be unrolled.
                    // Actually, `adj_matrix` depends on `edge_u_reg` which is stable.
                    // I will calculate it here.
                    // Note: To ensure `adj_matrix` is set correctly, I will initialize it to 0 at IDLE,
                    // and set bits here. Since this is a single cycle state, I will iterate.
                    // But standard synthesizable code for variable loops in FSM usually requires the loop to be combinational.
                    // Let's define `adj_matrix_next` logic in an `always @(*)` block outside. 
                    // WAIT: The instruction says "Do not assume a clock signal unless explicitly given", but `clk` IS given.
                    // The instruction says "Only return Verilog code".
                    // I will implement the BUILD logic as a simple sequential step that sets the matrix.
                    // I will define a `build_index` counter to iterate through edges.
                    // Let's refine the states: IDLE -> BUILD (wait for build completion) -> CHECK_EDGE.
                    // But the prompt lists specific states. I will strictly follow IDLE->BUILD->CHECK_EDGE.
                    // To make BUILD work in 1 cycle, I will assume `n_edges` is small (max 6) and unroll.
                    // Let's define `reg [3:0] build_counter` to handle the loop over multiple cycles if needed.
                    // Let's add a sub-state or counter for BUILD.

                // REVISED FSM to handle sequential processing of edges for BUILD
                // We will stick to the state names, but BUILD will take multiple cycles.
                // Let's use `current_edge_idx` as the build index during BUILD.
                
                BUILD: begin
                    if (current_edge_idx < 6) begin
                        // Process edge if valid
                        if (current_edge_idx < n_edges) begin
                            // Set bit u->v and v->u (undirected)
                            // Matrix is 4x4. Row major: u*4 + v
                            // u = edge_u_reg[current_edge_idx], v = edge_v_reg[current_edge_idx]
                            // Adjust for 1-based indexing
                            // We need combinational logic to read edge_u_reg[current_edge_idx].
                            // Since it's inside sequential block, we read the reg.
                            // We can't do array indexing with variable in some synthesis tools without caution, but standard tools support it.
                            // Let's use a temporary variable.
                            // To be safe, we will use the logic: 
                            // The `current_edge_idx` increments. We update `adj_matrix` OR-ing the bits.
                            // Actually, we should clear `adj_matrix` first. 
                            // We can clear it at start of BUILD or IDLE.
                            // Let's clear at IDLE.
                            // We need to read edge_u_reg and edge_v_reg.
                            // Let's use helper regs `u_node` and `v_node`.
                            // Since we can't easily do variable array indexing in a sequential block inside an always block without 
                            // a `for` loop (which unrolls), let's use the following trick:
                            // We will rely on the fact that current_edge_idx is a register.
                            // We need to map current_edge_idx to values.
                            // This is hard without combinational logic.
                            // Let's add a combinational block outside for `next_adj_matrix`.
                            // But instructions say "Only return Verilog code". I will embed combinational logic using `always @(*)` outside the main FSM block.
                            // OR, I can use a case statement for indices 0-5 since max is 6. This is robust.
                        end
                        current_edge_idx <= current_edge_idx + 1;
                    end else begin
                        current_edge_idx <= 0; // Reset for CHECK_EDGE
                        // State transition handled in next_state logic
                    end
                end
                
                // REVISION 2: To strictly follow the user's states without adding new ones, and to keep code clean,
                // I will perform BUILD in a single cycle using a hardcoded loop structure if possible, 
                // OR use a separate combinational block to compute the adjacency matrix.
                // Let's use a separate combinational block `always @(*)` to calculate `adj_matrix`.
                // But wait, the instructions say "Only return Verilog code". It implies I can use standard constructs.
                // I will add an `always @(*)` block for `adj_matrix_next`.
                // And inside `BUILD` state, I will assign `adj_matrix <= adj_matrix_next`.
                // Since `edge_u_reg` and `edge_v_reg` are inputs to that combinational block, it works.
                // Let's do that. I will insert an `always @(*)` block before the main FSM always block.
                // Wait, I can't modify the structure that much? I can just put the logic inside the FSM state.
                // But I need to read the array indices. `edge_u_reg[edge_idx]` requires `edge_idx` to be constant for synthesis usually, or a wire.
                // `current_edge_idx` is a register. This is valid Verilog.
                // Let's try to do BUILD strictly sequentially.
                // We need to reset `adj_matrix` before filling. 
                // Let's assume `adj_matrix` is cleared at the start (in IDLE).
                // In BUILD, if `current_edge_idx == 0`, we clear it? No, we already did in IDLE.
                // We iterate `current_edge_idx` 0 to 5. If < n_edges, update.
                // 
                // Implementation detail: `edge_u_reg` is `reg [2:0] array [0:5]`. `current_edge_idx` is `reg [3:0]`.
                // `edge_u_reg[current_edge_idx]` returns 3 bits.
                // We need to map node index 1-4 to bit position 0-3? Or 1-4?
                // Let's map 1->0, 2->1, 3->2, 4->3 for matrix index.
                // u_idx = edge_u_reg[current_edge_idx] - 1.
                // v_idx = edge_v_reg[current_edge_idx] - 1.
                // If we are in BUILD, we update `adj_matrix`.
                // Because we are updating `adj_matrix` in a sequential block, we need to make sure we don't lose previous values.
                // 
                // Let's assume `adj_matrix` is a [15:0] vector.
                // To set bit (u_idx * 4 + v_idx), we do: `adj_matrix[u_idx * 4 + v_idx] <= 1`.
                // Since we are inside `always @(posedge clk)`, we can do this.
                // However, we are iterating 6 edges. We need to make sure we iterate through all 6.
                // I will use `current_edge_idx` to iterate. 
                // 
                // Wait, the state name is BUILD. It seems like it's a bulk operation.
                // I will implement BUILD as a state that checks `current_edge_idx`.
                // But the state transition logic says: BUILD -> CHECK_EDGE.
                // This implies BUILD finishes in 1 cycle or we stay in BUILD.
                // I will make BUILD stay until finished. 
                // I need to add a condition to `next_state` for BUILD.
                // If in BUILD and `current_edge_idx` < 6, stay in BUILD.
                // If `current_edge_idx` >= 6, go to CHECK_EDGE.
                // This is a deviation from the strict state list provided (BUILD -> CHECK_EDGE), but necessary for sequential processing.
                // Actually, let's look at the prompt again. "State Machine States: ... BUILD: Construct adjacency matrix".
                // It doesn't say how many cycles. I will make it take 6 cycles.
                // 
                // But to be safe and match the strict prompt logic: 
                // The prompt says: "BUILD: Construct adjacency matrix" -> "CHECK_EDGE: For current edge..."
                // This implies `current_edge_idx` is managed in `CHECK_EDGE`.
                // So `BUILD` should construct the WHOLE matrix. 
                // I will use a separate `build_counter` to handle the loop inside BUILD, 
                // so that `current_edge_idx` remains free for `CHECK_EDGE`.
                
                // Let's introduce `build_idx`.
                // 
                // RE-REVISION: 
                // I will stick to the prompt's flow exactly. 
                // To construct the matrix in BUILD without a loop counter inside the state, 
                // I will use a combinational block to compute the matrix from the stored edges.
                // Since `edge_u_reg` is a wire array, I can do:
                // `adj_matrix = (1 << (u*4+v)) | ...` but that requires `genvar` or unrolling.
                // 
                // Given the constraints, I will implement BUILD as a single cycle state that sets `adj_matrix`.
                // I will manually unroll the loop for 6 edges. This is standard for small fixed max size.
                // 
                // Let's write the logic inside BUILD:
                // If (n_edges > 0) check edge 0. 
                // But we need to accumulate. 
                // Let's assume `adj_matrix` is cleared at IDLE.
                // In BUILD state: 
                //   if (n_edges > 0) adj_matrix[{edge_u_reg[0]-1, edge_v_reg[0]-1}] <= 1; 
                //   ... this is hard to do sequentially in one cycle for variable edges.
                // 
                // CORRECT APPROACH for Verilog FSM:
                // Use a `for` loop inside the `always` block? No, it blocks.
                // Use a combinational block `always @(*)` for `adj_matrix_next`.
                // Update `adj_matrix <= adj_matrix_next` in BUILD state.
                // This effectively creates the matrix in 1 cycle.
                // This is the most efficient and synthesis-friendly way.
                // I will add this combinational block.
                // 
                // Wait, the prompt asks for "Sequential Verilog module".
                // Usually, this refers to the module behavior. Having combinational logic inside is fine.
                // 
                // Let's go with the `always @(*)` block for `adj_matrix_next`.
                // 
                // But wait, the instructions say "Only return Verilog code". I will include that block.
                // 
                // Let's refine the states:
                // IDLE -> BUILD (set adj_matrix) -> CHECK_EDGE -> CONNECTIVITY -> ANALYZE -> COMPLETE -> IDLE.
                // 
                // I will implement BUILD as: 
                //   adj_matrix <= adj_matrix_next;
                //   next_state = CHECK_EDGE;
                // 
                // Then CHECK_EDGE: 
                //   We remove edge `current_edge_idx` from `adj_matrix` to make `temp_adj_matrix`.
                //   `current_edge_idx` starts at 0. 
                //   Logic: `temp_adj_matrix = adj_matrix & ~(mask_u_v) & ~(mask_v_u)`.
                //   Then go to CONNECTIVITY.
                // 
                // CONNECTIVITY: 
                //   Initialize DFS stack with node 1.
                //   Run until stack empty.
                //   This will take multiple cycles (iterate 4 nodes).
                //   I will use a state loop inside CONNECTIVITY or just stay there until done.
                //   I will use a `stack_ptr` and `head_ptr` or just a `stack_ptr` and a `stack` array.
                //   Standard iterative DFS:
                //     Pop node. If not visited, mark visited.
                //     Push neighbors (nodes connected via edges NOT removed).
                //   Since `temp_adj_matrix` is fixed, we iterate 1 to `n_nodes`.
                // 
                // Let's implement the `adj_matrix_next` logic outside.

                // ADDING LOGIC OUTSIDE THE FSM BLOCK:
                // I will place an `always @(*)` block to calculate `adj_matrix_next` and `temp_adj_matrix_next`.
                // And maybe `dfs_next_state` logic.
            endcase
        end
    end

    // --- Combinational Logic Helper Block ---
    // We need to handle the dynamic indexing for synthesis. 
    // Since max nodes is 4 and edges 6, we can unroll loops using generate or explicit assignments.
    // Let's use explicit assignments for robustness.
    
    // 1. Adjacency Matrix Construction
    reg [15:0] adj_matrix_next;
    always @(*) begin
        adj_matrix_next = 0;
        // Use a loop unrolled by synthesis tools or explicit checks
        // We iterate 0 to 5.
        if (n_edges > 0 && edge_u_reg[0] != 0) adj_matrix_next[((edge_u_reg[0]-1)*4) + (edge_v_reg[0]-1)] = 1'b1;
        if (n_edges > 0 && edge_u_reg[0] != 0) adj_matrix_next[((edge_v_reg[0]-1)*4) + (edge_u_reg[0]-1)] = 1'b1;
        if (n_edges > 1 && edge_u_reg[1] != 0) adj_matrix_next[((edge_u_reg[1]-1)*4) + (edge_v_reg[1]-1)] = 1'b1;
        if (n_edges > 1 && edge_u_reg[1] != 0) adj_matrix_next[((edge_v_reg[1]-1)*4) + (edge_u_reg[1]-1)] = 1'b1;
        if (n_edges > 2 && edge_u_reg[2] != 0) adj_matrix_next[((edge_u_reg[2]-1)*4) + (edge_v_reg[2]-1)] = 1'b1;
        if (n_edges > 2 && edge_u_reg[2] != 0) adj_matrix_next[((edge_v_reg[2]-1)*4) + (edge_u_reg[2]-1)] = 1'b1;
        if (n_edges > 3 && edge_u_reg[3] != 0) adj_matrix_next[((edge_u_reg[3]-1)*4) + (edge_v_reg[3]-1)] = 1'b1;
        if (n_edges > 3 && edge_u_reg[3] != 0) adj_matrix_next[((edge_v_reg[3]-1)*4) + (edge_u_reg[3]-1)] = 1'b1;
        if (n_edges > 4 && edge_u_reg[4] != 0) adj_matrix_next[((edge_u_reg[4]-1)*4) + (edge_v_reg[4]-1)] = 1'b1;
        if (n_edges > 4 && edge_u_reg[4] != 0) adj_matrix_next[((edge_v_reg[4]-1)*4) + (edge_u_reg[4]-1)] = 1'b1;
        if (n_edges > 5 && edge_u_reg[5] != 0) adj_matrix_next[((edge_u_reg[5]-1)*4) + (edge_v_reg[5]-1)] = 1'b1;
        if (n_edges > 5 && edge_u_reg[5] != 0) adj_matrix_next[((edge_v_reg[5]-1)*4) + (edge_u_reg[5]-1)] = 1'b1;
    end

    // 2. Temp Adjacency Matrix (with one edge removed) for CHECK_EDGE state
    reg [15:0] temp_adj_matrix_next;
    reg [15:0] mask_u_v, mask_v_u;
    always @(*) begin
        // Default to current graph
        temp_adj_matrix_next = adj_matrix;
        
        // If we are checking edge `current_edge_idx`, we remove it.
        // We need to construct the mask for that edge.
        // Use casez or if-else to select edge based on current_edge_idx
        // Since current_edge_idx is 0-5, we can use a case statement.
        
        mask_u_v = 0;
        mask_v_u = 0;
        
        case (current_edge_idx)
            4'd0: begin
                if (n_edges > 0) begin
                    mask_u_v[ ((edge_u_reg[0]-1)*4) + (edge_v_reg[0]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[0]-1)*4) + (edge_u_reg[0]-1) ] = 1'b1;
                end
            end
            4'd1: begin
                if (n_edges > 1) begin
                    mask_u_v[ ((edge_u_reg[1]-1)*4) + (edge_v_reg[1]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[1]-1)*4) + (edge_u_reg[1]-1) ] = 1'b1;
                end
            end
            4'd2: begin
                if (n_edges > 2) begin
                    mask_u_v[ ((edge_u_reg[2]-1)*4) + (edge_v_reg[2]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[2]-1)*4) + (edge_u_reg[2]-1) ] = 1'b1;
                end
            end
            4'd3: begin
                if (n_edges > 3) begin
                    mask_u_v[ ((edge_u_reg[3]-1)*4) + (edge_v_reg[3]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[3]-1)*4) + (edge_u_reg[3]-1) ] = 1'b1;
                end
            end
            4'd4: begin
                if (n_edges > 4) begin
                    mask_u_v[ ((edge_u_reg[4]-1)*4) + (edge_v_reg[4]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[4]-1)*4) + (edge_u_reg[4]-1) ] = 1'b1;
                end
            end
            4'd5: begin
                if (n_edges > 5) begin
                    mask_u_v[ ((edge_u_reg[5]-1)*4) + (edge_v_reg[5]-1) ] = 1'b1;
                    mask_v_u[ ((edge_v_reg[5]-1)*4) + (edge_u_reg[5]-1) ] = 1'b1;
                end
            end
        endcase
        
        temp_adj_matrix_next = adj_matrix & ~mask_u_v & ~mask_v_u;
    end

    // 3. DFS Neighbor Logic
    // For the current node `current_node`, we need to find neighbors from `temp_adj_matrix`.
    // The neighbor `j` exists if `temp_adj_matrix[current_node * 4 + j]` is 1.
    // We will push valid neighbors sequentially (0 to 3).
    // We need a loop counter for checking neighbors.
    reg [1:0] neighbor_check_idx;
    
    // --- Main Sequential Logic (Resumed) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                // UPDATE BUILD STATE
                BUILD: begin
                    // Assign the precomputed matrix
                    adj_matrix <= adj_matrix_next;
                    current_edge_idx <= 0; // Reset for iteration in CHECK_EDGE
                    bridge_mask <= 0;
                    possible_reg <= 1;
                    // We rely on next_state to transition immediately or wait?
                    // Since comb logic computes it, we can transition immediately.
                end

                // CHECK_EDGE: Prepare temp matrix and initialize DFS
                CHECK_EDGE: begin
                    // Check if we have processed all edges
                    if (current_edge_idx < n_edges) begin
                        // Load temp_adj_matrix (computed comb logic)
                        temp_adj_matrix <= temp_adj_matrix_next;
                        
                        // Initialize DFS variables
                        visited_nodes <= 0;
                        // Start DFS from node 1 (index 0)
                        stack[0] <= 0; // Node 0 (physical index)
                        stack_ptr <= 1;
                        head_ptr <= 0;
                        reached_count <= 0;
                        neighbor_check_idx <= 0;
                        
                        // We need to track that we are starting DFS
                        // We will process first node in same cycle or next? 
                        // Usually next cycle to let signals settle.
                    end
                end

                // CONNECTIVITY: Run DFS
                CONNECTIVITY: begin
                    // Iterative DFS Logic
                    if (head_ptr < stack_ptr) begin
                        // Pop node from stack
                        current_node <= stack[head_ptr];
                        head_ptr <= head_ptr + 1;
                        // We need to check if this node is visited
                        // We do this in the same cycle or next? 
                        // Let's use a dedicated register for the popped node processing state.
                        // But we can use the 'current_node' register and a 'valid_popped' flag.
                        // Let's use `current_node` which is updated from stack.
                    end
                end
                
                // ANALYZE: Check results
                ANALYZE: begin
                    if (current_edge_idx < n_edges) begin
                        // Check if graph was disconnected (visited_nodes < n_nodes)
                        // Note: n_nodes is 1-based, visited_nodes is 0-based count.
                        // If n_nodes == 1, count 1. If n_nodes==2, count 2.
                        // We need to compare `reached_count` with `n_nodes`.
                        // Actually, we have to check if ALL nodes are reachable.
                        // The DFS starts at node 0. It should visit nodes 0 to n_nodes-1.
                        
                        // Edge case: If n_nodes = 1, we visit 1 node.
                        if (reached_count < n_nodes) begin
                            // Disconnected, this edge is a bridge
                            bridge_mask[current_edge_idx] <= 1'b1;
                            possible_reg <= 1'b0;
                        end
                        
                        // Next edge
                        current_edge_idx <= current_edge_idx + 1;
                    end
                end

                // COMPLETE: Finalize outputs
                COMPLETE: begin
                    possible <= possible_reg;
                    done <= 1;
                    valid <= 1;
                    
                    // Output edges
                    for (i = 0; i < 6; i = i + 1) begin
                        if (i < n_edges) begin
                            out_u[i] <= edge_u_reg[i];
                            out_v[i] <= edge_v_reg[i];
                        end else begin
                            out_u[i] <= 0;
                            out_v[i] <= 0;
                        end
                    end
                    
                    // If possible is 0, we might leave outputs as is or clear, 
                    // spec says "output original edges as orientation" if possible.
                    // If impossible, the outputs are technically invalid, but `valid` is high.
                    // Spec says "If any bridge exists, impossible (output possible=0)".
                    // "If no bridges, possible (output possible=1, and original edges as orientation)".
                    // It doesn't specify output for impossible case. We will output original edges but `possible=0`.
                end
            endcase
        end
    end

    // --- DFS Sub-Logic Handler ---
    // We need to handle the popping and pushing in CONNECTIVITY state.
    // The `CONNECTIVITY` state as defined in the prompt loops.
    // Since I can't put an infinite loop in a state, I will handle it in cycles.
    // 
    // Logic for `CONNECTIVITY` state:
    // We are in this state while stack is not empty.
    // We popped `current_node` in the `CONNECTIVITY` block above.
    // But we need to mark it visited and push neighbors.
    // To do this efficiently, we can add a sub-state or use a flag.
    // Let's use a register `dfs_phase`.
    // Phase 0: Mark visited (if new).
    // Phase 1: Push neighbors.
    // But wait, `current_node` is popped in `CONNECTIVITY` block.
    // Let's adjust the `CONNECTIVITY` state logic inside the sequential block.
    
    // Re-writing `CONNECTIVITY` block for better clarity and correctness.
    // We will use a `dfs_active` flag or check `head_ptr < stack_ptr`.
    // 
    // Let's refine the logic:
    // 1. In `CHECK_EDGE`, we reset `stack`, `visited`, `head_ptr`, `stack_ptr`.
    //    We push node 0. So `stack_ptr=1`, `head_ptr=0`.
    //    We go to `CONNECTIVITY`.
    // 2. In `CONNECTIVITY`: 
    //    If `head_ptr < stack_ptr`:
    //       Read `stack[head_ptr]` -> `current_node`.
    //       `head_ptr` increments.
    //       Check if `current_node` is already visited?
    //       If yes, continue (don't push neighbors).
    //       If no, mark visited. Then push neighbors.
    //       Pushing neighbors: Iterate `neighbor_check_idx` 0 to 3.
    //       If edge exists in `temp_adj_matrix` and neighbor not visited (or just push, let duplicates handle later)
    //       and neighbor is < n_nodes.
    //       Push to `stack[stack_ptr]`, increment `stack_ptr`.
    //       
    //    If `head_ptr == stack_ptr`, go to `ANALYZE`.
    //    
    // This requires multiple cycles per node.
    // 
    // Let's implement `CONNECTIVITY` state fully:

    // We need to handle the DFS loop in `CONNECTIVITY`. 
    // To avoid adding new states, I will manage it within `CONNECTIVITY`.
    // We need to read `stack[head_ptr]` and process it.
    // 
    // Let's add a `dfs_step` register to track if we are processing a node (marking vs pushing).
    // But wait, the sequential block logic I wrote earlier sets `current_node <= stack[head_ptr]`.
    // Then I need to process that node.
    
    // Let's modify the `CONNECTIVITY` state handling:
    // We will use a `current_node_valid` flag.
    
    // Since I need to modify the `always @(posedge clk)` block, I will rewrite the `CONNECTIVITY` part.
    // I will replace the simple `CONNECTIVITY` block with a more robust one.
    
    // Given the strict output format, I must provide the final code.
    // I will assume the previous `always` block structure and refine it.
    
    // Actually, to ensure the DFS works correctly in a single state, let's define the operation:
    // 1. Pop node.
    // 2. If visited, repeat (pop again).
    // 3. If not visited, mark visited.
    // 4. Push neighbors.
    // 5. Repeat.
    
    // This is effectively a loop. In hardware FSM, this takes many cycles.
    // I will handle this in `CONNECTIVITY` state.
    
    // Let's update the `CONNECTIVITY` block in the sequential logic.
    // I'll insert a specific `always` block for DFS operations or just logic.
    
    // The code below integrates the DFS logic into the FSM.

    // **Refined DFS Logic within `CONNECTIVITY` State**
    // We need a way to know if we are currently processing a node (Phase 1) or looking for a node (Phase 0).
    // Let's use a flag `dfs_node_valid`.
    
    reg dfs_node_valid;
    reg [2:0] dfs_current_node;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dfs_node_valid <= 0;
            dfs_current_node <= 0;
            // ... other resets
        end else if (state == CHECK_EDGE) begin
            // Reset DFS flags when starting new edge check
            dfs_node_valid <= 0;
        end else if (state == CONNECTIVITY) begin
            if (!dfs_node_valid) begin
                // Try to pop a node
                if (head_ptr < stack_ptr) begin
                    dfs_current_node <= stack[head_ptr];
                    head_ptr <= head_ptr + 1;
                    dfs_node_valid <= 1'b1;
                end
            end else begin
                // Node is valid in `dfs_current_node`
                // 1. Check if visited
                if (visited_nodes[dfs_current_node]) begin
                    // Already visited, discard and look for next
                    dfs_node_valid <= 1'b0;
                end else begin
                    // 2. Mark visited
                    visited_nodes[dfs_current_node] <= 1'b1;
                    reached_count <= reached_count + 1;
                    
                    // 3. Push neighbors
                    // We will use `neighbor_check_idx` to iterate 0 to 3
                    if (neighbor_check_idx < n_nodes[1:0]) begin // Only check valid nodes
                        // Check connection in temp_adj_matrix
                        // index = dfs_current_node * 4 + neighbor_check_idx
                        // We need to construct the index dynamically.
                        // `dfs_current_node` is 0-3. `neighbor_check_idx` is 0-3.
                        // Since we are in sequential block, we can use a helper wire or calculate directly.
                        // Let's use a temporary reg `check_bit`.
                        // But we can't easily index array with variable in `always` block without explicit logic.
                        // Let's use a case statement or helper combinational block.
                        // Let's use the `temp_adj_matrix` which is a wire/reg.
                        // Access bit: `temp_adj_matrix[ dfs_current_node * 4 + neighbor_check_idx ]`
                        // `dfs_current_node * 4` is `dfs_current_node << 2`.
                        
                        // To check connection:
                        // We need to calculate the bit index.
                        // Since `dfs_current_node` is a reg, this requires combinational logic.
                        // I will use a wire `connection_exists`.
                        // But I can't define a wire inside the always block.
                        // I will define a combinational block at the bottom to drive `connection_exists`.
                        // OR, I can manually unroll for `dfs_current_node`.
                        // Since `dfs_current_node` is 0-3, let's use an `if` chain.
                        
                        // Check connection logic:
                        reg conn;
                        conn = 0;
                        case (dfs_current_node)
                            0: conn = temp_adj_matrix[neighbor_check_idx];
                            1: conn = temp_adj_matrix[4 + neighbor_check_idx];
                            2: conn = temp_adj_matrix[8 + neighbor_check_idx];
                            3: conn = temp_adj_matrix[12 + neighbor_check_idx];
                        endcase
                        
                        if (conn && (stack_ptr < 16)) begin
                            // Push neighbor
                            // But wait, if neighbor is already visited, we might push it. 
                            // Optimization: Don't push if visited. But we need combinational logic for that too.
                            // Let's just push. It handles duplicates.
                            if (!visited_nodes[neighbor_check_idx]) begin
                                stack[stack_ptr] <= neighbor_check_idx;
                                stack_ptr <= stack_ptr + 1;
                            end
                        end
                        
                        neighbor_check_idx <= neighbor_check_idx + 1;
                    end else begin
                        // Finished pushing neighbors for this node
                        dfs_node_valid <= 1'b0;
                        neighbor_check_idx <= 0;
                    end
                end
            end
        end
    end

    // Combinational logic to detect end of DFS for state transition
    // This logic is needed to transition from CONNECTIVITY to ANALYZE.
    // The FSM next_state logic currently checks: `if (stack_ptr == head_ptr) next_state = ANALYZE;`
    // But we also need to check if `dfs_node_valid` is low and stack is empty.
    // The current next_state logic is: `if (stack_ptr == head_ptr) next_state = ANALYZE;`
    // This is slightly imperfect if we just popped a node (head_ptr advanced) but haven't processed it (dfs_node_valid=1).
    // We need to refine the next_state logic.
    // 
    // Let's refine `next_state` logic for CONNECTIVITY:
    // Condition to leave: stack is empty AND we are not processing a node.
    // Condition: `(head_ptr == stack_ptr) && !dfs_node_valid`

    // Re-defining `next_state` logic for `CONNECTIVITY`:
    // It was: `if (stack_ptr == head_ptr) next_state = ANALYZE;`
    // Should be: `if (stack_ptr == head_ptr && !dfs_node_valid) next_state = ANALYZE;`

    // **Final updates to the FSM logic blocks:**

    // Update Next State Logic (partially defined above, appending refined logic)
    // We need to overwrite the block or append. Since I can't append in JSON string easily, 
    // I will regenerate the `always @(*)` block for `next_state` to be fully correct.

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = BUILD;
                else next_state = IDLE;
            end
            BUILD: begin
                next_state = CHECK_EDGE;
            end
            CHECK_EDGE: begin
                if (current_edge_idx < n_edges) begin
                    next_state = CONNECTIVITY;
                end else begin
                    next_state = COMPLETE;
                end
            end
            CONNECTIVITY: begin
                // Stay in connectivity if stack not empty OR we are processing a node
                if ((stack_ptr != head_ptr) || dfs_node_valid) begin
                    next_state = CONNECTIVITY;
                end else begin
                    next_state = ANALYZE;
                end
            end
            ANALYZE: begin
                // We iterate current_edge_idx inside ANALYZE state.
                // After updating bridge info, we need to decide where to go.
                // If we increment `current_edge_idx` here, we can immediately check if we are done.
                // But usually, we go back to CHECK_EDGE if more edges, else COMPLETE.
                // Let's stick to the prompt's flow: 
                // "ANALYZE: Check if all nodes were reached"
                // "COMPLETE: Set outputs"
                // The prompt says: "CHECK_EDGE -> CONNECTIVITY -> ANALYZE -> COMPLETE (or back to CHECK_EDGE?)"
                // It says: "For each edge..." implies loop. 
                // So: ANALYZE -> (if more edges) CHECK_EDGE -> ...
                // The prompt flow: "CHECK_EDGE: For current edge..." -> "CONNECTIVITY..." -> "ANALYZE..."
                // It does not explicitly show the loop back, but step 3 says "For each edge".
                // I will manage the loop in ANALYZE state.
                
                // Logic: If `current_edge_idx` < `n_edges`, we have just analyzed one. 
                // We need to go to next. So we transition to CHECK_EDGE.
                // But wait, `current_edge_idx` increments in `ANALYZE` (Sequential block).
                // So if `current_edge_idx` (before increment) was < n_edges, we stay in loop.
                // 
                // Correct flow:
                // CHECK_EDGE (sets up edge k)
                // CONNECTIVITY (checks k)
                // ANALYZE (records result for k, increments k)
                // 
                // If k < n_edges: Go to CHECK_EDGE
                // Else: Go to COMPLETE
                
                // Since we increment `current_edge_idx` in `ANALYZE` state (Sequential), 
                // we need to check the NEW value or OLD value.
                // Let's check if `current_edge_idx` < `n_edges`.
                // Wait, `current_edge_idx` is updated in `ANALYZE`.
                // We need to check `current_edge_idx + 1` effectively.
                // OR, we increment `current_edge_idx` at the END of `ANALYZE` or transition.
                // Let's increment `current_edge_idx` in `ANALYZE` state logic.
                // And check `current_edge_idx`.
                
                if (current_edge_idx < n_edges) begin
                    next_state = CHECK_EDGE;
                end else begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Refine Sequential Block for `ANALYZE` and `CONNECTIVITY`
    // I will rewrite the sequential block to include the refined logic.
    // To avoid conflicts, I will overwrite the existing `always @(posedge clk...)` block with the refined one.
    // This requires me to paste the full `always` block again in the code.

endmodule

module graph_orientability (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_nodes,
    input [3:0] n_edges,
    input [2:0] edge_u [0:5],
    input [2:0] edge_v [0:5],
    output reg possible,
    output reg [2:0] out_u [0:5],
    output reg [2:0] out_v [0:5],
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam BUILD = 3'b001;
    localparam CHECK_EDGE = 3'b010;
    localparam CONNECTIVITY = 3'b011;
    localparam ANALYZE = 3'b100;
    localparam COMPLETE = 3'b101;

    reg [2:0] state, next_state;

    // Registers
    reg [3:0] current_edge_idx;
    reg [15:0] adj_matrix;
    reg [15:0] temp_adj_matrix;
    reg [3:0] bridge_mask;
    reg possible_reg;
    
    // Edge storage
    reg [2:0] edge_u_reg [0:5];
    reg [2:0] edge_v_reg [0:5];

    // DFS Registers
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] head_ptr;
    reg [3:0] visited_nodes;
    reg [3:0] reached_count;
    reg dfs_node_valid;
    reg [2:0] dfs_current_node;
    reg [1:0] neighbor_check_idx;

    // Combinational Logic for Adjacency Matrix Construction
    // This block computes the next adjacency matrix value.
    // It is a pure combinational block.
    always @(*) begin
        adj_matrix_next = 0;
        // Unrolled loop for max 6 edges
        if (n_edges > 0 && edge_u_reg[0] != 0) adj_matrix_next[((edge_u_reg[0]-1)*4) + (edge_v_reg[0]-1)] = 1'b1;
        if (n_edges > 0 && edge_u_reg[0] != 0) adj_matrix_next[((edge_v_reg[0]-1)*4) + (edge_u_reg[0]-1)] = 1'b1;
        if (n_edges > 1 && edge_u_reg[1] != 0) adj_matrix_next[((edge_u_reg[1]-1)*4) + (edge_v_reg[1]-1)] = 1'b1;
        if (n_edges > 1 && edge_u_reg[1] != 0) adj_matrix_next[((edge_v_reg[1]-1)*4) + (edge_u_reg[1]-1)] = 1'b1;
        if (n_edges > 2 && edge_u_reg[2] != 0) adj_matrix_next[((edge_u_reg[2]-1)*4) + (edge_v_reg[2]-1)] = 1'b1;
        if (n_edges > 2 && edge_u_reg[2] != 0) adj_matrix_next[((edge_v_reg[2]-1)*4) + (edge_u_reg[2]-1)] = 1'b1;
        if (n_edges > 3 && edge_u_reg[3] != 0) adj_matrix_next[((edge_u_reg[3]-1)*4) + (edge_v_reg[3]-1)] = 1'b1;
        if (n_edges > 3 && edge_u_reg[3] != 0) adj_matrix_next[((edge_v_reg[3]-1)*4) + (edge_u_reg[3]-1)] = 1'b1;
        if (n_edges > 4 && edge_u_reg[4] != 0) adj_matrix_next[((edge_u_reg[4]-1)*4) + (edge_v_reg[4]-1)] = 1'b1;
        if (n_edges > 4 && edge_u_reg[4] != 0) adj_matrix_next[((edge_v_reg[4]-1)*4) + (edge_u_reg[4]-1)] = 1'b1;
        if (n_edges > 5 && edge_u_reg[5] != 0) adj_matrix_next[((edge_u_reg[5]-1)*4) + (edge_v_reg[5]-1)] = 1'b1;
        if (n_edges > 5 && edge_u_reg[5] != 0) adj_matrix_next[((edge_v_reg[5]-1)*4) + (edge_u_reg[5]-1)] = 1'b1;
    end

    // Combinational Logic for Temp Adjacency Matrix (Edge Removal)
    always @(*) begin
        temp_adj_matrix = adj_matrix;
        mask_u_v = 0;
        mask_v_u = 0;
        
        case (current_edge_idx)
            4'd0: if (n_edges > 0) begin mask_u_v[((edge_u_reg[0]-1)*4) + (edge_v_reg[0]-1)] = 1; mask_v_u[((edge_v_reg[0]-1)*4) + (edge_u_reg[0]-1)] = 1; end
            4'd1: if (n_edges > 1) begin mask_u_v[((edge_u_reg[1]-1)*4) + (edge_v_reg[1]-1)] = 1; mask_v_u[((edge_v_reg[1]-1)*4) + (edge_u_reg[1]-1)] = 1; end
            4'd2: if (n_edges > 2) begin mask_u_v[((edge_u_reg[2]-1)*4) + (edge_v_reg[2]-1)] = 1; mask_v_u[((edge_v_reg[2]-1)*4) + (edge_u_reg[2]-1)] = 1; end
            4'd3: if (n_edges > 3) begin mask_u_v[((edge_u_reg[3]-1)*4) + (edge_v_reg[3]-1)] = 1; mask_v_u[((edge_v_reg[3]-1)*4) + (edge_u_reg[3]-1)] = 1; end
            4'd4: if (n_edges > 4) begin mask_u_v[((edge_u_reg[4]-1)*4) + (edge_v_reg[4]-1)] = 1; mask_v_u[((edge_v_reg[4]-1)*4) + (edge_u_reg[4]-1)] = 1; end
            4'd5: if (n_edges > 5) begin mask_u_v[((edge_u_reg[5]-1)*4) + (edge_v_reg[5]-1)] = 1; mask_v_u[((edge_v_reg[5]-1)*4) + (edge_u_reg[5]-1)] = 1; end
        endcase
        
        temp_adj_matrix = adj_matrix & ~mask_u_v & ~mask_v_u;
    end

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? BUILD : IDLE;
            BUILD: next_state = CHECK_EDGE;
            CHECK_EDGE: next_state = (current_edge_idx < n_edges) ? CONNECTIVITY : COMPLETE;
            CONNECTIVITY: next_state = ((stack_ptr == head_ptr) && !dfs_node_valid) ? ANALYZE : CONNECTIVITY;
            ANALYZE: next_state = (current_edge_idx < n_edges) ? CHECK_EDGE : COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            possible <= 0;
            valid <= 0;
            done <= 0;
            current_edge_idx <= 0;
            bridge_mask <= 0;
            possible_reg <= 1;
            dfs_node_valid <= 0;
            adj_matrix <= 0;
            // Reset outputs
            for (integer i = 0; i < 6; i = i + 1) begin
                out_u[i] <= 0;
                out_v[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        // Store edges
                        for (integer i = 0; i < 6; i = i + 1) begin
                            edge_u_reg[i] <= edge_u[i];
                            edge_v_reg[i] <= edge_v[i];
                        end
                        current_edge_idx <= 0;
                        bridge_mask <= 0;
                        possible_reg <= 1;
                    end
                end

                BUILD: begin
                    // Assign matrix from comb logic
                    adj_matrix <= adj_matrix_next;
                    current_edge_idx <= 0;
                    possible_reg <= 1;
                end

                CHECK_EDGE: begin
                    if (current_edge_idx < n_edges) begin
                        // Init DFS for this edge
                        visited_nodes <= 0;
                        reached_count <= 0;
                        stack[0] <= 0; // Start from Node 1 (index 0)
                        stack_ptr <= 1;
                        head_ptr <= 0;
                        dfs_node_valid <= 0;
                        neighbor_check_idx <= 0;
                        // temp_adj_matrix is loaded from comb logic
                    end
                end

                CONNECTIVITY: begin
                    if (!dfs_node_valid) begin
                        // Try to pop
                        if (head_ptr < stack_ptr) begin
                            dfs_current_node <= stack[head_ptr];
                            head_ptr <= head_ptr + 1;
                            dfs_node_valid <= 1'b1;
                        end
                    end else begin
                        // Process popped node
                        if (visited_nodes[dfs_current_node]) begin
                            // Already visited, discard
                            dfs_node_valid <= 1'b0;
                        end else begin
                            // Mark visited
                            visited_nodes[dfs_current_node] <= 1'b1;
                            reached_count <= reached_count + 1;
                            
                            // Push neighbors
                            if (neighbor_check_idx < n_nodes[1:0]) begin
                                // Check connection
                                reg conn;
                                conn = 0;
                                case (dfs_current_node)
                                    0: conn = temp_adj_matrix[neighbor_check_idx];
                                    1: conn = temp_adj_matrix[4 + neighbor_check_idx];
                                    2: conn = temp_adj_matrix[8 + neighbor_check_idx];
                                    3: conn = temp_adj_matrix[12 + neighbor_check_idx];
                                endcase
                                
                                if (conn && (stack_ptr < 16)) begin
                                    if (!visited_nodes[neighbor_check_idx]) begin
                                        stack[stack_ptr] <= neighbor_check_idx;
                                        stack_ptr <= stack_ptr + 1;
                                    end
                                end
                                neighbor_check_idx <= neighbor_check_idx + 1;
                            end else begin
                                // Finished checking neighbors
                                dfs_node_valid <= 1'b0;
                                neighbor_check_idx <= 0;
                            end
                        end
                    end
                end

                ANALYZE: begin
                    if (current_edge_idx < n_edges) begin
                        // Check connectivity
                        if (reached_count < n_nodes) begin
                            bridge_mask[current_edge_idx] <= 1'b1;
                            possible_reg <= 1'b0;
                        end
                        // Move to next edge
                        current_edge_idx <= current_edge_idx + 1;
                    end
                end

                COMPLETE: begin
                    possible <= possible_reg;
                    done <= 1;
                    valid <= 1;
                    
                    // Output edges
                    for (integer i = 0; i < 6; i = i + 1) begin
                        if (i < n_edges) begin
                            out_u[i] <= edge_u_reg[i];
                            out_v[i] <= edge_v_reg[i];
                        end else begin
                            out_u[i] <= 0;
                            out_v[i] <= 0;
                        end
                    end
                end
            endcase
        end
    end
    
    // Internal helper regs for comb logic (must be declared)
    reg [15:0] adj_matrix_next;
    reg [15:0] mask_u_v, mask_v_u;

endmodule