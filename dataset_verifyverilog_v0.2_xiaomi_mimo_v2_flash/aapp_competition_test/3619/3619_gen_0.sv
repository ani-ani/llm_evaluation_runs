module optimal_team_selector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_valid,
    input wire [3:0] node_id,      // 1..12
    input wire [3:0] parent_id,    // 0..11 (0 is CEO)
    input wire [11:0] salary,
    input wire [11:0] productivity,
    output reg [31:0] max_ratio_q16_16,
    output reg done
);

    // Parameters
    parameter N = 12;
    parameter K = 6;
    parameter M = 4;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD_DATA = 3'b001;
    localparam BINARY_SEARCH = 3'b010;
    localparam DP_COMPUTE = 3'b011;
    localparam CHECK_RESULT = 3'b100;
    localparam DONE = 3'b101;

    // Registers and Wires
    reg [2:0] current_state, next_state;
    
    // Tree Data Storage (1-based indexing for nodes, 0 is root)
    reg [11:0] salary_reg [0:N];
    reg [11:0] productivity_reg [0:N];
    reg [3:0] parent_reg [0:N];
    reg node_loaded [0:N];
    
    // Tracking loaded nodes
    reg [3:0] load_count;
    
    // Binary Search Registers
    reg [31:0] low;  // Q16.16
    reg [31:0] high; // Q16.16
    reg [31:0] mid;  // Q16.16
    reg [4:0] iteration_count; // 16 iterations needed for 16 bits
    
    // DP Storage
    // dp[node][count] stores max value. Count 0..K.
    // We use K+1 = 7.
    reg signed [31:0] dp_val [0:N][0:K];
    reg signed [31:0] temp_dp [0:K]; // For merging children
    
    // DP Control
    reg [3:0] node_idx; // Current node being processed in DP
    reg [3:0] child_idx; // Current child being merged
    reg [3:0] child_ptr; // Pointer to iterate children
    reg signed [31:0] weight_val; // p - R*s
    reg signed [63:0] mul_temp; // Intermediate multiplication
    
    // Constraints & Logic
    reg root_child_selected; // Flag to check if any child of root is in selection
    reg signed [31:0] current_max_val;
    
    // Helper to find children
    // Since M is small and N is small, we can iterate 1..N to find children
    // or store adjacency list. Iterating 1..N is simpler for this scale.
    reg [3:0] scan_idx;
    reg signed [31:0] dp_child [0:K];
    
    integer i, j, k;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_DATA;
            end
            LOAD_DATA: begin
                // Wait for all 12 nodes (assuming input order or check loaded flags)
                // We assume we load exactly N nodes.
                // If node_id 0 is CEO, we ignore data for it or treat as dummy.
                // Requirements say CEO is node 0 implicit, candidates 1..n.
                // We will assume data for 1..N is fed.
                if (load_count == N) next_state = BINARY_SEARCH;
            end
            BINARY_SEARCH: begin
                // 16 iterations. But wait, fixed point logic:
                // We iterate until low >= high (or specific precision).
                // Requirement says "Iterate 16 iterations".
                // Let's stick to 16 iterations for simplicity and range coverage.
                if (iteration_count >= 16) next_state = DP_COMPUTE; // Done searching, use best found? 
                // Actually, standard binary search: we check condition.
                // But here we need to run DP for each mid.
                // The DP_COMPUTE state will be invoked inside the binary search loop.
                // Wait, the prompt implies a state structure where BINARY_SEARCH calculates mid, 
                // and DP_COMPUTE runs for that mid. So BINARY_SEARCH -> DP_COMPUTE -> CHECK_RESULT -> BINARY_SEARCH.
                // Let's refine:
                if (iteration_count < 16) next_state = DP_COMPUTE;
                else next_state = CHECK_RESULT; // 16 iterations done
            end
            DP_COMPUTE: begin
                // Needs to process all nodes.
                // Simplest traversal: process nodes 1..N in reverse order (leaves to root)
                // Since it's a tree (or forest with root 0), reverse order usually works if parents < children
                // or we need explicit topological sort. We will scan nodes N downto 1.
                // We need to iterate children for each node. This takes multiple cycles.
                // We will implement a mini-sequencer.
                // For now, assume a coarse loop:
                // If finished all nodes, go to CHECK.
                // But CHECK is part of the binary search loop.
                // Let's assume DP_COMPUTE takes N * M cycles roughly.
                // We will use a 'dp_done' flag internal to this state.
                // If dp_done, go to CHECK_RESULT.
                if (dp_done_signal) next_state = CHECK_RESULT;
                else next_state = DP_COMPUTE;
            end
            CHECK_RESULT: begin
                // Check if valid (root constraint). Update high/low.
                // If iteration_count < 16, go back to BINARY_SEARCH.
                // If iteration_count == 16, go to DONE.
                if (iteration_count < 16) next_state = BINARY_SEARCH;
                else next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    reg dp_done_signal;
    reg [3:0] dp_node_ptr; // 1..N
    reg [2:0] dp_child_scan_state; 
    reg [3:0] scan_child_idx;
    
    // For DP merging loops
    integer c1, c2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            load_count <= 0;
            iteration_count <= 0;
            done <= 0;
            max_ratio_q16_16 <= 0;
            low <= 0;
            high <= 32'h0FFF0000; // Max possible ratio 4095 << 16
            // Clear loaded flags
            for (i=0; i<N; i=i+1) node_loaded[i] <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    load_count <= 0;
                    iteration_count <= 0;
                    done <= 0;
                    // Initialize high based on max possible ratio (4095) * 2^16
                    high <= 32'h0FFF0000; 
                    low <= 0;
                end

                LOAD_DATA: begin
                    if (data_valid) begin
                        // node_id 0 is CEO (root). We might not get data for it, or ignore.
                        // We store data for nodes 1..12.
                        if (node_id >= 1 && node_id <= N) begin
                            salary_reg[node_id] <= salary;
                            productivity_reg[node_id] <= productivity;
                            parent_reg[node_id] <= parent_id;
                            node_loaded[node_id] <= 1'b1;
                            load_count <= load_count + 1;
                        end
                    end
                end

                BINARY_SEARCH: begin
                    // Calculate Mid
                    mid <= (low >> 1) + (high >> 1);
                    // If low[0] && high[0], add 1 to avoid truncation bias? 
                    // Standard integer binary search: mid = (low+high)/2.
                    // Since these are Q16.16, addition is fine.
                    mid <= (low + high) >> 1;
                    // Reset DP state
                    dp_node_ptr <= N;
                    dp_done_signal <= 0;
                    dp_child_scan_state <= 0;
                end

                DP_COMPUTE: begin
                    // We process nodes from N down to 1.
                    // For each node:
                    // 1. Calculate weight (p - R*s)
                    // 2. Init dp[node][1] = weight, dp[node][0] = 0, others = -inf
                    // 3. Merge children
                    
                    if (dp_node_ptr >= 1) begin
                        case (dp_child_scan_state)
                            0: begin // Initialize DP for this node
                                // weight = (productivity << 16) - (mid * salary)
                                // mid is Q16.16, salary is int. Mul -> Q16.16.
                                mul_temp <= mid * salary_reg[dp_node_ptr];
                                // Wait for multiplication or do in next cycle? Verilog handles combinational mul.
                                // We need to wait 1 cycle for registered output usually, or use combo logic.
                                // Let's use a registered approach.
                                dp_child_scan_state <= 1;
                                
                                // Initialize DP array for this node
                                // dp[dp_node_ptr][0] = 0;
                                // dp[dp_node_ptr][1] = weight;
                                // others = -infinity (e.g., 32'h80000000)
                                for (int k = 0; k <= K; k = k + 1) begin
                                    dp_val[dp_node_ptr][k] <= (k == 0) ? 0 : 32'h80000000;
                                end
                            end
                            1: begin // Calculate weight
                                // weight = (productivity << 16) - mul_temp
                                // Sign extend to 64 bits for safety then truncate
                                // Or just 32-bit arithmetic since inputs are small enough.
                                // Max P: 4095 << 16 = 0x00FF0000
                                // Max R*S: 4095 * 4095 << 16 = ~0x0FFF_FFFF (oops, too big)
                                // 4095 * 4095 = 16M. Fits in 24 bits. 
                                // So (P << 16) fits in 28 bits. (R*S) fits in 48 bits if R is Q16.16.
                                // R is 0..4095. 4095<<16 = 0x0FFF0000. 
                                // S is 0..4095.
                                // Product: 0x0FFF0000 * 4095 = ~0x0FFF_FFFF_FFFF. Fits in 64 bits.
                                weight_val <= (productivity_reg[dp_node_ptr] <<< 16) - $signed(mul_temp);
                                
                                // Apply weight to dp[1]
                                // We want to ADD weight to dp[1] if we pick the node itself.
                                // Current dp[1] is -inf (init). We set it to weight.
                                // But wait, dp[1] represents picking exactly 1 node in subtree.
                                // If we pick the node itself, it's weight.
                                // If we pick only children (not possible for count 1 unless child subtree has count 1, but node must be picked if children are picked? No, constraint is parent picked -> child picked.
                                // Actually, standard tree knapsack:
                                // 1. Include Node: Add weight, then merge children allowing 0..K-1 picks from children.
                                // 2. Exclude Node: Not allowed if parent is picked? 
                                // Here we are computing bottom-up. 
                                // If parent picks this node, this node gets value.
                                // We compute best values for this subtree.
                                // Let's assume we compute "If this node is picked".
                                // But actually, the DP table stores max value for exactly 'c' nodes in the subtree, 
                                // subject to the constraint that if we pick nodes, the tree structure is valid.
                                // Wait, the problem says: "A node can only be picked if its parent is picked."
                                // This implies we are calculating the gain of picking a subtree rooted at this node.
                                // However, bottom-up DP usually calculates: 
                                // dp[u][c] = max value of picking c nodes in subtree of u, assuming u is picked (or not).
                                // Let's use a common approach: 
                                // dp[u][c] = max value of picking c nodes in subtree of u.
                                // Transitions:
                                // 1. We pick u. Then we must pick children if we want to pick nodes in child subtrees.
                                // 2. We don't pick u. Then we pick 0 nodes from this subtree.
                                // But the constraint is dependency. If we pick u, we can pick children.
                                // If we don't pick u, we cannot pick any descendants.
                                // So dp[u][0] = 0 (don't pick u).
                                // dp[u][c>0] = weight(u) + sum over children of max value for picking some nodes.
                                // This is the "Tree Knapsack".
                                
                                // Let's refine DP State: dp[u][c] = max score for picking c nodes in subtree of u.
                                // Transition:
                                // Initialize temp dp array for this node.
                                // temp[0] = 0 (not picking node u)
                                // temp[1...K] = -inf
                                // Then, process children:
                                // For each child v:
                                //   new_temp[k] = max(new_temp[k], new_temp[k-j] + dp[v][j]) for j=1..K
                                // Finally, add node u's weight to all non-zero counts:
                                // dp[u][k] = new_temp[k] + weight(u) for k>=1.
                                // Wait, this allows picking children without parent? No, because we add weight(u) to ALL k>=1.
                                // So if we pick k nodes in total, we MUST include u (weight added) and k-1 nodes from children.
                                // But what if we don't pick u? That is covered by k=0.
                                // So dp[u][k] (for k>=1) represents picking u and k-1 nodes from children.
                                // Is that correct?
                                // If we pick u, we must pick u. So value includes weight(u).
                                // Then we distribute (k-1) nodes among children.
                                // Yes, this works.
                                
                                // We are in state 1. We calculated weight_val.
                                // We need to initialize the temporary buffer for this node to start merging children.
                                // Initially, before merging children, if we pick the node, we have picked 1 node (the node itself).
                                // But we haven't merged children yet.
                                // So let's set up the merge buffer.
                                // buf[0] = 0 (case where we don't pick the node - but wait, we will add weight later)
                                // Let's do it in the child merging phase.
                                
                                // Let's restart the logic for clarity.
                                // State 1: Set up merge buffer.
                                // buf[0] = 0. buf[1..K] = -inf.
                                // Then go to State 2 (Merge Children).
                                // After merging all children, State 3 (Add Node Weight).
                                
                                for (int k = 0; k <= K; k = k + 1) temp_dp[k] <= (k==0) ? 0 : 32'h80000000;
                                
                                // Find first child index
                                scan_child_idx <= 1;
                                dp_child_scan_state <= 2; // Go to child merge loop
                            end
                            
                            2: begin // Iterate children and merge
                                // Check if scan_child_idx <= N
                                if (scan_child_idx <= N) begin
                                    // Check if scan_child_idx is child of dp_node_ptr
                                    if (node_loaded[scan_child_idx] && parent_reg[scan_child_idx] == dp_node_ptr) begin
                                        // Merge child scan_child_idx into temp_dp
                                        // Standard knapsack merge (reverse order to avoid using same item twice)
                                        // We are merging the child's DP table into the current node's accumulator.
                                        // child's dp is in dp_val[scan_child_idx][j]
                                        // accumulator is temp_dp[k]
                                        // new_val[k] = max(temp_dp[k], temp_dp[k-j] + dp_val[child][j])
                                        
                                        // Since K is small (6), we can unroll or do a small loop.
                                        // Use a nested loop for merging. 
                                        // Since we are in a sequential block, we might want to do this over multiple cycles or unroll.
                                        // To save space and ensure correct behavior, let's use a sub-state for the inner loop.
                                        // But verilog allows generate loops? No, not inside always block.
                                        // We can do it in one cycle if we wire up a small adder tree, but let's be safe.
                                        // Let's assume we do one child merge per cycle (or few cycles).
                                        // Actually, since N=12, K=6, we can just do the inner loops unrolled in one cycle.
                                        
                                        for (c1 = K; c1 >= 1; c1 = c1 - 1) begin
                                            for (c2 = 1; c2 <= c1; c2 = c2 + 1) begin
                                                if (dp_val[scan_child_idx][c2] > 32'h80000000) begin
                                                    if (temp_dp[c1 - c2] > 32'h80000000) begin
                                                        if ($signed(temp_dp[c1]) < $signed(temp_dp[c1 - c2] + dp_val[scan_child_idx][c2])) begin
                                                            temp_dp[c1] <= temp_dp[c1 - c2] + dp_val[scan_child_idx][c2];
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        
                                        scan_child_idx <= scan_child_idx + 1;
                                    end else begin
                                        // Not a child, check next
                                        scan_child_idx <= scan_child_idx + 1;
                                    end
                                end else begin
                                    // All children merged
                                    dp_child_scan_state <= 3;
                                end
                            end
                            
                            3: begin // Add Node Weight to finalize dp for this node
                                // dp[node][k] = temp_dp[k] + weight_val, for k >= 1
                                // dp[node][0] remains 0 (not picking node)
                                // Wait, temp_dp[0] is 0. If we pick 0 nodes, value is 0.
                                // If we pick 1 node, temp_dp[1] might be -inf (no children picked) or from children.
                                // Actually, picking node itself counts as 1 node.
                                // So we need to shift.
                                // Standard logic: dp[u][k] = max(0, weight + max_{child distr} sum)
                                // But we want exactly k nodes in subtree.
                                // If we pick the node, we have 1 node already. So we need k-1 from children.
                                // So dp[u][k] = weight + temp_dp[k-1]
                                // dp[u][0] = 0.
                                
                                dp_val[dp_node_ptr][0] <= 0;
                                for (int k = 1; k <= K; k = k + 1) begin
                                    if (temp_dp[k-1] > 32'h80000000) 
                                        dp_val[dp_node_ptr][k] <= temp_dp[k-1] + weight_val;
                                    else 
                                        dp_val[dp_node_ptr][k] <= 32'h80000000;
                                end
                                
                                // Next node
                                dp_node_ptr <= dp_node_ptr - 1;
                                dp_child_scan_state <= 0;
                                
                                if (dp_node_ptr == 1) dp_done_signal <= 1;
                            end
                        endcase
                    end else begin
                        // Should not reach here if dp_node_ptr logic is correct
                        dp_done_signal <= 1;
                    end
                end

                CHECK_RESULT: begin
                    // We have finished DP for current 'mid'.
                    // Check if there exists a valid selection satisfying root constraint.
                    // Root constraint: Must select at least one child of CEO (node 0).
                    // CEO's children are nodes where parent_reg[i] == 0.
                    // We need to combine results from these children.
                    // We want to maximize sum of values.
                    // We need to select at least one node from the set of children of root.
                    // Since the root is not counted in the team size, we just sum up from children.
                    // The children are disjoint subtrees (assuming tree).
                    // We need to pick a total of k nodes (1..K) from the union of children subtrees.
                    // And we must pick at least 1 node.
                    
                    // Let's compute a temporary 'root_dp[k]' for the union of root's children.
                    // root_dp[k] = max score picking k nodes from children of root.
                    // Initialize root_dp[0] = 0, others = -inf.
                    // For each child v of root:
                    //   merge root_dp with dp[v] (knapsack).
                    //   NOTE: We don't add weight of root because root is implicit.
                    //   Also, root is not in the tree DP, so children act as independent trees.
                    //   However, the root constraint says "Must select at least one child".
                    //   If we merge all children, root_dp[k] allows picking k nodes from children.
                    //   If root_dp[k] > 0 for any k >= 1, then we have a valid solution?
                    //   No, we want to check if (sum(p) - R*sum(s)) > 0.
                    //   So we want max(root_dp[k]) > 0 for any k >= 1.
                    
                    // Let's perform this merge in CHECK_RESULT state (since it's fast).
                    // Or reuse temp_dp.
                    
                    if (!root_child_selected) begin
                        // First cycle of CHECK_RESULT: Compute root_dp
                        // Reset temp_dp
                        for (int k=0; k<=K; k=k+1) temp_dp[k] <= (k==0) ? 0 : 32'h80000000;
                        scan_child_idx <= 1;
                        root_child_selected <= 1'b1; // Flag to proceed to next step
                    end else begin
                        // We need a sub-state here to iterate children or do it in one go.
                        // Let's just do it in one go since N is small.
                        // Wait, CHECK_RESULT is a state. We can iterate scan_child_idx.
                        // Let's refine the control flow for CHECK_RESULT.
                        
                        // Actually, let's simplify. 
                        // The prompt says: "Iterate R from 0 to 4095... for 12-bit search range."
                        // "16 iterations". 
                        // "Iterate 16 iterations of binary search".
                        // So we do 16 fixed iterations. 
                        // In BINARY_SEARCH, we calculated mid.
                        // In DP_COMPUTE, we computed dp_val for all nodes.
                        // In CHECK_RESULT, we verify validity and update low/high.
                        // But we haven't computed root_dp yet.
                        
                        // Let's compute root_dp inside CHECK_RESULT.
                        // Since we are inside 'always' block, we need state variables.
                        // Let's use 'scan_child_idx' and 'scan_state'.
                        
                        // If we are at the start of CHECK_RESULT (newly entered), reset.
                        // But we already used root_child_selected flag above.
                        // Let's reset it at BINARY_SEARCH.
                        // So in CHECK_RESULT:
                        // if (scan_child_idx == 0) initialize temp_dp and set scan_child_idx = 1.
                        // else if (scan_child_idx <= N) check child.
                        // else go to update logic.
                    end
                end
            endcase
        end
    end

    // Separate logic for CHECK_RESULT to handle sequential scan and update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // done
        end else begin
            if (current_state == BINARY_SEARCH) begin
                // Reset checker state
                root_child_selected <= 0; // Use this as 'checker started' flag
                scan_child_idx <= 0;
            end
            
            if (current_state == CHECK_RESULT) begin
                // Logic to merge children of root into temp_dp
                // We need to find max valid score.
                
                if (scan_child_idx == 0) begin
                    // Init
                    for (int k=0; k<=K; k=k+1) temp_dp[k] <= (k==0) ? 0 : 32'h80000000;
                    scan_child_idx <= 1;
                end else if (scan_child_idx <= N) begin
                    // Check if child of root
                    if (node_loaded[scan_child_idx] && parent_reg[scan_child_idx] == 0) begin
                        // Merge dp_val[scan_child_idx] into temp_dp
                        for (c1 = K; c1 >= 1; c1 = c1 - 1) begin
                            for (c2 = 1; c2 <= c1; c2 = c2 + 1) begin
                                if (dp_val[scan_child_idx][c2] > 32'h80000000) begin
                                    if (temp_dp[c1 - c2] > 32'h80000000) begin
                                        if ($signed(temp_dp[c1]) < $signed(temp_dp[c1 - c2] + dp_val[scan_child_idx][c2])) begin
                                            temp_dp[c1] <= temp_dp[c1 - c2] + dp_val[scan_child_idx][c2];
                                        end
                                    end
                                end
                            end
                        end
                    end
                    scan_child_idx <= scan_child_idx + 1;
                end else begin
                    // Finished merging. Check max valid score.
                    // Valid if we picked at least 1 node. 
                    // But temp_dp[k] includes selection of k nodes.
                    // We need to check if any temp_dp[k] > 0 for k >= 1.
                    // Actually, the condition for binary search is: 
                    // sum(p_i) - R * sum(s_i) > 0.
                    // So we want max_score > 0.
                    // max_score = max over k=1..K of temp_dp[k].
                    
                    current_max_val <= 32'h80000000;
                    // Unroll max finding
                    for (int k=1; k<=K; k=k+1) begin
                        if ($signed(temp_dp[k]) > $signed(current_max_val)) begin
                            current_max_val <= temp_dp[k];
                        end
                    end
                    
                    // Update Binary Search Bounds
                    // if current_max_val > 0, then R is feasible, try higher (low = mid + 1)
                    // else try lower (high = mid - 1)
                    // Note: mid is Q16.16. Low/High are Q16.16.
                    // We should add/subtract 1 to mid. But mid is (low+high)/2.
                    // We need to be careful with integer division.
                    // Standard update:
                    // if (valid && max > 0) low = mid + 1;
                    // else high = mid - 1;
                    
                    // But wait, if valid == false (no selection), we treat as max <= 0.
                    
                    if ($signed(current_max_val) > 0 && scan_child_idx > N) begin // scan_child_idx > N implies valid check done
                        low <= mid + 1;
                    end else begin
                        high <= mid - 1;
                    end
                    
                    iteration_count <= iteration_count + 1;
                    
                    // Reset flag for next iteration
                    root_child_selected <= 0;
                end
            end
            
            if (current_state == DONE) begin
                // The result is stored in 'low'.
                // Binary search invariant: low is the best feasible R.
                // Or we might want to use 'high'. 
                // Since we increment 'low' when valid, 'low' ends up being the first invalid or best valid?
                // Standard binary search for max R such that valid(R):
                // while(low <= high) {
                //    mid = (l+h)/2;
                //    if (valid(mid)) l = mid+1;
                //    else h = mid-1;
                // }
                // Result is h.
                // So we should output 'high'.
                // However, we updated 'high' inside CHECK_RESULT.
                // And we checked 'iteration_count' to exit.
                // So we need to capture the final 'high'.
                // But 'high' was updated in the last cycle of CHECK_RESULT.
                // We need to ensure we store it.
                // Actually, in the last iteration, CHECK_RESULT updates low/high.
                // Then next state is CHECK_RESULT (checks iter < 16), fails, goes to DONE.
                // So 'high' holds the best feasible value.
                // Wait, if we do 16 iterations, we start iter=0, end iter=16.
                // Iter 0..15 (16 times). 
                // So on iter 15, we update. Then iter becomes 16.
                // Next cycle state goes to CHECK_RESULT -> checks iter < 16 -> false -> DONE.
                // So 'high' is correct.
                
                // One nuance: We want the ratio in Q16.16.
                // 'high' is the ratio. 
                // But we want max ratio. 
                // The algorithm finds the boundary. 
                // If high is valid, then it's the answer. 
                // If high is slightly low, we might be off by 1.
                // Given the requirements, output high.
                
                // Let's verify the update logic:
                // if (max > 0) low = mid + 1. 
                // This means mid is valid. We try higher.
                // else high = mid - 1. mid is invalid. We try lower.
                // So at the end, 'high' is the last value known to be valid (or close to it).
                // Actually, if 'mid' is valid, 'low' becomes mid+1. 'high' stays same (or updates later).
                // If 'mid' is invalid, 'high' becomes mid-1. 'low' stays same.
                // At the end, 'low' > 'high'. The answer is 'high'.
                
                max_ratio_q16_16 <= high;
                done <= 1;
            end
        end
    end

endmodule
