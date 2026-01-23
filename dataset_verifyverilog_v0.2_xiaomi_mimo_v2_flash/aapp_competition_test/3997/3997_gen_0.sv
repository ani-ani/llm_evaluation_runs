module tree_control(
    input clk,
    input rst_n,
    input start,
    // Tree structure: fixed 8 nodes, indexed 0-7 (root is 0)
    input [7:0] child_mask_0,
    input [7:0] child_mask_1,
    input [7:0] child_mask_2,
    input [7:0] child_mask_3,
    input [7:0] child_mask_4,
    input [7:0] child_mask_5,
    input [7:0] child_mask_6,
    input [7:0] child_mask_7,
    // Edge weights (16-bit)
    input [15:0] edge_weight_01, input [15:0] edge_weight_02, input [15:0] edge_weight_03,
    input [15:0] edge_weight_04, input [15:0] edge_weight_05, input [15:0] edge_weight_06,
    input [15:0] edge_weight_07,
    input [15:0] edge_weight_12, input [15:0] edge_weight_13, input [15:0] edge_weight_14,
    input [15:0] edge_weight_15, input [15:0] edge_weight_16, input [15:0] edge_weight_17,
    input [15:0] edge_weight_23, input [15:0] edge_weight_24, input [15:0] edge_weight_25,
    input [15:0] edge_weight_26, input [15:0] edge_weight_27,
    input [15:0] edge_weight_34, input [15:0] edge_weight_35, input [15:0] edge_weight_36,
    input [15:0] edge_weight_37,
    input [15:0] edge_weight_45, input [15:0] edge_weight_46, input [15:0] edge_weight_47,
    input [15:0] edge_weight_56, input [15:0] edge_weight_57,
    input [15:0] edge_weight_67,
    // Control values a_i (16-bit)
    input [15:0] a_0, input [15:0] a_1, input [15:0] a_2, input [15:0] a_3,
    input [15:0] a_4, input [15:0] a_5, input [15:0] a_6, input [15:0] a_7,
    output reg [2:0] result_index,
    output reg [3:0] result_value,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam VISIT = 3'b010;
    localparam CHECK = 3'b011;
    localparam UPDATE = 3'b100;
    localparam OUTPUT = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] current_state, next_state;

    // Internal arrays
    reg [15:0] distance_register [7:0]; // Stores dist(ancestor, current)
    reg [3:0] control_count [7:0];      // Stores result for each node
    reg [2:0] ancestor_node;            // The node v (controls others)
    reg [2:0] current_node;             // The node u (potential descendant)
    reg [2:0] output_counter;           // For OUTPUT state
    
    // Child masks storage
    reg [7:0] child_masks [7:0];
    // Edge weights storage (indexed by [parent][child])
    reg [15:0] edge_weights [7:0][7:0];
    reg [15:0] a_values [7:0];
    
    // Stack for DFS traversal (stores up to 8 nodes)
    reg [2:0] stack_path [7:0];
    reg [3:0] stack_depth; // 0-7
    reg [15:0] current_distance;
    
    // Helper logic to get edge weight
    wire [15:0] w_edge;
    assign w_edge = edge_weights[stack_path[stack_depth-1]][current_node];

    integer i, j;

    // Sequential State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end
            SETUP: begin
                next_state = VISIT;
            end
            VISIT: begin
                // If stack is empty (after root done), move to CHECK for first ancestor
                if (stack_depth == 0 && ancestor_node == 0 && current_node == 0)
                    next_state = CHECK;
                else if (stack_depth == 0)
                    next_state = CHECK; // Start checking for next ancestor
                else
                    next_state = VISIT; // Continue traversal
            end
            CHECK: begin
                // Logic inside always block to handle loop control
                next_state = CHECK; // Default, overridden below
                // We need to iterate through ancestor_node (0 to 7) and current_node (descendants)
                // If done with all checks for current ancestor, go to UPDATE
                // If done with all ancestors, go to OUTPUT
                // Else increment current_node or ancestor_node and go to CHECK
                // Since this is combinatorial logic, we handle transitions based on flags
                // To make it clean, we'll manage state changes inside the state machine block itself
            end
            UPDATE: begin
                next_state = CHECK; // Move to next ancestor or node
            end
            OUTPUT: begin
                if (output_counter == 7) next_state = DONE;
                else next_state = OUTPUT;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            done <= 0;
            result_index <= 0;
            result_value <= 0;
            stack_depth <= 0;
            ancestor_node <= 0;
            current_node <= 0;
            output_counter <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                control_count[i] <= 0;
                distance_register[i] <= 0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load inputs into internal arrays
                        child_masks[0] <= child_mask_0;
                        child_masks[1] <= child_mask_1;
                        child_masks[2] <= child_mask_2;
                        child_masks[3] <= child_mask_3;
                        child_masks[4] <= child_mask_4;
                        child_masks[5] <= child_mask_5;
                        child_masks[6] <= child_mask_6;
                        child_masks[7] <= child_mask_7;

                        // Mapping the flat edge inputs to 2D array (simplified map)
                        // This is verbose but necessary given the interface
                        edge_weights[0][1] <= edge_weight_01; edge_weights[0][2] <= edge_weight_02;
                        edge_weights[0][3] <= edge_weight_03; edge_weights[0][4] <= edge_weight_04;
                        edge_weights[0][5] <= edge_weight_05; edge_weights[0][6] <= edge_weight_06;
                        edge_weights[0][7] <= edge_weight_07;
                        edge_weights[1][2] <= edge_weight_12; edge_weights[1][3] <= edge_weight_13;
                        edge_weights[1][4] <= edge_weight_14; edge_weights[1][5] <= edge_weight_15;
                        edge_weights[1][6] <= edge_weight_16; edge_weights[1][7] <= edge_weight_17;
                        edge_weights[2][3] <= edge_weight_23; edge_weights[2][4] <= edge_weight_24;
                        edge_weights[2][5] <= edge_weight_25; edge_weights[2][6] <= edge_weight_26;
                        edge_weights[2][7] <= edge_weight_27;
                        edge_weights[3][4] <= edge_weight_34; edge_weights[3][5] <= edge_weight_35;
                        edge_weights[3][6] <= edge_weight_36; edge_weights[3][7] <= edge_weight_37;
                        edge_weights[4][5] <= edge_weight_45; edge_weights[4][6] <= edge_weight_46;
                        edge_weights[4][7] <= edge_weight_47;
                        edge_weights[5][6] <= edge_weight_56; edge_weights[5][7] <= edge_weight_57;
                        edge_weights[6][7] <= edge_weight_67;
                        
                        a_values[0] <= a_0; a_values[1] <= a_1; a_values[2] <= a_2; a_values[3] <= a_3;
                        a_values[4] <= a_4; a_values[5] <= a_5; a_values[6] <= a_6; a_values[7] <= a_7;
                    end
                end

                SETUP: begin
                    // Initialize for the first computation (v=0)
                    ancestor_node <= 0;
                    // Reset control counts
                    for (i = 0; i < 8; i = i + 1) control_count[i] <= 0;
                end

                VISIT: begin
                    // DFS Traversal to populate distance_register
                    if (stack_depth == 0 && ancestor_node == 0 && current_node == 0 && current_state != SETUP) begin
                        // Special case: Just finished root dist calculation, proceed
                        // Handled in logic flow
                    end else if (stack_depth == 0 && stack_path[0] != ancestor_node) begin
                        // Start traversal from root 0 for the current ancestor_node? 
                        // No, we traverse from root to descendants to calculate distances relative to root.
                        // Then we compute distances from ancestor u to descendant d as dist(root, d) - dist(root, u).
                        // Wait, problem says "dist(v,u)". It is a rooted tree, paths are unique.
                        // We can compute distance from Root to all nodes, then dist(A,B) = dist(Root, B) - dist(Root, A) if A is ancestor of B.
                        // Let's adopt the Root-relative distance approach to save states.
                        // We will compute dist_root[i] once for all i.
                        // But the state machine flow suggests on-the-fly. 
                        // Let's stick to the requested 'track cumulative distance from each ancestor'.
                        // Wait, simpler approach: Precompute Root distances, then derive control.
                        // However, the state machine implies a traversal per ancestor or similar.
                        // Let's use the efficient method: DFS from root once to get dist_root for all nodes.
                    end
                end
                
                // To strictly follow the 'Visiting' logic requested but efficiently:
                // We will perform 1 BFS/DFS pass from root to establish Root-to-Node distances.
                // Then we iterate v from 0 to 7. For each v, we iterate u from 0 to 7.
                // If u is descendant of v (check masks), dist = dist_root[u] - dist_root[v].
                // If dist <= a[u], count++.
                // This avoids complex stack traversal in hardware.
                
                // Re-defining VISIT state for precomputation:
                VISIT: begin
                    // If we are calculating Root Distances (Pass 1)
                    // Use BFS with simple queue logic or just iterate 3 times (depth max 7).
                    // Given 8 nodes, we can do:
                    // 1. Calculate dist_root for all nodes using a loop.
                    // 2. Then switch to CHECK phase.
                    
                    // Let's optimize:
                    // Pass 1: Compute dist_root. We use `current_node` to scan.
                    // Pass 2: Control counting. We use `ancestor_node` and `current_node`.
                    
                    // State `VISIT` handles Pass 1 (Precomputation)
                    // We iterate `current_node` 0..7. Calculate dist_root based on parent.
                    // Since input is child_mask, we don't have parent_mask.
                    // We need to find parent of current_node.
                    // This requires searching.
                    
                    // Alternative: Loop 0..7. For each node i, find its parent j (child_masks[j] has i).
                    // dist_root[i] = dist_root[parent] + edge_weight(parent,i).
                    // Since this is sequential, we can compute row by row.
                    
                    // Let's use VISIT to build a distance matrix (dist[u][v]) for all pairs.
                    // This is brute force but fits the "track cumulative distance" logic better.
                    // We need to identify path from u to v.
                    // We can store `ancestor_node` as u, `current_node` as v.
                    // We traverse v from 0..7 for each u.
                    // Stack `stack_path` stores the path from u to v.
                    
                    // Re-implementing VISIT for direct pair distance calculation:
                    // It's cleaner to calculate Root-to-Node distances first.
                    // Let's use a `sub_phase` register to distinguish.
                end
            endcase
            
            // Since the state machine logic above is split, we need a unified control block.
            // Let's rewrite the main logic block to be strictly sequential as requested.
        end
    end

    // COMPLETE LOGIC RE-WRITE FOR CORRECTNESS
    // We need a single always block to manage the sequence clearly.
    
    // Internal signals for distance calculation
    reg [15:0] dist_root [7:0];
    reg [2:0] calc_node; // Node currently computing distance for
    reg [2:0] calc_parent;
    
    // Logic for strict FSM control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            result_index <= 0;
            result_value <= 0;
            stack_depth <= 0;
            ancestor_node <= 0;
            current_node <= 0;
            output_counter <= 0;
            calc_node <= 0;
            current_state <= IDLE;
            for (i = 0; i < 8; i = i + 1) begin
                control_count[i] <= 0;
                dist_root[i] <= 0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load configuration
                        child_masks[0] <= child_mask_0;
                        child_masks[1] <= child_mask_1;
                        child_masks[2] <= child_mask_2;
                        child_masks[3] <= child_mask_3;
                        child_masks[4] <= child_mask_4;
                        child_masks[5] <= child_mask_5;
                        child_masks[6] <= child_mask_6;
                        child_masks[7] <= child_mask_7;
                        // We map inputs to edge_weights[7][7]
                        // To save space, we handle specific lookups in logic, or pre-map here.
                        // Mapping 28 inputs to 8x8 symmetric matrix (upper triangle)
                        // We will need a helper to retrieve weight. 
                        // Since we can't write a function in always block easily, we use a lookup block or compute on fly.
                        // Let's stick to the mapping logic:
                        edge_weights[0][1] <= edge_weight_01; edge_weights[0][2] <= edge_weight_02;
                        edge_weights[0][3] <= edge_weight_03; edge_weights[0][4] <= edge_weight_04;
                        edge_weights[0][5] <= edge_weight_05; edge_weights[0][6] <= edge_weight_06;
                        edge_weights[0][7] <= edge_weight_07;
                        edge_weights[1][2] <= edge_weight_12; edge_weights[1][3] <= edge_weight_13;
                        edge_weights[1][4] <= edge_weight_14; edge_weights[1][5] <= edge_weight_15;
                        edge_weights[1][6] <= edge_weight_16; edge_weights[1][7] <= edge_weight_17;
                        edge_weights[2][3] <= edge_weight_23; edge_weights[2][4] <= edge_weight_24;
                        edge_weights[2][5] <= edge_weight_25; edge_weights[2][6] <= edge_weight_26;
                        edge_weights[2][7] <= edge_weight_27;
                        edge_weights[3][4] <= edge_weight_34; edge_weights[3][5] <= edge_weight_35;
                        edge_weights[3][6] <= edge_weight_36; edge_weights[3][7] <= edge_weight_37;
                        edge_weights[4][5] <= edge_weight_45; edge_weights[4][6] <= edge_weight_46;
                        edge_weights[4][7] <= edge_weight_47;
                        edge_weights[5][6] <= edge_weight_56; edge_weights[5][7] <= edge_weight_57;
                        edge_weights[6][7] <= edge_weight_67;
                        
                        a_values[0] <= a_0; a_values[1] <= a_1; a_values[2] <= a_2; a_values[3] <= a_3;
                        a_values[4] <= a_4; a_values[5] <= a_5; a_values[6] <= a_6; a_values[7] <= a_7;
                        
                        current_state <= SETUP;
                    end
                end

                SETUP: begin
                    // Reset counters and arrays for calculation
                    for (i = 0; i < 8; i = i + 1) begin
                        control_count[i] <= 0;
                        dist_root[i] <= (i == 0) ? 0 : 16'hFFFF; // Root dist 0, others infinity
                    end
                    calc_node <= 1; // Start calculating dist for node 1
                    current_node <= 0; // Use for looping
                    // We enter VISIT to compute distances from Root (0) to all nodes.
                    // Since it's a tree, we can do this by iterating levels or checking parents.
                    // Given the flat input, we find parents by checking child_masks.
                    current_state <= VISIT;
                end

                VISIT: begin
                    // PART 1: Compute Root-to-Node distances
                    // We iterate calc_node from 1 to 7. Find parent. Update dist.
                    // Because edges are directed (parent->child), dist is additive.
                    // We might need multiple passes if children come before parents in order.
                    // To be safe, we perform 7 passes (max depth).
                    // Let's use `current_node` as pass counter.
                    
                    // Since child_mask is provided, we can find parent of any node 'i' by checking mask.
                    // If node `calc_node` has dist_root known (via parent), update.
                    // This looks like a BFS queue which is hard in pure logic without memory.
                    // Loop approach:
                    // For k=0 to 7:
                    //   For i=0 to 7:
                    //      Find parent P of i. If dist[P] + weight(P,i) < dist[i], update.
                    // This guarantees convergence.
                    
                    // Let's use `current_state` to manage the triple nested loop efficiently.
                    // But here in VISIT, let's do the distance calculation.
                    // We will use `stack_depth` as the outer loop counter (0 to 7).
                    // `calc_node` as the inner node iterator (0 to 7).
                    // `calc_parent` as the parent of `calc_node`.
                    
                    // Logic to find parent of `calc_node` (let's call it `u`)
                    // Iterate `j` 0..7. Check if child_masks[j] has bit `calc_node` set.
                    // This requires a sub-loop or comb logic.
                    // Let's assume `dist_root` is updated in `UPDATE` state based on `CHECK` state findings.
                    
                    // Simplified Logic:
                    // If `calc_node` > 0, find parent `p` of `calc_node`.
                    // If `dist_root[p]` is not infinity, add weight(p, calc_node) to get dist_root[calc_node].
                    // To handle dependencies, we loop this 8 times.
                    
                    // Since we are in VISIT, let's just iterate calc_node 0..7.
                    // We'll update in UPDATE.
                    if (calc_node < 8) begin
                        // Find parent of calc_node
                        // We need comb logic for parent. Let's add a wire.
                        // Wait, we can't easily loop inside always block without state.
                        // Let's use `current_node` as the pass count (0 to 7).
                        // In each pass, update all distances.
                        
                        if (current_node < 8) begin
                            // Check if current_node can be updated
                            // Find parent of current_node
                            // This is computationally expensive to do in one cycle for all nodes.
                            // Let's do: Calculate distance for ONE node per cycle in this state.
                            // Loop `calc_node` 0..7. Find parent, update.
                            // Loop `current_node` 0..7 (pass count) to ensure convergence.
                            
                            // We will use `calc_node` to index the node we are trying to update.
                            // We will use `current_node` as the "pass" index to ensure propagation.
                            
                            // Look for parent of `calc_node` using combinational logic defined below.
                            // If parent found and dist_root[parent] != MAX, update dist_root[calc_node].
                            // Increment `calc_node`. If 8, reset `calc_node` and increment `current_node` (pass).
                            
                            if (calc_node == 0) begin
                                // Root is 0, dist is 0. Skip.
                                if (current_node == 0) dist_root[0] <= 0;
                            end else begin
                                // Combinational block logic ported here:
                                // Find parent p of calc_node
                                // We need to look at child_masks[0..7] to see which has bit calc_node.
                                // This is sequential logic, so we need to unroll or compute.
                                // Let's use a `temp_parent` computed in a separate comb block.
                                // Since we can't define new regs easily, let's just check all.
                                // Optimization: Since we are in VISIT, and we have to do this, we might as well
                                // just have a pre-computed parent index if the structure was fixed.
                                // But it's inputs. 
                                
                                // We will use a helper variable in the block below to find parent.
                                // Actually, let's just rely on the fact that for a tree, dist(A, B) = dist(Root, B) - dist(Root, A).
                                // So we only need dist(Root, X) for all X.
                                // To compute dist(Root, X), we need parent[X].
                                // We will find parent in combinational logic and register the result.
                                
                                // Let's do the parent find logic here:
                                // Search for j in 0..7 such that child_masks[j][calc_node] is 1.
                                // Since we can't loop combinational in always block cleanly without a task, 
                                // we will use a `case` statement or bitwise reduction if possible, but 8 nodes allows simple ifs.
                                
                                // We will assume a `parent_idx` wire is available computed from inputs.
                                // To be synthesizable, we define this logic externally.
                            end
                            
                            // Increment logic
                            if (calc_node == 7) begin
                                calc_node <= 0;
                                if (current_node == 7) begin
                                    // Done with distance precomputation
                                    current_state <= CHECK;
                                    ancestor_node <= 0;
                                    current_node <= 0;
                                end else begin
                                    current_node <= current_node + 1;
                                end
                            end else begin
                                calc_node <= calc_node + 1;
                            end
                        end
                    end
                end

                CHECK: begin
                    // Main computation loop: For each ancestor v (0..7), check descendants u (0..7)
                    // Condition: u is descendant of v AND dist(v,u) <= a[u]
                    // dist(v,u) = dist_root[u] - dist_root[v]
                    
                    // We iterate: ancestor_node = 0..7, current_node = 0..7
                    // Check is combinational. Result stored in UPDATE.
                    
                    // If done with all pairs, go to OUTPUT
                    if (ancestor_node == 8) begin
                        current_state <= OUTPUT;
                        output_counter <= 0;
                    end else begin
                        // Process current pair (ancestor_node, current_node)
                        current_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Check if current_node is descendant of ancestor_node
                    // and dist <= a[current_node]
                    // Then increment control_count[ancestor_node]
                    
                    // Check descendant: Is there a path from ancestor_node to current_node?
                    // Path exists if ancestor_node is in ancestors of current_node.
                    // We can check this by walking up from current_node to root.
                    // Since we need this check, let's define a comb logic for "is_ancestor".
                    // Or simpler: dist_root[current_node] > dist_root[ancestor_node] AND paths connect.
                    // Because it's a tree, path exists if lowest common ancestor is ancestor_node.
                    // But finding LCA is complex. 
                    // Alternative: Pre-calculate a "reachability" matrix [8][8] using DFS in SETUP/VISIT?
                    // Or just calculate it on the fly? No.
                    
                    // Simplified approach for the specific problem:
                    // The input is a rooted tree. 
                    // To check if v is ancestor of u, we can trace u back to root and see if we hit v.
                    // We can do this in `CHECK`/`UPDATE` with a small loop or comb logic.
                    // Since depth is small (max 7), we can do this in one cycle with logic.
                    
                    // Let's implement a comb block for is_ancestor:
                    // wire is_descendant;
                    // assign is_descendant = (check_ancestor(current_node, ancestor_node, child_masks));
                    // Since we can't easily do recursive functions, we unroll:
                    // Walk up from current_node to root. 
                    // Since we don't have parent pointers, we search child_masks.
                    
                    // Let's do the check logic inline using a temporary variable `is_desc`.
                    // We need to find parents.
                    // Since we are in UPDATE, we can use the result of a previous combinational check.
                    
                    // Let's define a `descendant_check` wire in the module body.
                    // However, `descendant_check` depends on `ancestor_node` and `current_node`.
                    // We'll compute this in `CHECK` state and latch it, or do it in `UPDATE`.
                    
                    // Let's perform the check in `UPDATE`.
                    // We need to know if `ancestor_node` is on the path from `current_node` to Root.
                    // Let's trace parents of `current_node` up to root. 
                    // Since we don't have parent array, we search masks: find p where child_masks[p] has bit current_node.
                    // Then check if p == ancestor_node. If not, find parent of p.
                    // This requires a loop. We can unroll it up to depth 7.
                    
                    // Optimization: Since we computed dist_root, we know the distance.
                    // If dist_root[current_node] < dist_root[ancestor_node], then ancestor_node cannot be ancestor.
                    // If dist_root[current_node] >= dist_root[ancestor_node], we need to check if they are on same path.
                    // We can check by finding the node at distance dist_root[ancestor_node] from root along the path to current_node.
                    // 
                    // Let's use a simpler check:
                    // Iterate backwards from current_node.
                    // We will use `temp_node` and `temp_dist` registers for this traversal.
                    // Start with temp_node = current_node, temp_dist = dist_root[current_node].
                    // While temp_dist > dist_root[ancestor_node]:
                    //   Find parent of temp_node. temp_node = parent. temp_dist -= weight.
                    // If temp_dist == dist_root[ancestor_node] and temp_node == ancestor_node, then YES.
                    
                    // Since we are in a cycle, we can do one step of this walk per cycle.
                    // But we need the result to decide whether to increment control_count.
                    
                    // Given the "Result valid approx 200 cycles" hint, we can afford some latency.
                    // However, doing a loop per pair might take too long.
                    // Let's assume we can do the check in one cycle with logic.
                    // We need a combinational block to find parent of any node.
                    // 
                    // Re-thinking the "Check" state:
                    // We can generate a `valid_pair` signal.
                    // To find if `ancestor_node` is ancestor of `current_node`:
                    // We need to trace `current_node` up to `ancestor_node`.
                    // Let's do this: Calculate the specific node at `dist_root[ancestor_node]` on the path to `current_node`.
                    // 
                    // Implementation strategy for UPDATE:
                    // 1. Check distance: if (dist_root[current_node] - dist_root[ancestor_node] > a_values[current_node]) skip.
                    // 2. Check ancestry: Walk up `current_node` to root. If we hit `ancestor_node`, it's valid.
                    
                    // Let's implement the walk up logic in a combinational helper block.
                    // Since we need to do this in hardware, let's use a small loop state inside UPDATE if necessary.
                    // But to keep it simple, we will use the `CHECK` state to evaluate `is_valid` and `dist_ok`.
                    // We will use `UPDATE` to apply the increment.
                    
                    // Let's refine the states:
                    // CHECK: Compute `dist_ok` and `is_descendant`.
                    // UPDATE: If conditions met, increment count. Then advance iterators (ancestor_node, current_node).
                    // If iterators advance past 7, go to CHECK (which will then move to OUTPUT).
                    
                    // Let's move the logic to CHECK and UPDATE strictly.
                    // In CHECK:
                    // Calculate distance difference.
                    // Calculate ancestry (using `child_masks` lookup).
                    // This calculation might take multiple cycles or combinational logic.
                    // Let's do it in UPDATE state, using the previous cycle to setup or do it all in one cycle.
                    
                    // Let's stick to the state transition requested: CHECK -> UPDATE.
                    // We will compute the conditions in CHECK, and UPDATE stores them.
                    // Actually, it's easier to compute in UPDATE based on `current_node` and `ancestor_node`.
                    
                    // Let's use a temporary register `should_increment`.
                    // Also, we need to handle the "walk up" logic.
                    // Since we can't do complex loops in one cycle, we will use the fact that we have many cycles.
                    // We will implement a small sub-state machine or use the main state machine.
                    // Let's try to do it in one cycle: We need to check if `ancestor_node` is on the path.
                    // We can check: `child_masks[ancestor_node][current_node]` is NOT sufficient (direct child).
                    // We need `child_masks[ancestor_node]` to cover `current_node` or its descendants.
                    // We can precompute a "reachability" matrix R[i][j] in SETUP/VISIT.
                    // R[i][j] = 1 if i is ancestor of j.
                    // We can compute this in a loop in VISIT.
                    
                    // Let's add a `reachability` matrix calculation to the VISIT phase.
                    // VISIT Phase:
                    // 1. Compute dist_root (approx 8*8 cycles).
                    // 2. Compute reachability. 
                    //    reachability[i][j] = 1 if i is ancestor of j.
                    //    We can compute this by: i is ancestor of j if dist_root[i] < dist_root[j] AND path from j to root goes through i.
                    //    To check path: trace j up. If we find i, yes.
                    
                    // Given the complexity, let's simplify the design to match the requirements.
                    // Requirement: "Track cumulative distance".
                    // Let's use the stack-based DFS approach suggested.
                    // We will traverse the tree using a stack (simulated in registers).
                    // As we traverse, we maintain `distance_from_start` (where start is the current `ancestor_node`).
                    // 
                    // New Plan:
                    // Outer loop: ancestor_node = 0 to 7.
                    // Inner loop: DFS traversal of the tree starting from root.
                    // - Maintain `current_path_node` and `current_path_distance`.
                    // - When visiting a node `u`:
                    //   - If `u` is a descendant of `ancestor_node` (path includes `ancestor_node`):
                    //     Check `current_path_distance` (dist from ancestor to u) <= `a[u]`.
                    //     If yes, `control_count[ancestor_node]` ++.
                    
                    // To implement "path includes ancestor_node":
                    // We can track `ancestor_in_path` flag as we DFS.
                    // When we enter `ancestor_node`, set flag.
                    // Pass flag down to children.
                    // 
                    // This is complex. Let's go back to the "Root Distance + Check" method.
                    // It is the most robust.
                    // 
                    // Final Plan for UPDATE state:
                    // 1. Calculate `dist = dist_root[current_node] - dist_root[ancestor_node]`.
                    // 2. Check `dist <= a_values[current_node]`.
                    // 3. Check `ancestor_node` is ancestor of `current_node`.
                    //    To check ancestry without precomputed matrix, we can do a quick search in logic.
                    //    Since max depth is 7, we can trace back `current_node` up to root.
                    //    We need to find parent of `current_node`. Let's call it `p`.
                    //    We can find `p` by checking which `child_masks[p]` has bit `current_node`.
                    //    Then `p1`, `p2`, etc.
                    //    Since this is sequential logic, we can't do this easily in one cycle for arbitrary depth.
                    //    
                    //    However, we can precompute a `parent` array in SETUP/VISIT.
                    //    We can iterate 0..7, find parent for each node, store in `parent_idx[7:0]`.
                    //    Then in CHECK/UPDATE, we just walk up `parent_idx` array.
                    //    
                    //    Let's add a `phase` register. 
                    //    Phase 0: Compute `dist_root` and `parent_idx`.
                    //    Phase 1: Check loops.
                    
                    // Let's implement this in the main always block.
                    // We need to modify VISIT state to compute `dist_root` and `parent_idx`.
                    // We will need `calc_parent` array.
                    // 
                    // Logic for `UPDATE`:
                    // If (dist <= a[current_node]) and (is_ancestor(ancestor_node, current_node))
                    //    control_count[ancestor_node] ++;
                    // 
                    // `is_ancestor` check logic:
                    // Trace `current_node` up via `parent_idx`.
                    // Since we have `parent_idx` array, we can check this in combinational logic.
                    // But combinational loop `while (node != ancestor_node && node != root) node = parent_idx[node];` is not allowed.
                    // We must unroll or use a sequence of checks.
                    // Since depth <= 7, we can unroll:
                    // if (current_node == ancestor_node) is_ancestor = 0; // Self is not descendant (unless problem allows, but usually u != v)
                    // if (parent_idx[current_node] == ancestor_node) is_ancestor = 1;
                    // else if (parent_idx[parent_idx[current_node]] == ancestor_node) is_ancestor = 1;
                    // ...
                    // This is ugly.
                    
                    // Alternative: Use `reachability` matrix computed during Phase 1.
                    // Compute reachability[i][j].
                    // We can compute it using transitive closure or simple DFS.
                    // Since we have `parent_idx`, we can compute it.
                    // reachability[i][j] = reachability[i][parent_idx[j]] | (i == parent_idx[j]) | (i == j).
                    // This requires a topological sort order or multi-pass.
                    // 
                    // Given the constraints, let's assume we can use a `reachability` array.
                    // We compute it in VISIT state.
                    // 
                    // Let's start coding the `VISIT` state logic for Phase 1.
                    // We will use `current_node` to loop 0..7.
                    // `stack_depth` (re-purposed) as pass count.
                    
                    // To ensure we meet the requirement "Iterative state machine", let's be explicit.
                    
                    // Re-defining states for the complete solution:
                    // IDLE -> SETUP -> VISIT (Precomp) -> CHECK -> OUTPUT -> DONE
                    // We will add an internal `sub_state` or use `current_node`/`stack_depth` to manage loops.
                    
                    // VISIT Sub-state logic:
                    // 1. Find Parents (1 pass).
                    // 2. Compute Distances (7 passes).
                    // 3. Compute Reachability (8 passes).
                    // This is too many states. 
                    // 
                    // Let's trust the "200 cycles" hint. We can do a lot of work.
                    // 
                    // Let's implement the triple nested loop mentioned in requirements directly.
                    // Loop 1: `v` (ancestor) 0..7.
                    // Loop 2: `u` (descendant) 0..7.
                    // Loop 3: Find path from v to u. 
                    //   Since it's a tree, v is ancestor of u if v is on the path u->Root.
                    //   We can check this by walking u up to Root.
                    //   We need `parent_idx` to do this efficiently.
                    
                    // Let's allocate `parent_idx[7:0]` in SETUP.
                    // We can find parents by checking `child_masks`.
                    // Iterate `i` 0..7. For each `i`, check `child_masks[0]..[7]` to see who is parent.
                    // This takes 8*8 = 64 cycles. 
                    // Then we have parents.
                    
                    // Then in CHECK/UPDATE:
                    // for v in 0..7:
                    //   for u in 0..7:
                    //     dist = dist_root[u] - dist_root[v];
                    //     if (dist <= a[u]) {
                    //       // check ancestry
                    //       temp = u;
                    //       while (temp != 0 && temp != v) temp = parent_idx[temp];
                    //       if (temp == v) count[v]++;
                    //     }
                    // The while loop is the problem.
                    // We can do one step of the while loop per cycle.
                    // 
                    // Let's structure the `CHECK` and `UPDATE` states to handle the nested loops AND the ancestry check.
                    
                    // We need:
                    // `v` (ancestor, 0..7)
                    // `u` (descendant, 0..7)
                    // `temp` (node walking up from u)
                    // `walking` flag (true if we are currently walking up the tree for current v,u pair)
                    
                    // State: CHECK (start pair v,u)
                    //   Calculate dist. If dist <= a[u], set `walking`=1, `temp`=u, go to UPDATE.
                    //   Else, advance u (or v if u done), go to CHECK.
                    // State: UPDATE (walking)
                    //   If `temp` == v -> count[v]++. Advance pair.
                    //   If `temp` == 0 and `temp` != v -> Advance pair (not ancestor).
                    //   Else `temp` = parent_idx[temp]. Go to UPDATE.
                    //   (Wait, if we advance pair, we go back to CHECK).
                    
                    // This seems feasible. 
                    // We need `parent_idx` array.
                    // Let's compute `parent_idx` first. 
                    // We can do this in SETUP or first part of VISIT.
                    
                    // Let's implement `VISIT` state to compute `parent_idx` and `dist_root`.
                    // Then transition to CHECK.
                    // We will use `calc_node` as loop index.
                    // We need `parent_idx` array declared.
                    // `reg [2:0] parent_idx [7:0];`
                    // `reg [15:0] dist_root [7:0];`
                    
                    // Let's write the code for the state machine logic.
                end
            endcase
        end
    end

    // We need a comb block or logic to handle the transitions and updates for the triple loop.
    // But wait, we can't easily write loops inside always block for synthesis without indices.
    // The state machine must be controlled by indices `ancestor_node`, `current_node`, `temp_node`.
    
    // Let's redefine the states for the execution phase:
    // SETUP: Init indices, compute parents.
    //   We'll use `calc_node` (0..7) to fill `parent_idx`. 
    //   For each `calc_node`, search `child_masks[j]`.
    //   This requires a sub-loop or comb logic. Let's do a sub-loop in SETUP state.
    //   We need `temp_search` index.
    //   
    //   Logic for SETUP:
    //   `calc_node` goes 0..7.
    //   `temp_search` goes 0..7.
    //   If `child_masks[temp_search][calc_node]`, parent_idx[calc_node] = temp_search.
    //   This is fine. 64 cycles.
    //   Then compute `dist_root`.
    //   `dist_root[0] = 0`.
    //   `dist_root[i] = dist_root[parent_idx[i]] + weight(parent, i)`.
    //   This requires parents to be processed before children, or multiple passes.
    //   Let's do 7 passes after parents are found.
    //   
    //   Actually, let's combine VISIT and SETUP or just use VISIT.
    //   Let's use the `VISIT` state for all precomputation.
    //   We will use `stack_depth` as a generic counter.
    //   
    //   `VISIT` logic:
    //   Phase 1: Compute `parent_idx`. (Counter `calc_node` 0..7, `temp_search` 0..7).
    //   Phase 2: Compute `dist_root`. (Counter `stack_depth` 0..6 (passes), `calc_node` 0..7).
    //   Phase 3: Done. Transition to `CHECK`.
    //   
    //   `CHECK` Logic (Main Compute):
    //   We manage `ancestor_node` (v) and `current_node` (u).
    //   We need a `walk_node` to walk up from u.
    //   We need a state `WALKING` or reuse `CHECK`/`UPDATE`.
    //   
    //   Let's use `UPDATE` state for the walking part.
    //   `CHECK` state:
    //   If `ancestor_node` == 8, go to `OUTPUT`.
    //   Calculate `dist = dist_root[current_node] - dist_root[ancestor_node]`.
    //   If `dist <= a_values[current_node]`:
    //       Set `walk_node = current_node`.
    //       Set `walking_flag = 1`.
    //       Go to `UPDATE`.
    //   Else:
    //       Advance iterators (`current_node`++, if 8 then `ancestor_node`++, `current_node`=0).
    //       Go to `CHECK`.
    //   
    //   `UPDATE` state (Walking)
    //   If `walking_flag`:
    //       If `walk_node == ancestor_node`: 
    //           `control_count[ancestor_node]++`.
    //           `walking_flag = 0`. Advance iterators. Go to `CHECK`.
    //       Else if `walk_node == 0`: 
    //           `walking_flag = 0`. Advance iterators. Go to `CHECK`.
    //       Else:
    //           `walk_node = parent_idx[walk_node]`.
    //           Go to `UPDATE` (continue walking).
    //   Else (normal update):
    //       Advance iterators. Go to `CHECK`.
    //       (This part handles the "else" from CHECK).
    
    // Let's implement this logic in the always block.
    // We need registers: `parent_idx [7:0]`, `dist_root [7:0]`, `walking_flag`, `walk_node`, `temp_search`.

    // --- Implementation ---

    // Additional internal registers
    reg [2:0] parent_idx [7:0];
    reg walking_flag;
    reg [2:0] walk_node;
    reg [2:0] temp_search; // For searching parents
    reg [2:0] pass_counter; // For distance calculation passes

    // Helper logic for edge weight retrieval (combinational)
    wire [15:0] weight_u_v;
    // Function to get weight between u and v (where v is child of u)
    // Since inputs are flat, we map manually or use the array.
    // We pre-filled edge_weights in IDLE.
    // We need to handle symmetry or direction. 
    // The weights are given as e.g. edge_weight_01 (0->1). 
    // So edge_weights[0][1] is correct.
    // When computing dist_root[child] = dist_root[parent] + weight(parent, child).
    // We need to access edge_weights[parent][child].
    // This is valid.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            walking_flag <= 0;
            current_state <= IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    result_value <= 0;
                    result_index <= 0;
                    if (start) begin
                        // Mapping inputs (as done in previous block, keep it concise)
                        edge_weights[0][1] <= edge_weight_01; edge_weights[0][2] <= edge_weight_02;
                        edge_weights[0][3] <= edge_weight_03; edge_weights[0][4] <= edge_weight_04;
                        edge_weights[0][5] <= edge_weight_05; edge_weights[0][6] <= edge_weight_06;
                        edge_weights[0][7] <= edge_weight_07;
                        edge_weights[1][2] <= edge_weight_12; edge_weights[1][3] <= edge_weight_13;
                        edge_weights[1][4] <= edge_weight_14; edge_weights[1][5] <= edge_weight_15;
                        edge_weights[1][6] <= edge_weight_16; edge_weights[1][7] <= edge_weight_17;
                        edge_weights[2][3] <= edge_weight_23; edge_weights[2][4] <= edge_weight_24;
                        edge_weights[2][5] <= edge_weight_25; edge_weights[2][6] <= edge_weight_26;
                        edge_weights[2][7] <= edge_weight_27;
                        edge_weights[3][4] <= edge_weight_34; edge_weights[3][5] <= edge_weight_35;
                        edge_weights[3][6] <= edge_weight_36; edge_weights[3][7] <= edge_weight_37;
                        edge_weights[4][5] <= edge_weight_45; edge_weights[4][6] <= edge_weight_46;
                        edge_weights[4][7] <= edge_weight_47;
                        edge_weights[5][6] <= edge_weight_56; edge_weights[5][7] <= edge_weight_57;
                        a_values[0] <= a_0; a_values[1] <= a_1; a_values[2] <= a_2; a_values[3] <= a_3;
                        a_values[4] <= a_4; a_values[5] <= a_5; a_values[6] <= a_6; a_values[7] <= a_7;
                        
                        // Reset indices
                        calc_node <= 0;
                        temp_search <= 0;
                        pass_counter <= 0;
                        // Reset parent and dist
                        parent_idx[0] <= 0; // Root has no parent, usually 0 or self. 
                        dist_root[0] <= 0;
                        
                        current_state <= SETUP; // Start computation
                    end
                end

                SETUP: begin
                    // Phase 1: Compute Parent Indices
                    // We iterate calc_node 1..7 (skip root)
                    // We iterate temp_search 0..7 to find parent
                    // This takes 8*8 = 64 cycles. 
                    // We can optimize: Loop 1..7 for calc_node, and inside loop 0..7 for search.
                    // Since we are in SETUP, we will stay here until parents are found.
                    
                    // If calc_node == 0, move to 1.
                    if (calc_node == 0) calc_node <= 1;
                    
                    // Search logic
                    // We need to check child_masks[temp_search][calc_node]
                    // We have child_masks loaded? No, need to load them in IDLE too.
                    // Let's load them in IDLE.
                    
                    // In SETUP:
                    // If parent_idx[calc_node] is not found yet (or 0), check temp_search.
                    // Wait, we need to store child_masks.
                    // child_masks[0] = child_mask_0, etc.
                    // We did that in IDLE? No, let's do it in IDLE or beginning of SETUP.
                    // Let's assume it's done. 
                    
                    // Logic:
                    // If (child_masks[temp_search][calc_node] == 1) then parent_idx[calc_node] = temp_search.
                    // Increment temp_search.
                    // If temp_search == 8, reset temp_search, increment calc_node.
                    // If calc_node == 8, we are done with parents. Move to Distance Calc.
                    
                    if (calc_node < 8) begin
                        if (child_masks[temp_search][calc_node]) begin
                            parent_idx[calc_node] <= temp_search;
                        end
                        
                        if (temp_search == 7) begin
                            temp_search <= 0;
                            if (calc_node == 7) begin
                                // Parents done. Move to Phase 2: Distances
                                calc_node <= 1; // Start from 1 again
                                pass_counter <= 0;
                                // State transition logic handled below
                            end else begin
                                calc_node <= calc_node + 1;
                            end
                        end else begin
                            temp_search <= temp_search + 1;
                        end
                    end
                    
                    // Phase 2: Compute Distances
                    // We are still in SETUP state? No, let's use VISIT for Phase 2 to keep it clean.
                    // But let's just do it in SETUP for simplicity.
                    // We need 8 passes to propagate distances.
                    // If parents are done (calc_node == 7 && temp_search == 0 && just finished), we start passes.
                    // 
                    // Let's add a flag `phase2` to switch logic inside SETUP.
                    // 
                    // To make the code synthesizable and clean, let's stick to the state machine.
                    // We will transition to VISIT after SETUP (parents).
                    // VISIT will handle distances.
                    // Then CHECK/UPDATE.
                    
                    // Let's refine SETUP:
                    // Just parents. 
                    // If done, go to VISIT.
                    // Logic for parents:
                    // `calc_node` loops 1..7. `temp_search` loops 0..7.
                    // 
                    // We need to load child_masks. 
                    // In IDLE, we didn't load them. Let's load them in SETUP start.
                    if (calc_node == 0 && temp_search == 0) begin
                        child_masks[0] <= child_mask_0; child_masks[1] <= child_mask_1;
                        child_masks[2] <= child_mask_2; child_masks[3] <= child_mask_3;
                        child_masks[4] <= child_mask_4; child_masks[5] <= child_mask_5;
                        child_masks[6] <= child_mask_6; child_masks[7] <= child_mask_7;
                    end
                end

                VISIT: begin
                    // Compute dist_root using parents found in SETUP.
                    // We need multiple passes.
                    // Use `pass_counter` (0 to 6) and `calc_node` (1 to 7).
                    // dist_root[child] = dist_root[parent] + weight(parent, child).
                    // 
                    // Since we are in VISIT, we perform one update per cycle.
                    // Loop `pass_counter` 0..6.
                    // Inside, loop `calc_node` 1..7.
                    // Update if parent is valid.
                    // Note: We don't have dist_root[parent] ready immediately if we iterate linear order.
                    // But multiple passes ensure propagation.
                    
                    // Logic:
                    // If (pass_counter < 7):
                    //   If (calc_node <= 7):
                    //     p = parent_idx[calc_node];
                    //     w = edge_weights[p][calc_node];
                    //     dist_root[calc_node] = dist_root[p] + w;
                    //     (This assumes dist_root[p] is updated in previous pass or is 0).
                    //   Increment calc_node.
                    //   If calc_node > 7, reset calc_node, increment pass_counter.
                    //   If pass_counter >= 7, go to CHECK.
                    
                    // Since dist_root is updated, we can do it in one pass if we iterate in topological order.
                    // But we don't have topological order guaranteed.
                    // 8 passes is safe.
                    
                    // Wait, we need to map edge_weights indices correctly.
                    // Edge weights are defined for i->j where i<j? No, inputs are arbitrary pairs.
                    // We mapped them to `edge_weights[i][j]`.
                    // We need to ensure we access `edge_weights[parent_idx[calc_node]][calc_node]`.
                    // This is valid.
                    
                    if (pass_counter < 8) begin // 8 passes
                        if (calc_node == 0) calc_node <= 1;
                        
                        if (calc_node <= 7) begin
                            // Update dist
                            // Check if parent_idx[calc_node] is valid (root is 0)
                            // dist_root[calc_node] <= dist_root[parent_idx[calc_node]] + edge_weights[parent_idx[calc_node]][calc_node];
                            // 
                            // However, `edge_weights` indexing: 
                            // We loaded edge_weights[0][1], etc. 
                            // If parent_idx[calc_node] is p, child is c.
                            // `edge_weights[p][c]`.
                            // This is fine.
                            
                            // Safety: Check if edge weight exists. We loaded all inputs.
                            dist_root[calc_node] <= dist_root[parent_idx[calc_node]] + edge_weights[parent_idx[calc_node]][calc_node];
                            
                            calc_node <= calc_node + 1;
                        end else begin
                            calc_node <= 1;
                            pass_counter <= pass_counter + 1;
                            if (pass_counter == 7) begin
                                current_state <= CHECK;
                                ancestor_node <= 0;
                                current_node <= 0;
                                walking_flag <= 0;
                            end
                        end
                    end
                end

                CHECK: begin
                    // Check condition for pair (ancestor_node, current_node)
                    // dist = dist_root[current_node] - dist_root[ancestor_node]
                    // If current_node == ancestor_node, skip (v controls u, usually u != v? Or dist 0 <= a[u]? Dist(v,v)=0. Usually included? "u in v's subtree" - usually u != v. But root is in root's subtree? Let's assume u != v or check definition. "dist(v,u) <= a_u". If u=v, dist=0. Usually we count descendants. Let's skip if u==v). 
                    // If current_node == ancestor_node, go to UPDATE (which will advance).
                    
                    if (ancestor_node >= 8) begin
                        current_state <= OUTPUT;
                        output_counter <= 0;
                        result_index <= 0;
                        result_value <= control_count[0]; // Pre-load first output
                        done <= 0;
                    end else begin
                        // Calculate distance
                        // We need to know if current_node is descendant.
                        // We will use the WALK logic in UPDATE.
                        // In CHECK, we just setup the walk.
                        
                        // If current_node == ancestor_node, just advance.
                        if (current_node == ancestor_node) begin
                            // Advance iterators
                            if (current_node == 7) begin
                                current_node <= 0;
                                ancestor_node <= ancestor_node + 1;
                            end else begin
                                current_node <= current_node + 1;
                            end
                        end else begin
                            // Check distance validity first to save time
                            // dist_root[current_node] must be >= dist_root[ancestor_node] (ancestor must be closer to root)
                            // Actually, if ancestor_node is NOT ancestor, dist_root might be smaller but nodes unrelated.
                            // But we will verify ancestry via walk.
                            
                            // We need to perform the walk to check ancestry AND distance.
                            // Wait, we can check distance BEFORE walking.
                            // If (dist_root[current_node] - dist_root[ancestor_node] <= a_values[current_node]) {
                            //    Start Walk.
                            // } else {
                            //    Advance.
                            // }
                            
                            // Note: We need to ensure we don't overflow. dist_root is 16-bit.
                            // Since it's a tree, if ancestor_node is NOT ancestor, we shouldn't count it anyway.
                            // But if we check distance first, we might get a negative or wrong number.
                            // Let's do the WALK in UPDATE state.
                            // We will set `walking_flag = 1` and `walk_node = current_node` in CHECK.
                            // Then in UPDATE, we walk up.
                            // While walking, we track distance from ancestor.
                            // 
                            // Actually, let's pass `distance_so_far` down.
                            // In CHECK: start `distance_so_far = 0`. `walk_node = current_node`.
                            // In UPDATE: 
                            //   If `walk_node` == `ancestor_node`: Check `distance_so_far` against `a[ancestor_node]`? No, against `a[current_node]`.
                            //   Wait. `dist(v,u)` is distance from v to u.
                            //   We are walking from u up to v.
                            //   We need to accumulate weight.
                            //   
                            //   Revised UPDATE logic for walk:
                            //   Start with `walk_node = current_node`, `walk_dist = 0`.
                            //   In UPDATE:
                            //     If `walk_node` == `ancestor_node`: 
                            //       Check `walk_dist` (which is dist(u,v)) <= `a_values[current_node]`.
                            //       If yes, increment `control_count[ancestor_node]`.
                            //       Advance iterators. Go to CHECK.
                            //     Else if `walk_node` == 0: 
                            //       (Reached root without hitting ancestor).
                            //       Advance iterators. Go to CHECK.
                            //     Else:
                            //       p = parent_idx[walk_node];
                            //       walk_dist += edge_weights[p][walk_node];
                            //       walk_node = p;
                            //       Go to UPDATE.
                            // 
                            // This is perfect. It calculates dist on the fly and checks ancestry.
                            // We need `walk_dist` register.
                            
                            // Transition to UPDATE to start walking.
                            walking_flag <= 1;
                            walk_node <= current_node;
                            walk_dist <= 0;
                            current_state <= UPDATE;
                        end
                    end
                end

                UPDATE: begin
                    // Walking logic
                    if (walking_flag) begin
                        if (walk_node == ancestor_node) begin
                            // Found ancestor. Check distance.
                            if (walk_dist <= a_values[current_node]) begin
                                control_count[ancestor_node] <= control_count[ancestor_node] + 1;
                            end
                            // Done with this pair
                            walking_flag <= 0;
                            // Advance iterators
                            if (current_node == 7) begin
                                current_node <= 0;
                                ancestor_node <= ancestor_node + 1;
                            end else begin
                                current_node <= current_node + 1;
                            end
                            current_state <= CHECK;
                        end else if (walk_node == 0) begin
                            // Reached root, ancestor not found
                            walking_flag <= 0;
                            if (current_node == 7) begin
                                current_node <= 0;
                                ancestor_node <= ancestor_node + 1;
                            end else begin
                                current_node <= current_node + 1;
                            end
                            current_state <= CHECK;
                        end else begin
                            // Walk up one step
                            // p = parent_idx[walk_node]
                            // walk_dist += edge_weights[p][walk_node]
                            // walk_node = p
                            // Check edge weight existence (we mapped all)
                            walk_dist <= walk_dist + edge_weights[parent_idx[walk_node]][walk_node];
                            walk_node <= parent_idx[walk_node];
                            current_state <= UPDATE; // Continue walking
                        end
                    end else begin
                        // Should not happen if logic correct, but fallback
                        current_state <= CHECK;
                    end
                end

                OUTPUT: begin
                    // Stream out results
                    // result_index cycles 0 to 7
                    // result_value = control_count[result_index]
                    
                    result_value <= control_count[output_counter];
                    result_index <= output_counter;
                    
                    if (output_counter == 7) begin
                        done <= 1;
                        current_state <= DONE;
                    end else begin
                        output_counter <= output_counter + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for reset or new start
                end
            endcase
        end
    end

endmodule
