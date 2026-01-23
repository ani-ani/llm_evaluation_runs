module joke_party(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [127:0] V_packed,
    input [511:0] adj_packed,
    output reg [31:0] result,
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam PARSE = 3'b001;
    localparam CHECK_SUBSETS = 3'b010;
    localparam COUNT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Internal memory
    reg [3:0] V [0:7]; // 4-bit type per node (1-16)
    reg [0:7] adj [0:7]; // Adjacency matrix (row-major)
    
    // Subset iteration
    reg [7:0] mask;
    reg [7:0] valid_mask; // tracks validity of current mask
    
    // Checkers
    reg [7:0] node_idx;
    reg parent_fail;
    reg dup_fail;
    reg consec_fail;
    
    // Temporary storage for duplicates and consecutive checks
    reg [15:0] type_seen;
    reg [15:0] min_val;
    reg [15:0] max_val;
    reg [3:0] count_in_subtree;
    
    // Tree traversal
    reg [2:0] queue [0:7]; // Simple queue for DFS
    reg [2:0] q_head;
    reg [2:0] q_tail;
    reg [2:0] curr_node;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            mask <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PARSE;
                        result <= 0;
                    end
                end

                PARSE: begin
                    // Parse inputs
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            V[i] <= V_packed[i*8 +: 4]; // Only lower 4 bits needed (1-16)
                            for (j = 0; j < 8; j = j + 1) begin
                                adj[i][j] <= adj_packed[i*8 + j];
                            end
                        end else begin
                            V[i] <= 0;
                            for (j = 0; j < 8; j = j + 1) adj[i][j] <= 0;
                        end
                    end
                    mask <= 8'b1; // Start with mask 1 (bit 0 set)
                    state <= CHECK_SUBSETS;
                end

                CHECK_SUBSETS: begin
                    if (mask < (8'b1 << N)) begin
                        // Initialize validity check
                        valid_mask <= mask;
                        parent_fail <= 0;
                        dup_fail <= 0;
                        consec_fail <= 0;
                        type_seen <= 16'b0;
                        node_idx <= 0;
                        state <= COUNT; // Use COUNT state for checks
                    end else begin
                        state <= DONE;
                    end
                end

                COUNT: begin
                    // This state handles all validity checks for the current mask
                    
                    // 1. Parent Constraint Check (Sequential)
                    if (!parent_fail && !dup_fail && !consec_fail) begin
                        if (node_idx < N) begin
                            if (mask[node_idx]) begin
                                // Check parents (assuming sorted indices imply parent index < child)
                                // We need to find the parent. Adjacency matrix definition required.
                                // Assuming adj[i][j] == 1 means j is child of i (row i, col j)
                                // OR adj[i][j] == 1 means j is parent of i.
                                // Let's assume adj[parent][child] = 1.
                                // A node i has parent p if adj[p][i] == 1.
                                // We search for p < i.
                                for (integer k = 0; k < N; k = k + 1) begin
                                    if (adj[k][node_idx]) begin // found parent k
                                        if (!mask[k]) parent_fail <= 1;
                                    end
                                end
                            end
                            node_idx <= node_idx + 1;
                        end else begin
                            // Done parent check, move to duplicates check
                            node_idx <= 0;
                            if (parent_fail) begin
                                // Invalid, skip to next mask
                                state <= CHECK_SUBSETS;
                                mask <= mask + 1;
                            end
                        end
                    end
                    
                    // 2. Duplicate & Consecutive Checks (Executed if Parent check passed or done)
                    // We split logic. If parent_fail, we jump. Else we check dup/consec.
                    // To avoid state explosion, we combine dup/consec checks.
                    
                    // Logic refinement: Sequential checks in one state is messy in Verilog always block.
                    // Let's use auxiliary state flags or nested ifs.
                    
                    // Let's restart the logic for COUNT state properly.
                end
            endcase
        end
    end

    // Re-implementing logic cleanly in a single always block with sub-steps inside COUNT state
    // The previous COUNT logic was incomplete for sequential processing.
    // Let's use a helper counter to drive the sequential checks within the COUNT state.
    
    reg [2:0] sub_step;
    reg [2:0] k_idx; // for loops
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            mask <= 8'b0;
            sub_step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PARSE;
                        result <= 0;
                    end
                end

                PARSE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            V[i] <= V_packed[i*8 +: 4];
                            for (j = 0; j < 8; j = j + 1) begin
                                adj[i][j] <= adj_packed[i*8 + j];
                            end
                        end
                    end
                    mask <= 8'b1;
                    sub_step <= 0;
                    state <= CHECK_SUBSETS;
                end

                CHECK_SUBSETS: begin
                    if (mask < (8'b1 << N)) begin
                        // Reset check variables
                        parent_fail <= 0;
                        dup_fail <= 0;
                        consec_fail <= 0;
                        type_seen <= 16'b0;
                        min_val <= 16'hFFFF;
                        max_val <= 16'b0;
                        count_in_subtree <= 0;
                        node_idx <= 0;
                        k_idx <= 0;
                        sub_step <= 0; // Step 0: Parent Check
                        state <= COUNT;
                    end else begin
                        state <= DONE;
                    end
                end

                COUNT: begin
                    case (sub_step)
                        0: begin // Parent Constraint
                            if (!parent_fail && node_idx < N) begin
                                if (mask[node_idx]) begin
                                    // Find parent
                                    if (k_idx < N) begin
                                        if (adj[k_idx][node_idx] && !mask[k_idx]) parent_fail <= 1;
                                        k_idx <= k_idx + 1;
                                    end else begin
                                        node_idx <= node_idx + 1;
                                        k_idx <= 0;
                                    end
                                end else begin
                                    node_idx <= node_idx + 1;
                                end
                            end else if (node_idx >= N) begin
                                if (parent_fail) begin
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end else begin
                                    sub_step <= 1; // Next: Duplicates & Consecutive
                                    node_idx <= 0;
                                end
                            end
                        end

                        1: begin // Duplicates & Consecutive
                            if (!dup_fail && !consec_fail && node_idx < N) begin
                                if (mask[node_idx]) begin
                                    // Check Duplicate
                                    if (type_seen[V[node_idx]]) dup_fail <= 1;
                                    else type_seen[V[node_idx]] <= 1;
                                    
                                    // Check Consecutive for this node's subtree
                                    // We need to collect types in subtree(node_idx) that are in mask
                                    // To do this sequentially, we can iterate all nodes j and check if j is in subtree
                                    // But finding subtree requires traversal.
                                    // Let's assume adj[parent][child].
                                    // We need to find all descendants of node_idx that are in mask.
                                    
                                    // Start traversal logic to fill min/max/count
                                    // Reset traversal vars for this node_idx
                                    // We'll use a separate state for traversal or just iterate all nodes for subtree check?
                                    // Since N <= 8, iterating all nodes to check if they are in subtree is efficient.
                                    // How to check "in subtree"? 
                                    // A node B is in subtree of A if there is a path A -> ... -> B.
                                    // Since graph is a tree and nodes are sorted (0 is root?), we can check ancestors.
                                    // Wait, "tree" usually implies rooted at 0 or similar.
                                    // If adj[i][j] == 1 means i is parent of j.
                                    // Then j is in subtree of i if i is ancestor of j.
                                    // Ancestor of j: 
                                    // Parent of j: find p such that adj[p][j]=1. If p==i, direct child. 
                                    // If p != i, check parent of p, etc.
                                    
                                    // Let's do the "consecutive" check in a separate sub-step for clarity.
                                    // We need to iterate all nodes in mask to check duplicates and consecutive.
                                    // Consecutive check is the hard part.
                                    
                                    // Optimization: Check consecutive in a separate loop.
                                    // Let's move to a "Traverse" phase.
                                end
                                node_idx <= node_idx + 1;
                            end else if (node_idx >= N) begin
                                if (dup_fail || consec_fail) begin
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end else begin
                                    // Valid set
                                    state <= CHECK_SUBSETS;
                                    result <= result + 1;
                                    mask <= mask + 1;
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // The COUNT state logic above handles Duplicates (single pass). 
    // The Consecutive check is missing because it requires traversing subtrees for EACH node in mask.
    // 
    // To implement Consecutive Check properly:
    // 1. Pick node X in mask.
    // 2. Find all Y in mask where Y is descendant of X.
    // 3. Check if V(Y) values are consecutive integers.
    // 
    // Since N is small, let's use the existing states but refine the logic.
    // We will use a dedicated "Consecutive Check" sub-step sequence.
    // 
    // Revised Plan for COUNT state:
    // sub_step 0: Parent Check (Iterate all nodes)
    // sub_step 1: Duplicate Check (Iterate all nodes, accumulate type_seen)
    // sub_step 2: Consecutive Check (Iterate all nodes X in mask, then for each X, iterate all Y in mask to see if Y is in X's subtree)
    
    // Let's rewrite the always block to be cleaner and correct.
    // Since the prompt asks for a single module, we need to be careful with variable names.
    // I will use a hierarchical state machine inside COUNT.
    
    // Auxiliary registers for Consecutive Check
    reg [2:0] curr_node_x; // Node X currently being checked for consecutive
    reg [2:0] curr_node_y; // Node Y being checked if it's in subtree of X
    reg [3:0] subtree_count; // Count of nodes in subtree of X
    reg [15:0] subtree_min;
    reg [15:0] subtree_max;
    reg [2:0] ancestor_search_idx; // For finding if Y is in subtree of X
    reg [2:0] temp_ancestor;
    reg is_ancestor;

    // Final Corrected Logic Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            mask <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PARSE;
                        result <= 0;
                    end
                end

                PARSE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            V[i] <= V_packed[i*8 +: 4];
                            for (j = 0; j < 8; j = j + 1) begin
                                adj[i][j] <= adj_packed[i*8 + j];
                            end
                        end
                    end
                    mask <= 8'b1;
                    state <= CHECK_SUBSETS;
                end

                CHECK_SUBSETS: begin
                    if (mask < (8'b1 << N)) begin
                        // Initialize checks
                        sub_step <= 0; // Parent Check
                        node_idx <= 0;
                        k_idx <= 0;
                        parent_fail <= 0;
                        state <= COUNT;
                    end else begin
                        state <= DONE;
                    end
                end

                COUNT: begin
                    case (sub_step)
                        // Step 0: Check Parent Constraint
                        0: begin
                            if (node_idx < N) begin
                                if (mask[node_idx]) begin
                                    if (k_idx < N) begin
                                        if (adj[k_idx][node_idx] && !mask[k_idx]) parent_fail <= 1;
                                        k_idx <= k_idx + 1;
                                    end else begin
                                        node_idx <= node_idx + 1;
                                        k_idx <= 0;
                                    end
                                end else begin
                                    node_idx <= node_idx + 1;
                                end
                            end else begin
                                if (parent_fail) begin
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end else begin
                                    // Move to Step 1: Duplicate Check
                                    sub_step <= 1;
                                    node_idx <= 0;
                                    type_seen <= 16'b0;
                                    dup_fail <= 0;
                                end
                            end
                        end

                        // Step 1: Check Duplicate Types
                        1: begin
                            if (node_idx < N) begin
                                if (mask[node_idx]) begin
                                    if (type_seen[V[node_idx]]) dup_fail <= 1;
                                    else type_seen[V[node_idx]] <= 1;
                                end
                                node_idx <= node_idx + 1;
                            end else begin
                                if (dup_fail) begin
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end else begin
                                    // Move to Step 2: Consecutive Check
                                    sub_step <= 2;
                                    curr_node_x <= 0;
                                    consec_fail <= 0;
                                end
                            end
                        end

                        // Step 2: Check Consecutive Constraint for all nodes in mask
                        // For each node X in mask, check its subtree members in mask
                        2: begin
                            // Loop 1: Iterate X (nodes in mask)
                            if (curr_node_x < N) begin
                                if (mask[curr_node_x]) begin
                                    // Prepare to check subtree of curr_node_x
                                    subtree_count <= 0;
                                    subtree_min <= 16'hFFFF;
                                    subtree_max <= 0;
                                    curr_node_y <= 0;
                                    sub_step <= 3; // Go to inner loop state
                                end else begin
                                    curr_node_x <= curr_node_x + 1;
                                end
                            end else begin
                                // Done all X checks
                                if (consec_fail) begin
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end else begin
                                    // Valid set!
                                    result <= result + 1;
                                    state <= CHECK_SUBSETS;
                                    mask <= mask + 1;
                                end
                            end
                        end

                        // Step 3: Inner Loop for Consecutive (Iterate Y)
                        3: begin
                            // Loop 2: Iterate Y (nodes in mask)
                            if (curr_node_y < N) begin
                                if (mask[curr_node_y]) begin
                                    // Check if Y is in subtree of X (curr_node_x)
                                    // We need a recursive check. Since N is small, we can unroll or use a small sub-process.
                                    // Let's use a flag 'is_ancestor' and search index.
                                    // Actually, we can calculate if Y is in subtree of X by walking up from Y to root.
                                    // If we encounter X, then Y is in subtree of X.
                                    // Since X < Y usually, we can check if X is ancestor of Y.
                                    // 
                                    // Recursive check: 
                                    // Is X ancestor of Y? 
                                    // If X == Y, yes (trivially, or if we consider the node itself? 
                                    // "invited nodes in its subtree" - usually includes the node itself.
                                    // If X is parent of Y, yes.
                                    // If X is parent of parent of Y, yes.
                                    
                                    // Let's use a small stack/queue logic or just iterate ancestors of Y.
                                    // We can do this in sub_step 4.
                                    // Start searching ancestors of Y starting from parent.
                                    temp_ancestor <= 8'hFF; // Find parent of Y first
                                    sub_step <= 4;
                                end else begin
                                    curr_node_y <= curr_node_y + 1;
                                end
                            end else begin
                                // Done checking all Y for this X
                                // Check if consecutive count >= 2 (requires at least 2 nodes to form consecutive range? No, 1 node is trivially consecutive)
                                // But the problem says "consecutive joke types". 
                                // If only 1 node, min == max, diff = 0. 0 == count - 1 -> valid.
                                if (subtree_count > 0) begin
                                    if ((subtree_max - subtree_min) != (subtree_count - 1)) consec_fail <= 1;
                                end
                                curr_node_x <= curr_node_x + 1;
                                sub_step <= 2; // Return to outer loop
                            end
                        end

                        // Step 4: Find Parent of curr_node_y (Recursive Step)
                        // We need to check if curr_node_x is an ancestor of curr_node_y.
                        // We will walk up the tree from curr_node_y.
                        // But we need to wait for result.
                        // Let's optimize: We can just iterate all nodes Z and check if Z is parent of Y.
                        // If Z == X, found. If Z != X, check if X is ancestor of Z.
                        // This is recursive. 
                        // 
                        // Let's try an iterative approach using a variable to hold the "current node" for ancestor check.
                        // 
                        // Let's refine Step 3:
                        // If mask[Y], we need to check if X is ancestor of Y.
                        // We will use `temp_ancestor` to hold the node we are currently checking.
                        // Init: temp_ancestor = Y. 
                        // Loop: Find parent of temp_ancestor. 
                        // If parent == X, YES.
                        // If parent == Root (and != X), NO.
                        // 
                        // We need a state to perform this ancestor finding.
                        // State 4: Find Parent of `temp_ancestor`.
                        // State 5: Compare with X.

                        // Actually, let's simplify the check.
                        // Is X ancestor of Y?
                        // We can verify this by checking if there is a path.
                        // Since N is small, we can do this in one state by iterating all nodes as potential parents.
                        
                        // Revised Step 3 (Logic):
                        // If Y == X, include Y in subtree count.
                        // Else, find if X is ancestor of Y.
                        // We can iterate parents of Y.
                        // 
                        // Let's use `ancestor_search_idx` to iterate potential parents of Y.
                        // 
                        // Back to Step 3 code:
                        // ... we enter Step 3 with curr_node_y.
                        // Check: Is curr_node_y == curr_node_x? If yes, include.
                        // Else, check parentage.
                        
                        // Let's just implement the ancestor check in Step 4 cleanly.
                        
                        // --- Step 3 (Refined): Identify if Y is in X's subtree ---
                        3: begin
                            if (curr_node_y < N) begin
                                if (mask[curr_node_y]) begin
                                    if (curr_node_y == curr_node_x) begin
                                        // Self is always in subtree
                                        if (V[curr_node_y] < subtree_min) subtree_min <= V[curr_node_y];
                                        if (V[curr_node_y] > subtree_max) subtree_max <= V[curr_node_y];
                                        subtree_count <= subtree_count + 1;
                                        curr_node_y <= curr_node_y + 1;
                                    end else begin
                                        // Check if curr_node_x is ancestor of curr_node_y
                                        // Walk up from curr_node_y
                                        ancestor_search_idx <= curr_node_y; // Start at Y
                                        sub_step <= 4;
                                    end
                                end else begin
                                    curr_node_y <= curr_node_y + 1;
                                end
                            end else begin
                                // Done Y loop for this X
                                if (subtree_count > 0 && (subtree_max - subtree_min) != (subtree_count - 1)) consec_fail <= 1;
                                curr_node_x <= curr_node_x + 1;
                                sub_step <= 2;
                            end
                        end

                        // Step 4: Ancestor Walking
                        // Check if `ancestor_search_idx` has a parent.
                        // If parent == curr_node_x -> YES.
                        // If parent != curr_node_x -> continue walking up.
                        // If no parent -> NO.
                        4: begin
                            // Find parent of `ancestor_search_idx`
                            // Iterate all nodes k to see if adj[k][ancestor_search_idx] == 1
                            if (k_idx < N) begin
                                if (adj[k_idx][ancestor_search_idx]) begin
                                    // Found parent k_idx
                                    if (k_idx == curr_node_x) begin
                                        // YES, X is ancestor of Y
                                        if (V[curr_node_y] < subtree_min) subtree_min <= V[curr_node_y];
                                        if (V[curr_node_y] > subtree_max) subtree_max <= V[curr_node_y];
                                        subtree_count <= subtree_count + 1;
                                        curr_node_y <= curr_node_y + 1;
                                        k_idx <= 0;
                                        sub_step <= 3; // Return to Step 3 loop
                                    end else begin
                                        // Parent is not X, check if X is ancestor of Parent (continue walk)
                                        ancestor_search_idx <= k_idx;
                                        k_idx <= 0; // Reset to search for parent of new ancestor_search_idx
                                        // Stay in Step 4
                                    end
                                end else begin
                                    k_idx <= k_idx + 1;
                                end
                            end else begin
                                // No more parents found (reached root) and didn't find X
                                curr_node_y <= curr_node_y + 1;
                                k_idx <= 0;
                                sub_step <= 3; // Return to Step 3 loop
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
