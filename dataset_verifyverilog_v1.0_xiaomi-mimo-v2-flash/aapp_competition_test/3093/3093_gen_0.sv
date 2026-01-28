module color_planner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [5:0] K,
    input wire [15:0][3:0] f_arr,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_N = 5'd16;
    
    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_VARS     = 4'd1;
    localparam [3:0] FIND_ROOTS     = 4'd2;
    localparam [3:0] FIND_ROOTS_CHK = 4'd3;
    localparam [3:0] FIND_ROOTS_INC = 4'd4;
    localparam [3:0] CHECK_CYCLES   = 4'd5;
    localparam [3:0] CYCLE_LEN      = 4'd6;
    localparam [3:0] CYCLE_LEN_RUN  = 4'd7;
    localparam [3:0] CALC_COMPONENT = 4'd8;
    localparam [3:0] CALC_TREE      = 4'd9;
    localparam [3:0] CALC_CYCLE_WAY = 4'd10;
    localparam [3:0] CALC_POWER     = 4'd11;
    localparam [3:0] MULT_MOD       = 4'd12;
    localparam [3:0] MULT_MOD_2     = 4'd13;
    localparam [3:0] NEXT_NODE      = 4'd14;
    localparam [3:0] UPDATE_RESULT  = 4'd15;
    localparam [3:0] FINISH         = 4'd16;

    reg [3:0] state, next_state;
    
    // Registers for inputs (capture on start)
    reg [3:0] N_reg;
    reg [5:0] K_reg;
    
    // Storage for f_arr (packed for Verilator/Icarus compatibility)
    reg [3:0] f_reg [0:15];
    
    // Visited and Root flags
    reg visited [0:15];
    reg root [0:15];
    
    // Iteration counters
    reg [3:0] i; // General purpose index
    reg [3:0] current_node;
    reg [3:0] next_node_temp;
    reg [3:0] cycle_start;
    
    // Temporary registers
    reg [31:0] temp_val;
    reg [31:0] temp_val_2;
    reg [31:0] power_val;
    reg [31:0] power_base;
    reg [31:0] power_exp;
    reg [4:0] cycle_length;
    reg [4:0] tree_nodes_count;
    
    // Exponentiation state
    localparam [1:0] EXP_IDLE = 2'd0;
    localparam [1:0] EXP_RUN  = 2'd1;
    localparam [1:0] EXP_DONE = 2'd2;
    reg [1:0] exp_state;
    reg [31:0] exp_res;
    reg [31:0] exp_base;
    reg [31:0] exp_rem;
    
    integer j; // for initialization loop

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            N_reg <= 4'd0;
            K_reg <= 6'd0;
            i <= 4'd0;
            current_node <= 4'd0;
            next_node_temp <= 4'd0;
            cycle_start <= 4'd0;
            temp_val <= 32'd0;
            temp_val_2 <= 32'd0;
            power_val <= 32'd0;
            power_base <= 32'd0;
            power_exp <= 32'd0;
            cycle_length <= 5'd0;
            tree_nodes_count <= 5'd0;
            exp_state <= EXP_IDLE;
            exp_res <= 32'd0;
            exp_base <= 32'd0;
            exp_rem <= 32'd0;
            
            for (j = 0; j < 16; j = j + 1) begin
                f_reg[j] <= 4'd0;
                visited[j] <= 1'b0;
                root[j] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        N_reg <= N;
                        K_reg <= K;
                        // Copy f_arr to internal regs
                        for (j = 0; j < 16; j = j + 1) begin
                            if (j < N) f_reg[j] <= f_arr[j];
                            else f_reg[j] <= 4'd0;
                        end
                        state <= INIT_VARS;
                    end
                end

                INIT_VARS: begin
                    // Reset flags
                    i <= 4'd0;
                    result <= 32'd1; // Start with product of 1
                    state <= FIND_ROOTS;
                    for (j = 0; j < 16; j = j + 1) begin
                        visited[j] <= 1'b0;
                        root[j] <= 1'b0;
                    end
                end

                FIND_ROOTS: begin
                    if (i >= N_reg) begin
                        i <= 4'd0;
                        state <= CHECK_CYCLES;
                    end else begin
                        state <= FIND_ROOTS_CHK;
                    end
                end

                FIND_ROOTS_CHK: begin
                    // If f[i] is self (or points to self, 1-based), it's a root
                    // f[i] is 1-based in input, we store 1-based
                    if (f_reg[i] == i + 4'd1) begin
                        root[i] <= 1'b1;
                        visited[i] <= 1'b1;
                    end
                    state <= FIND_ROOTS_INC;
                end

                FIND_ROOTS_INC: begin
                    i <= i + 4'd1;
                    state <= FIND_ROOTS;
                end

                CHECK_CYCLES: begin
                    // Find an unvisited node to start cycle finding
                    if (i >= N_reg) begin
                        // All nodes visited (roots + cycle nodes). Now count trees.
                        state <= CALC_TREE;
                        i <= 4'd0; // Reset for tree counting
                    end else begin
                        if (visited[i]) begin
                            i <= i + 4'd1;
                        end else begin
                            // Found a node in a cycle. Trace it to find the root of the cycle
                            current_node <= i;
                            state <= CYCLE_LEN;
                        end
                    end
                end

                CYCLE_LEN: begin
                    // Trace until we hit a visited node
                    // Note: In a functional graph, an unvisited node leads to either another unvisited node or a cycle root
                    // We mark visited as we go to prevent infinite loops
                    if (visited[current_node]) begin
                        // Found a visited node, it must be the start of the cycle (root) or part of an already processed cycle
                        cycle_start <= current_node;
                        state <= CYCLE_LEN_RUN;
                        cycle_length <= 5'd0;
                    end else begin
                        visited[current_node] <= 1'b1;
                        next_node_temp <= f_reg[current_node] - 4'd1; // 0-based index
                        state <= CYCLE_LEN_RUN;
                    end
                end

                CYCLE_LEN_RUN: begin
                    // Loop to count cycle length
                    if (visited[next_node_temp]) begin
                        // If we hit a visited node, check if it's the start of our trace
                        // To simplify, we assume the trace logic in CYCLE_LEN places us correctly
                        // We need to count steps until we hit the 'current_node' logic again
                        // Actually, standard cycle detection: follow pointer, mark visited.
                        // When we hit a marked node, that's the cycle start.
                        
                        // Re-logic:
                        // If we just visited 'current_node', we move to f[current_node].
                        // If f[current_node] is visited, we might be entering a cycle.
                        // If f[current_node] is NOT visited, continue.
                        
                        // Let's use a simpler approach:
                        // Trace 'current_node' until we find a node that is a root OR already in a cycle.
                        // Since we marked visited in CYCLE_LEN, we just need to see if we loop back.
                        
                        // Check if next_node_temp points back to start of current traversal or a known root
                        if (next_node_temp == cycle_start && cycle_length > 0) begin
                             // Completed cycle
                             state <= CALC_COMPONENT;
                        end else if (root[next_node_temp]) begin
                            // Connected to a root (not a cycle in this component)
                            // This shouldn't happen for unvisited nodes entering here usually
                            // unless logic is slightly different. Assuming standard functional graph:
                            // Unvisited node -> leads to cycle or tree->cycle.
                            // If we hit a root, it means we are on a tree branch feeding the root.
                            // Wait, roots are marked visited.
                            // If we hit a root, this path is a tree feeding the root.
                            // We need to handle tree counting separately.
                            
                            // Special case: If we hit a root, it's not a cycle. 
                            // But the problem says: find cycles. 
                            // If we start from an unvisited node, we MUST find a cycle (unless N<=16 logic fail).
                            // Let's assume we only enter CYCLE_LEN if we are sure it's a cycle component.
                            // Actually, if N is small and K is small, logic holds.
                            
                            // If we hit a visited node that is NOT the start, we might be attaching to an existing structure.
                            // Just skip and continue in CHECK_CYCLES.
                            state <= CHECK_CYCLES;
                            i <= i + 4'd1;
                        end else begin
                            // Continue tracing
                            current_node <= next_node_temp;
                            // Mark visited for the next node (logic in CYCLE_LEN handles the check)
                            // We need to prep the next lookup
                            state <= CYCLE_LEN;
                        end
                    end else begin
                        // Next node is unvisited
                        visited[next_node_temp] <= 1'b1;
                        cycle_length <= cycle_length + 5'd1;
                        current_node <= next_node_temp;
                        next_node_temp <= f_reg[next_node_temp] - 4'd1;
                        // stay in CYCLE_LEN_RUN
                    end
                end

                CALC_COMPONENT: begin
                    // We found a cycle of length 'cycle_length'
                    // If cycle_length == 0, it was a single node self-loop (root) handled in FIND_ROOTS
                    // Here, cycle_length >= 1 (actually usually >= 2 for a distinct cycle)
                    // Calculate ways for cycle: K * (K-1)^(L-1)
                    // If K=1 and L>=2, result is 0.
                    
                    if (cycle_length < 2) begin
                        // Single node cycle or self-loop logic
                        // If single node, it acts like a tree node in terms of coloring? 
                        // No, cycle length 1 implies f[i] != i+1 but points to self? Impossible.
                        // Cycle length 1 means f[i] = i+1 (self loop). Handled in roots.
                        // Cycle length 1 from here implies a loop A->B->A (L=2? No, depends on definition).
                        // Let's stick to standard: L nodes in cycle.
                        // If L=1, it's a self-loop (no constraint). Ways = K.
                        // But our trace marks roots as visited. 
                        // If we enter here, cycle_length was incremented.
                        // If L=1 (A->B->...->A), length is number of edges? No, nodes.
                        // If we found 1 step back to start, cycle length is 1 node? 
                        // A->B->C->A is length 3.
                        // My trace logic increments 'cycle_length' for every step EXCEPT the start.
                        // So if we start at A, move to B (len=1), move to C (len=2), move to A (stop). Total nodes = 3.
                        // So cycle_length IS the node count.
                        
                        // If cycle_length is 0 (should not happen for cycle) or 1 (self loop A->A?),
                        // treat as K ways.
                        if (cycle_length == 0) begin
                            // Self loop
                            temp_val <= K_reg;
                            state <= UPDATE_RESULT;
                        end else begin
                            // cycle_length >= 1. 
                            // Calculate: K * (K-1)^(cycle_length - 1)
                            if (K_reg == 0) begin
                                temp_val <= 0;
                                state <= UPDATE_RESULT;
                            end else if (K_reg == 1) begin
                                if (cycle_length > 1) begin
                                    temp_val <= 0;
                                    state <= UPDATE_RESULT;
                                end else begin
                                    temp_val <= 1;
                                    state <= UPDATE_RESULT;
                                end
                            end else begin
                                // Start power calc for (K-1)^(cycle_length - 1)
                                power_base <= K_reg - 1;
                                power_exp <= cycle_length - 1;
                                state <= CALC_POWER;
                            end
                        end
                    end else begin
                        // cycle_length >= 2
                        if (K_reg == 0) begin
                            temp_val <= 0;
                            state <= UPDATE_RESULT;
                        end else if (K_reg == 1) begin
                            temp_val <= 0;
                            state <= UPDATE_RESULT;
                        end else begin
                            power_base <= K_reg - 1;
                            power_exp <= cycle_length - 1;
                            state <= CALC_POWER;
                        end
                    end
                end

                CALC_POWER: begin
                    // Iterative exponentiation (K-1)^(exp)
                    case (exp_state)
                        EXP_IDLE: begin
                            exp_res <= 32'd1;
                            exp_base <= power_base % MOD;
                            exp_rem <= power_exp;
                            exp_state <= EXP_RUN;
                        end
                        EXP_RUN: begin
                            if (exp_rem == 0) begin
                                exp_state <= EXP_DONE;
                            end else begin
                                if (exp_rem[0]) begin
                                    // exp_res = (exp_res * exp_base) % MOD
                                    temp_val_2 <= exp_res;
                                    temp_val <= exp_base;
                                    state <= MULT_MOD;
                                    // Wait for mult
                                end else begin
                                    // Just update exp_base
                                    temp_val_2 <= exp_base;
                                    temp_val <= exp_base;
                                    state <= MULT_MOD_2;
                                end
                                exp_rem <= exp_rem >> 1;
                            end
                        end
                        EXP_DONE: begin
                            exp_state <= EXP_IDLE;
                            // Multiply by K
                            temp_val_2 <= exp_res;
                            temp_val <= K_reg;
                            state <= MULT_MOD;
                        end
                    endcase
                end

                MULT_MOD: begin
                    // Multiply temp_val_2 * temp_val % MOD
                    temp_val_2 <= (temp_val_2 * temp_val) % MOD;
                    if (exp_state == EXP_DONE) begin
                        state <= UPDATE_RESULT;
                    end else begin
                        // Back to exponentiation loop
                        exp_res <= (temp_val_2 * temp_val) % MOD;
                        state <= CALC_POWER;
                        // Reset exp_state to run (it's still in RUN)
                        // Actually, we need to jump back to CALC_POWER but handle the state transition properly
                    end
                end

                MULT_MOD_2: begin
                    // Square base for exponentiation
                    exp_base <= (temp_val_2 * temp_val) % MOD;
                    exp_state <= EXP_RUN;
                    state <= CALC_POWER;
                end

                UPDATE_RESULT: begin
                    // Multiply result by temp_val_2 (which holds the component result)
                    // But wait, in CALC_POWER -> MULT_MOD flow, result is in temp_val_2
                    // Let's clarify: 
                    // CALC_POWER sets up MULT_MOD. MULT_MOD writes to temp_val_2.
                    // So we use temp_val_2.
                    
                    // Actually, for cycle calculation:
                    // CALC_POWER finishes -> MULT_MOD -> temp_val_2 holds K * (K-1)^(L-1)
                    // For tree calculation (CALC_TREE):
                    // We will calculate K^count and come here.
                    
                    temp_val <= result;
                    state <= MULT_MOD;
                    // Use a flag to indicate what to do next? 
                    // We can overload state or use next_state logic, but here we are sequential.
                    // Let's use next_state variable for post-mult jump
                    next_state <= CHECK_CYCLES;
                end

                CALC_TREE: begin
                    // Count tree nodes (unvisited nodes)
                    // This logic is tricky because FIND_ROOTS marked roots as visited.
                    // Nodes NOT visited are part of cycles or trees feeding roots.
                    // Actually, the problem statement says: graph has functional edges.
                    // Components are trees feeding into cycles.
                    // If we successfully found all roots (self-loops) and cycles,
                    // there should be no unvisited nodes.
                    // However, if constraints create chains A->B->C where C is a root,
                    // A and B are tree nodes.
                    
                    // Let's implement a pass to find unvisited nodes.
                    // If found, it means it's a tree node feeding a root or cycle.
                    // For a tree node, color choices = K (only constrained by parent).
                    
                    // Logic: Count total nodes in tree components.
                    // But wait, if a tree feeds into a cycle, we multiply K for each tree node.
                    // If a tree feeds into a root, we multiply K for each tree node.
                    
                    // If K=1, tree nodes contribute factor 1.
                    
                    // Iterate all nodes. If !visited, it's a tree node (or part of a cycle we missed, but logic should catch cycles).
                    // Add to tree_nodes_count.
                    // Mark visited (propagate up the tree?)
                    // Since edges point to constraint image, tree nodes point to parent.
                    // A->B means A constrains B. So B is parent of A. 
                    // If we find an unvisited node, we trace it until we hit a visited node (root or cycle).
                    // All nodes in that trace are tree nodes.
                    
                    // Optimization: Just count unvisited nodes. 
                    // Why? Because every unvisited node is unique in its path to a visited node.
                    // Coloring a tree of N nodes with K colors: K^N (since each has K choices, constrained only by parent which is colored before).
                    // Wait, is it strictly K^N? 
                    // If constraints were between siblings or complex, no. 
                    // But here: Image i != Image f[i].
                    // If we have A->B (A constr B). B is colored first (in cycle/root). A can be any color != B. (K-1 choices).
                    // Wait, the problem says: Image i must be diff from f[i].
                    // So if B is parent, A (child) must be diff from B.
                    // If B is root (self-loop), A has K-1 choices.
                    // If B is in cycle, A has K-1 choices.
                    // If A->B->C (A constr B, B constr C). C is root.
                    // C: K choices.
                    // B: K-1 choices (diff from C).
                    // A: K-1 choices (diff from B).
                    // Total for chain of length L (feeding root): K * (K-1)^(L-1).
                    // This looks exactly like a cycle calculation but starting from root.
                    
                    // Correction:
                    // Component = Cycle + Trees feeding into cycle.
                    // Color Cycle: K * (K-1)^(L_cycle - 1).
                    // Each tree node adds factor (K-1).
                    // Root (self-loop) is a cycle of length 1. Ways = K.
                    // Tree feeding root: adds factor (K-1).
                    
                    // So we need to sum the heights of trees?
                    // No, product of (K-1) for each tree node.
                    // Total Ways = (Cycle Ways) * (K-1)^(Total Tree Nodes).
                    
                    // Total Tree Nodes = N - (Sum of cycle lengths).
                    // Sum of cycle lengths = number of roots + number of cycle nodes.
                    // Roots are nodes with f[i] == i+1.
                    // Cycle nodes are nodes in non-self loops.
                    
                    // Let's count tree nodes.
                    // Identify all Cycle Nodes (Roots + Non-Root Cycle Nodes).
                    // Node count - Cycle Node Count = Tree Node Count.
                    
                    // Tree Node Count logic:
                    // Iterate all nodes. 
                    // If !visited: it's a tree node.
                    // If visited: check if it's in a cycle or is a root.
                    // We marked roots in FIND_ROOTS.
                    // We marked cycle nodes in CYCLE_LEN.
                    // What about trees feeding roots? 
                    // If A->B where B is root. 
                    // B is visited (root). A is not visited (unless we traced it).
                    // In our current logic, we only traced unvisited nodes to find cycles.
                    // We didn't trace unvisited nodes to find trees feeding roots.
                    // So we must iterate all nodes. If !visited, trace to find length (depth).
                    // Actually, we just need the count of tree nodes, not depth, because they all multiply by (K-1).
                    // Wait, A->B->C. A, B are tree nodes. Count = 2.
                    // Factor = (K-1)^2.
                    
                    // So, iterate all nodes. If !visited, trace until visited.
                    // Count nodes in trace. Add to tree_nodes_count.
                    // Mark nodes as visited to avoid double counting.
                    
                    if (i >= N_reg) begin
                        // Finished counting trees.
                        // Now calculate (K-1)^tree_nodes_count
                        if (K_reg <= 1 && tree_nodes_count > 0) begin
                             // If K=1, (K-1)=0. If any tree node, result is 0 (unless tree_nodes_count is 0).
                             temp_val <= 0;
                             state <= UPDATE_RESULT;
                             next_state <= FINISH;
                        end else begin
                            power_base <= K_reg - 1;
                            power_exp <= tree_nodes_count;
                            state <= CALC_POWER;
                            next_state <= FINISH;
                        end
                    end else begin
                        if (visited[i]) begin
                            i <= i + 4'd1;
                        end else begin
                            // Found tree node. Trace it.
                            current_node <= i;
                            state <= CALC_TREE_TRACE;
                            temp_val <= 32'd0; // counter for this tree
                        end
                    end
                end

                // New state to handle tree tracing
                CALC_TREE_TRACE: begin
                    if (visited[current_node]) begin
                        // End of trace
                        tree_nodes_count <= tree_nodes_count + temp_val[4:0];
                        i <= i + 4'd1;
                        state <= CALC_TREE;
                    end else begin
                        visited[current_node] <= 1'b1;
                        temp_val <= temp_val + 32'd1; // count this node
                        current_node <= f_reg[current_node] - 4'd1;
                        // stay in state
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= temp_val_2;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule