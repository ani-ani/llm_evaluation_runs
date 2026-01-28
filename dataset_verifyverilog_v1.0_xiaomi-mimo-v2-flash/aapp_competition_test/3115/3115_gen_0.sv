module tournament_consistency (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] player_a,
    input wire [3:0] player_b,
    input wire [1:0] match_type,
    input wire match_valid,
    input wire match_end,
    output reg done,
    output reg consistent
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ACCEPT_INPUTS = 2'd1;
    localparam [1:0] CHECK_CONSISTENCY = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Storage: 16x16 bitmasks for equality groups
    // Each row is a 16-bit register representing the group for that player
    reg [15:0] eq_group [0:15];
    // Adjacency matrix for strict inequalities (directed graph)
    reg [15:0] adj_matrix [0:15];

    // Internal state
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255; // Safety limit

    // Iteration counters
    reg [3:0] i, j, k; // i,j for loops, k for intermediate node
    reg [3:0] a_idx, b_idx; // temp indices for processing
    reg [15:0] group_a, group_b;
    reg [15:0] temp_mask;
    reg conflict_detected;
    
    // Helper variables for cycle detection
    reg [15:0] visited_nodes;
    reg [15:0] stack_nodes;
    reg cycle_found;
    reg [3:0] current_node;
    integer l, m;

    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            consistent <= 1'b1; // Default consistent
            cycle_counter <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            conflict_detected <= 1'b0;
            visited_nodes <= 16'd0;
            stack_nodes <= 16'd0;
            cycle_found <= 1'b0;
            current_node <= 4'd0;
            
            // Initialize storage
            for (l = 0; l < 16; l = l + 1) begin
                eq_group[l] <= 16'd0;
                adj_matrix[l] <= 16'd0;
                // Self-reference for equality group init (each player in own group initially)
                eq_group[l][l] <= 1'b1;
            end
        end else begin
            state <= next_state;
            
            // Default done to 0 unless explicitly set in DONE_STATE
            if (state != DONE_STATE) done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    conflict_detected <= 1'b0;
                    cycle_found <= 1'b0;
                    visited_nodes <= 16'd0;
                    stack_nodes <= 16'd0;
                    current_node <= 4'd0;
                    // Reset storage if start signal received (optional, but good for clean slate)
                    if (start) begin
                        consistent <= 1'b1;
                        for (l = 0; l < 16; l = l + 1) begin
                            eq_group[l] <= 16'd0;
                            adj_matrix[l] <= 16'd0;
                            eq_group[l][l] <= 1'b1;
                        end
                    end
                end

                ACCEPT_INPUTS: begin
                    if (match_valid) begin
                        if (match_type == 2'd0) begin // Equality '='
                            // Get current groups
                            group_a <= eq_group[player_a];
                            group_b <= eq_group[player_b];
                            // Merge operation: update later in combinational block or sequential
                            // For sequential simplicity, we perform merge here for the two players
                            // But to merge groups fully, we need to update all members.
                            // We will do the logic in combinational block triggered by state.
                        end else if (match_type == 2'd1) begin // Strict '>'
                            // Add edge a -> b
                            adj_matrix[player_a][player_b] <= 1'b1;
                        end
                    end
                end

                CHECK_CONSISTENCY: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Step 1: Merge equality groups (if not already done in ACCEPT_INPUTS)
                    // Actually, we should merge as we go. 
                    // Let's verify: The requirement says "Update all members... to share the same bitmask."
                    // This is expensive in one cycle. We will do it via a loop in CHECK_CONSISTENCY.
                    // But the problem says input processing happens in ACCEPT_INPUTS.
                    // Re-reading: "While match_valid is high..."
                    // Since match_end triggers CHECK_CONSISTENCY, we can process merges here.
                    // However, merges need to happen BEFORE consistency check.
                    // Let's handle merges in a sub-state or interleaved.
                    // Given the complexity, we will perform full group updates in CHECK_CONSISTENCY
                    // using iteration counters i and j.
                    
                    // --- MERGE LOGIC (Pre-check) ---
                    // We need to ensure all equality constraints are fully propagated.
                    // This is effectively finding connected components in the equality graph.
                    // Since we have small N=16, we can use Floyd-Warshall like logic or simple iteration.
                    // Let's use a transitive closure on the equality 'mask'.
                    // Actually, the requirement says: "Update all members of both groups to share the same bitmask."
                    // This implies if A=B and C=D and B=C, then A, B, C, D share one mask.
                    
                    // Optimization: Perform transitive closure on equality relation.
                    // Loop: for k in 0..15, for i in 0..15, for j in 0..15: 
                    // if (eq[i][k] && eq[k][j]) eq[i][j] = 1;
                    // We already store 'eq_group' as bitmask per player.
                    // We will iterate i (source), k (intermediate), j (target) in this state.
                    
                    if (i < 16 && j < 16 && k < 16) begin
                        // Check if i and k are connected, and k and j are connected -> connect i and j
                        if (eq_group[i][k] && eq_group[k][j]) begin
                            eq_group[i][j] <= 1'b1;
                            eq_group[j][i] <= 1'b1; // Ensure symmetry (undirected)
                        end
                        
                        // Increment counters
                        if (k < 15) k <= k + 1'b1;
                        else begin
                            k <= 4'd0;
                            if (j < 15) j <= j + 1'b1;
                            else begin
                                j <= 4'd0;
                                if (i < 15) i <= i + 1'b1;
                                else begin
                                    i <= 4'd0;
                                    j <= 4'd0;
                                    // Done with closure, proceed to conflict check
                                end
                            end
                        end
                    end

                    // --- CONFLICT CHECK ---
                    // 1. Check if A=B and A>B (direct loop)
                    // We iterate i, j. If eq_group[i][j] is 1 and adj_matrix[i][j] is 1.
                    // 2. Check transitivity of strict inequality.
                    // The graph is directed. We need to detect cycles in the condensed graph.
                    // Condensed graph: Nodes are equality groups.
                    // If group X > group Y and group Y > group X, inconsistent.
                    // If there is a path X -> Y -> Z -> X, inconsistent.
                    
                    // We will perform DFS for cycle detection on the adjacency matrix.
                    // To optimize for 1 cycle per clock, we can implement a simple iterative DFS.
                    // 
                    // Simplified approach for resource constrained sequential logic:
                    // Just check for direct loops (i > j AND j > i) involving equal nodes.
                    // And check for direct conflicts: (i==j via equality) AND (i>j).
                    // The requirement says "Check for transitive loops... using simple DFS or Floyd-Warshall".
                    // Let's use Floyd-Warshall on the strict adjacency matrix to find transitive closure.
                    // Then check for cycles.
                    
                    // Since we used i,j,k for equality closure, we can reuse them for strict closure.
                    // However, we need to separate the phases. 
                    // Let's use the cycle_counter to gate phases or just reuse i,j,k after equality is done.
                    // Assuming equality phase is done (i reached 16).
                    
                    if (i >= 16) begin
                        // Phase 2: Strict Inequality Transitive Closure
                        // Use Warshall's algorithm: adj_matrix[i][j] = adj_matrix[i][j] OR (adj_matrix[i][k] AND adj_matrix[k][j])
                        // Re-use i, j, k. We need to reset them for this phase if we want.
                        // Or just continue incrementing. Let's check values.
                        
                        // We need specific indices for the triple loop. 
                        // Let's use new locals: s, t, u or re-init i,j,k.
                        // To keep it simple and sequential:
                        if (k < 16 && j < 16 && i < 16) begin
                             // Standard Warshall
                             // if (adj[i][k] && adj[k][j]) adj[i][j] = 1
                             if (adj_matrix[i][k] && adj_matrix[k][j]) begin
                                if (!adj_matrix[i][j]) adj_matrix[i][j] <= 1'b1;
                             end
                             
                             // Counter logic
                             if (k < 15) k <= k + 1'b1;
                             else begin
                                 k <= 4'd0;
                                 if (j < 15) j <= j + 1'b1;
                                 else begin
                                     j <= 4'd0;
                                     if (i < 15) i <= i + 1'b1;
                                     else begin
                                         // All closures computed.
                                         // Now perform final consistency check.
                                         // i=16 indicates we are in check phase.
                                         i <= 4'd16; // Mark phase 2 complete
                                         j <= 4'd0;
                                         k <= 4'd0; // Reset for check loop
                                     end
                                 end
                             end
                        end
                    end

                    // --- FINAL CHECK ---
                    if (i == 4'd16) begin
                        // Check all pairs (j, k)
                        // Inconsistency if:
                        // 1. adj[j][k] == 1 AND adj[k][j] == 1 (cycle between distinct nodes)
                        // 2. eq_group[j][k] == 1 AND (adj[j][k] == 1 OR adj[k][j] == 1) (equality implies strict inequality)
                        //    (Specifically, if j==k via equality, j>j is impossible)
                        
                        if (adj_matrix[j][k] && adj_matrix[k][j]) begin
                            conflict_detected <= 1'b1;
                        end else if (eq_group[j][k] && (adj_matrix[j][k] || adj_matrix[k][j])) begin
                            // If j and k are in same group, but there is a strict path between them
                            // This includes self-check: eq[j][j] is 1, adj[j][j] is usually 0 unless loop, but if adj[j][j] was set explicitly
                            conflict_detected <= 1'b1;
                        end

                        // Increment counters
                        if (k < 15) k <= k + 1'b1;
                        else begin
                            k <= 4'd0;
                            if (j < 15) j <= j + 1'b1;
                            else begin
                                // Done checking
                                j <= 4'd0;
                                k <= 4'd0;
                                i <= 4'd17; // Mark check complete
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (conflict_detected) consistent <= 1'b0;
                    else consistent <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = ACCEPT_INPUTS;
                else next_state = IDLE;
            end
            
            ACCEPT_INPUTS: begin
                if (match_end) next_state = CHECK_CONSISTENCY;
                else if (match_valid) next_state = ACCEPT_INPUTS; // Stay to process
                else next_state = ACCEPT_INPUTS;
            end
            
            CHECK_CONSISTENCY: begin
                // We use i to track phase and progress.
                // i < 16: Equality Transitive Closure
                // 16 < i < 17: Strict Transitive Closure (i=16 acts as flag)
                // i == 17: Final Check
                // i == 18: Done with checks
                
                if (i < 16) begin
                    next_state = CHECK_CONSISTENCY; // Still doing equality closure
                end else if (i == 16) begin
                     // Doing strict closure
                     // We need to wait for the loops to finish. 
                     // In the sequential block, we incremented i when loops finished.
                     // Wait for i to become 17.
                     next_state = CHECK_CONSISTENCY;
                end else if (i == 17) begin
                    // Doing final check
                    // Wait for i to become 18 (check complete)
                    next_state = CHECK_CONSISTENCY;
                end else if (i == 18) begin
                    next_state = DONE_STATE;
                end else begin
                     // Safety fallback
                     next_state = CHECK_CONSISTENCY;
                end
                
                // Note: The counter logic in sequential block handles the transitions.
                // Specifically: 
                // 1. Equality loop finishes -> i becomes 16.
                // 2. Strict loop finishes -> i becomes 17 (Wait, in code I set i <= 16 after equality, then i <= 16 after strict? No, let's trace)
                // Correction in sequential block logic:
                // After equality (i loops): i = 16.
                // In strict loop (using i,j,k where i<16): This conflicts with i=16 flag.
                // I need separate counters or clearer state management.
                
                // Let's refine the transition logic in next_state:
                // If conflict_detected is set early, we can go to DONE, but the requirement says "within 2048 cycles".
                // We must complete the checks.
                
                // Refined Sequence in CHECK_CONSISTENCY state:
                // Phase A: Equality Transitive Closure. (Use counter s, t, u or reused i, j, k). 
                // Phase B: Strict Transitive Closure. (Reset counters). 
                // Phase C: Final Conflict Check.
                
                // Since we reused i, j, k in sequential block, we need to know where we are.
                // The sequential block increments i based on completion.
                // If i (as loop var) finishes, we need to move to next phase.
                // 
                // Let's use a separate 'phase' register or infer from loop counter max values.
                // To keep it simple with minimal registers:
                // The sequential block logic had: 
                // if (i < 16) ... increment i,j,k
                // if (i >= 16) ... this block was entered.
                // But inside that block, we reused i,j,k.
                // This is buggy. 
                
                // Correct approach in next_state:
                // We need to detect when a loop finishes.
                // Equality loop: i goes 0..15, j 0..15, k 0..15. Total cycles = 16*16*16 = 4096. 
                // 4096 > 2048. Too slow for 2048 cycle limit.
                // Must be more efficient.
                
                // Optimization: 
                // 1. Equality Closure: For each player, OR the masks of all connected players.
                //    Iteration 0-15: Update mask based on neighbors.
                //    Repeat 16 times? No, just iterate edges.
                //    Actually, standard transitive closure for N=16 takes N^3, which is 4096 ops.
                //    The requirement says "within 2048 cycles".
                //    This implies we might need to optimize or the test bench allows multi-cycle operations.
                //    "done should pulse within 2048 cycles of match_end".
                //    2048 cycles for CHECK_CONSISTENCY phase.
                //    N=16. 16*16 = 256 pairs. 2048/256 = 8 cycles per pair.
                //    This is feasible if we don't do full N^3 Floyd-Warshall blindly.
                
                // Let's simplify the logic for the 2048 cycle limit.
                // Equality: Simply propagate bitmasks. 
                // If we iterate 1..16 times, we can reach fixed point.
                // Strict: Cycle detection on 16 nodes.
                // We can do a DFS. 16 nodes. 
                // 
                // Revised Logic for CHECK_CONSISTENCY:
                // Step 1: Propagate Equality. 
                // For iter in 0..15 (16 iterations):
                //   For each node i: 
                //     temp_mask = eq_group[i]
                //     For each node j where temp_mask[j] is 1: OR eq_group[j] into temp_mask.
                //     Update eq_group[i] = temp_mask.
                // This is N^2 per iteration. 16*256 = 4096. Still too high.
                
                // Alternative: Since N=16, we can iterate Pairs (i, j).
                // If eq[i][j], then union their masks. 
                // Union operation: eq_group[i] = eq_group[i] | eq_group[j].
                // This updates the mask for i, but not for others pointing to i immediately.
                // We need a second pass to propagate.
                
                // Given the constraints, let's implement a reasonably efficient sequential logic.
                // We will assume the testbench waits for `done`.
                // However, the 2048 limit is strict.
                // 
                // Let's optimize the Loop Counters.
                // We will use a flat loop counter.
                // Total available cycles: 2048.
                // 
                // Optimized Transitive Closure (Equality):
                // Iterate k from 0 to 15 (intermediate node).
                // Iterate i from 0 to 15 (source).
                // If eq[i][k], then eq[i] = eq[i] | eq[k].
                // This takes 16*16 = 256 cycles.
                // 
                // Optimized Transitive Closure (Strict):
                // Iterate k from 0 to 15.
                // Iterate i from 0 to 15.
                // If adj[i][k], then adj[i] = adj[i] | adj[k].
                // This takes 256 cycles.
                // 
                // Optimized Conflict Check:
                // Iterate i, j (256 cycles).
                // 
                // Total: 256 + 256 + 256 = 768 cycles. Fits in 2048.
                
                // So we will implement the optimized O(N^3) logic (but actually O(N^2) per pass if careful, or O(N^3) for nested loops).
                // In sequential hardware, 16*16 = 256 steps is 256 cycles.
                // 3 passes = 768 cycles.
                
                // Let's adjust the sequential block to this optimized flow.
                // State: CHECK_CONSISTENCY.
                // We need 3 phases.
                // Phase 1: Equality Closure (256 cycles). 
                //   Loop i (0..15), Loop k (0..15). 
                //   Update eq[i] if eq[i][k].
                // Phase 2: Strict Closure (256 cycles).
                //   Loop i (0..15), Loop k (0..15).
                //   Update adj[i] if adj[i][k].
                // Phase 3: Check (256 cycles).
                //   Loop i (0..15), Loop j (0..15).
                //   Check conditions.
                
                // We will use `phase` register to distinguish stages.
                // localparam PHASE_EQ = 2'd0, PHASE_STRICT = 2'd1, PHASE_CHECK = 2'd2, PHASE_DONE = 2'd3.
                // Or use counters. 
                // Let's use a `phase` register.
                
                // Updated implementation:
                // 1. Add `phase` reg.
                // 2. In CHECK_CONSISTENCY state, iterate based on phase.
                // 3. Transition phases when loops complete.
                
                // We will rely on the fact that the sequential block updates `i`, `j`, `k`.
                // Phase 1 (EQ): 
                //   if i < 16: if k < 16: update eq[i] | eq[k], inc k. else k=0, inc i.
                //   if i==16: phase = 1, i=0, k=0.
                // Phase 2 (STRICT):
                //   if i < 16: if k < 16: update adj[i] | adj[k], inc k. else k=0, inc i.
                //   if i==16: phase = 2, i=0, j=0.
                // Phase 3 (CHECK):
                //   if i < 16: if j < 16: check eq[i][j] & (adj[i][j]|adj[j][i]), inc j. else j=0, inc i.
                //   if i==16: next_state = DONE.
                
                // We need a `phase` register.
                
                // Let's add `phase` to the module.
                // localparam [1:0] PHASE_EQ = 0, PHASE_STRICT = 1, PHASE_CHECK = 2;
                // reg [1:0] phase;
                
                // Next State Logic (simplified for implementation):
                if (i == 16) begin
                    // Phase transition logic handled in sequential block
                    // We stay in CHECK_CONSISTENCY until final check is done
                    // (Specifically, when phase CHECK is done)
                end
                
                // We will rely on the sequential block to set next_state to DONE_STATE.
                // The logic in the sequential block will handle the phase transitions.
                // We just need to keep next_state as CHECK_CONSISTENCY unless explicitly transitioned.
                
                next_state = CHECK_CONSISTENCY;
            end
            
            DONE_STATE: begin
                if (start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- Revised Sequential Logic with Phases ---
    // To make this work within the constraints, we will add a phase register.
    // I will include the phase register in the block below.

endmodule

// Note: The above code sketch includes the logic structure. 
// I need to output the final, clean code. 
// I will integrate the 'phase' register into the module definition.

// Re-writing the module with 'phase' included.

module tournament_consistency (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] player_a,
    input wire [3:0] player_b,
    input wire [1:0] match_type,
    input wire match_valid,
    input wire match_end,
    output reg done,
    output reg consistent
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ACCEPT_INPUTS = 2'd1;
    localparam [1:0] CHECK_CONSISTENCY = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Phase definitions for CHECK_CONSISTENCY
    localparam [1:0] PHASE_EQ = 2'd0;
    localparam [1:0] PHASE_STRICT = 2'd1;
    localparam [1:0] PHASE_CHECK = 2'd2;

    // Storage
    reg [15:0] eq_group [0:15];
    reg [15:0] adj_matrix [0:15];

    // Internal state
    reg [1:0] state;
    reg [1:0] phase;
    reg [3:0] i, j, k; // Iterators
    reg conflict_detected;
    
    // Combinational helper for sequential logic updates
    wire [15:0] eq_update;
    assign eq_update = eq_group[i] | eq_group[k];
    
    wire [15:0] adj_update;
    assign adj_update = adj_matrix[i] | adj_matrix[k];

    // FSM Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            phase <= PHASE_EQ;
            done <= 1'b0;
            consistent <= 1'b1;
            conflict_detected <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            // Initialize storage
            for (integer l = 0; l < 16; l = l + 1) begin
                eq_group[l] <= 16'd0;
                adj_matrix[l] <= 16'd0;
                eq_group[l][l] <= 1'b1;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        consistent <= 1'b1;
                        conflict_detected <= 1'b0;
                        // Reset storage on start for clean slate
                        for (integer l = 0; l < 16; l = l + 1) begin
                            eq_group[l] <= 16'd0;
                            adj_matrix[l] <= 16'd0;
                            eq_group[l][l] <= 1'b1;
                        end
                        // Input state handles match_valid
                    end
                end

                ACCEPT_INPUTS: begin
                    if (match_valid) begin
                        if (match_type == 2'd0) begin // Equality
                            // Merge groups for A and B immediately
                            // Update A's group to include B's group
                            // Update B's group to include A's group
                            // This is a local union operation. Full transitive closure happens later.
                            eq_group[player_a] <= eq_group[player_a] | eq_group[player_b];
                            eq_group[player_b] <= eq_group[player_b] | eq_group[player_a];
                        end else if (match_type == 2'd1) begin // Strict
                            adj_matrix[player_a][player_b] <= 1'b1;
                        end
                    end
                end

                CHECK_CONSISTENCY: begin
                    case (phase)
                        PHASE_EQ: begin
                            // Transitive closure for equality
                            // eq[i] = eq[i] | eq[k] if eq[i][k]
                            if (eq_group[i][k]) begin
                                eq_group[i] <= eq_update;
                            end
                            
                            // Loop counters i, k (0..15)
                            if (k < 15) begin
                                k <= k + 1'b1;
                            end else begin
                                k <= 4'd0;
                                if (i < 15) begin
                                    i <= i + 1'b1;
                                end else begin
                                    // Phase complete
                                    i <= 4'd0;
                                    phase <= PHASE_STRICT;
                                end
                            end
                        end

                        PHASE_STRICT: begin
                            // Transitive closure for strict inequalities
                            // adj[i] = adj[i] | adj[k] if adj[i][k]
                            if (adj_matrix[i][k]) begin
                                adj_matrix[i] <= adj_update;
                            end
                            
                            if (k < 15) begin
                                k <= k + 1'b1;
                            end else begin
                                k <= 4'd0;
                                if (i < 15) begin
                                    i <= i + 1'b1;
                                end else begin
                                    // Phase complete
                                    i <= 4'd0;
                                    phase <= PHASE_CHECK;
                                end
                            end
                        end

                        PHASE_CHECK: begin
                            // Check consistency
                            // Condition 1: adj[i][j] && adj[j][i] (Cycle between distinct or same)
                            // Condition 2: eq[i][j] && (adj[i][j] || adj[j][i]) (Equality implies strict)
                            
                            if (adj_matrix[i][j] && adj_matrix[j][i]) begin
                                conflict_detected <= 1'b1;
                            end else if (eq_group[i][j] && (adj_matrix[i][j] || adj_matrix[j][i])) begin
                                conflict_detected <= 1'b1;
                            end
                            
                            if (j < 15) begin
                                j <= j + 1'b1;
                            end else begin
                                j <= 4'd0;
                                if (i < 15) begin
                                    i <= i + 1'b1;
                                end else begin
                                    // Check complete
                                    // Transition handled in next_state logic or here
                                end
                            end
                        end
                    endcase
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (conflict_detected) consistent <= 1'b0;
                    else consistent <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = ACCEPT_INPUTS;
                else next_state = IDLE;
            end
            ACCEPT_INPUTS: begin
                if (match_end) next_state = CHECK_CONSISTENCY;
                else next_state = ACCEPT_INPUTS;
            end
            CHECK_CONSISTENCY: begin
                if (phase == PHASE_CHECK && i == 15 && j == 15) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECK_CONSISTENCY;
                end
            end
            DONE_STATE: begin
                if (start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
