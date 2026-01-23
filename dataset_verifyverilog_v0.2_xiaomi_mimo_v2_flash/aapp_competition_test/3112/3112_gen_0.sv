module producer_routing(
    input clk,
    input rst_n,
    input start,
    input [2:0] K,
    input [2:0] N,
    input [5:0] M,
    input [2:0] edge_a,
    input [2:0] edge_b,
    input edges_valid,
    input edges_done,
    output reg [2:0] max_producers,
    output reg done
);

    // Parameters
    parameter MAX_JUNC = 8;
    parameter MAX_PROD = 8;

    // State Definitions
    localparam IDLE = 4'd0;
    localparam LOAD_EDGES = 4'd1;
    localparam BUILD_PATHS_INIT = 4'd2;
    localparam BUILD_PATHS_BFS = 4'd3;
    localparam BUILD_PATHS_EXTRACT = 4'd4;
    localparam CHECK_COMPATIBILITY = 4'd5;
    localparam FIND_MAX_SET = 4'd6;
    localparam DONE = 4'd7;

    // Registers and Wires
    reg [3:0] state;
    reg [5:0] edge_cnt;
    reg [2:0] current_prod;
    reg [2:0] prod_i, prod_j;
    reg [2:0] subset_mask;
    reg [2:0] best_subset;
    reg [2:0] best_count;
    reg [2:0] temp_count;

    // Adjacency Matrix (8x8 bits, flattened or 2D array)
    // Stored as: adj_matrix[a][b] = 1 if directed edge a->b exists
    reg [7:0] adj_matrix [0:7];
    integer i, j;

    // Path Storage
    // path_len[p]: length of path from producer p+1 to N
    // dist_matrix[p][j]: distance from producer p+1 to junction j (1-indexed)
    reg [3:0] path_len [0:7];
    reg [3:0] dist_matrix [0:7] [0:7];

    // Compatibility Matrix
    // compat_matrix[i][j] = 1 if producer i and j are compatible
    reg [7:0] compat_matrix [0:7];

    // BFS State Registers
    reg [7:0] visited;
    reg [7:0] queue [0:7]; // Simple queue for BFS
    reg [2:0] q_head, q_tail;
    reg [3:0] bfs_dist [0:7]; // Distance from source in current BFS run
    reg [2:0] source_node;
    reg [2:0] walk_node;
    reg [2:0] walk_step;
    reg [2:0] walk_dest;
    reg [3:0] walk_dist;

    // Helper for popcount
    function [2:0] popcount;
        input [7:0] v;
        begin
            popcount = v[0] + v[1] + v[2] + v[3] + v[4] + v[5] + v[6] + v[7];
        end
    endfunction

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_producers <= 0;
            edge_cnt <= 0;
            best_count <= 0;
            // Reset adjacency
            for (i = 0; i < 8; i = i + 1) adj_matrix[i] <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_EDGES;
                        edge_cnt <= 0;
                    end
                end

                LOAD_EDGES: begin
                    if (edges_valid) begin
                        // Store edge: edge_a -> edge_b (1-indexed to 0-indexed logic)
                        if (edge_a >= 1 && edge_a <= N && edge_b >= 1 && edge_b <= N) begin
                            adj_matrix[edge_a - 1][edge_b - 1] <= 1'b1;
                        end
                        edge_cnt <= edge_cnt + 1;
                    end
                    if (edges_done) begin
                        state <= BUILD_PATHS_INIT;
                        current_prod <= 1; // Start from Producer 1
                    end
                end

                BUILD_PATHS_INIT: begin
                    // Initialize BFS for current producer
                    // Source is 'current_prod'. Destination is 'N'.
                    // BFS from source_node = current_prod.
                    source_node <= current_prod;
                    visited <= 8'b0;
                    // Initialize dist_matrix for this producer (reset or just overwrite)
                    // Initialize queue
                    q_head <= 0;
                    q_tail <= 0;
                    // Start BFS: Enqueue source
                    queue[0] <= current_prod;
                    q_tail <= 1;
                    visited[current_prod - 1] <= 1'b1;
                    bfs_dist[current_prod - 1] <= 0;
                    
                    if (current_prod > K) begin
                        state <= CHECK_COMPATIBILITY;
                        prod_i <= 1;
                        prod_j <= 2;
                    end else begin
                        state <= BUILD_PATHS_BFS;
                    end
                end

                BUILD_PATHS_BFS: begin
                    if (q_head < q_tail) begin
                        // Dequeue
                        reg [2:0] u;
                        u <= queue[q_head];
                        q_head <= q_head + 1;
                        // For each neighbor v of u
                        // We need to iterate v from 1 to N
                        walk_node <= 1;
                        walk_step <= 0; // State to continue iteration if needed
                        // We will check adjacency in a sub-state or combinational logic. 
                        // Here we prepare to check neighbors of dequeued node.
                        walk_dist <= bfs_dist[u - 1];
                    end else begin
                        // BFS Finished for this producer
                        // Save path length to N
                        if (bfs_dist[N - 1] != 0 || N == current_prod) begin
                            path_len[current_prod - 1] <= bfs_dist[N - 1];
                            // Also copy BFS dist to dist_matrix row
                            for (int k = 0; k < 8; k++) dist_matrix[current_prod - 1][k] <= bfs_dist[k];
                        end else begin
                            path_len[current_prod - 1] <= 4'hF; // Infinite/Unreachable
                        end
                        current_prod <= current_prod + 1;
                        state <= BUILD_PATHS_INIT;
                    end
                end
                
                // To implement BFS neighbor check efficiently in hardware, 
                // we can check one neighbor per cycle or check all neighbors combinational.
                // Given M <= 1000, graph is sparse? Or dense? Max 8 nodes, max 64 edges.
                // We can check all neighbors of 'u' in one cycle.
                // Update: Let's restructure BUILD_PATHS_BFS to process neighbors in one cycle.
                
                CHECK_COMPATIBILITY: begin
                    // Check pair (prod_i, prod_j)
                    // Logic: 
                    // 1. Check if paths share edges.
                    // 2. If shared edge exists, check distance difference parity.
                    // Since we only have dist_matrix (source -> node), we don't have edge-specific distances easily without storing the path.
                    // However, we can deduce compatibility based on shared edges.
                    // If edge u->v is in path P1 and P2:
                    //   dist1 = dist_matrix[prod_i-1][u]
                    //   dist2 = dist_matrix[prod_j-1][u]
                    //   If (dist1 - dist2) is even -> Collision.
                    // 
                    // We need to iterate all edges u->v.
                    // If adj_matrix[u][v] == 1:
                    //   Check if P1 uses it: dist_matrix[prod_i-1][u] + 1 == dist_matrix[prod_i-1][v]
                    //   Check if P2 uses it: dist_matrix[prod_j-1][u] + 1 == dist_matrix[prod_j-1][v]
                    //   (Also need to check if the edge is actually on the shortest path. BFS guarantees shortest path.)
                    //   If both use it: check (dist_matrix[prod_i-1][u] - dist_matrix[prod_j-1][u]) % 2.
                    
                    // We will compute compatibility in a loop over edges.
                    // Let's use 'walk_node' to iterate u, and 'walk_dest' to iterate v.
                    // We need a temporary flag to store if they are incompatible.
                    // 
                    // Optimization: We can just iterate edges and flag collision.
                    
                    // Iteration state:
                    // If prod_i > K: done.
                    // If prod_j > K: prod_i++, prod_j = prod_i+1.
                    // Else: Check pair.
                    
                    if (prod_i > K) begin
                        state <= FIND_MAX_SET;
                        subset_mask <= 1;
                        best_count <= 0;
                        temp_count <= 0;
                    end else if (prod_j > K) begin
                        prod_i <= prod_i + 1;
                        prod_j <= prod_i + 2;
                    end else begin
                        // Check compatibility of prod_i and prod_j
                        // Initialize edge iterator
                        walk_node <= 1; // u
                        walk_dest <= 1; // v
                        // We need a flag to track collision for this pair
                        // We'll use a temporary register or compute combinational? 
                        // Let's use a temp flag 'pair_collision' stored in a register.
                        // Actually, let's just calculate it statelessly in combinational logic if possible, 
                        // but since we are in FSM, we might need a cycle.
                        // Given constraints, we can do it in one cycle combinational check if we unroll or 
                        // iterate through edges (max 64) in multiple cycles. 
                        // To save states, let's iterate edges.
                        
                        state <= CHECK_COMPATIBILITY; // Stay here until done
                        
                        // Need a register to hold the collision result for current pair
                        // If we find one collision, we set compat_matrix[i][j] = 0.
                        // 
                        // Let's introduce a specific sub-state for pair checking or just use 'walk_step'.
                        // Let's use 'walk_step' as flag: 0 = checking, 1 = done checking pair.
                        walk_step <= 0; 
                    end
                end

                // Refinement: We need a separate state to iterate edges for compatibility
                // Let's call it CHECK_COMPAT_EDGES
                // Actually, let's handle the logic inside CHECK_COMPATIBILITY but with internal iteration registers.
                // If we stay in CHECK_COMPATIBILITY, we need to differentiate first cycle vs subsequent cycles.
                
                FIND_MAX_SET: begin
                    // Iterate all subsets of K producers (mask 1 to 2^K-1)
                    // Check if subset is independent (all pairs compatible)
                    // If valid, check popcount > best_count.
                    
                    // Check current subset_mask
                    // Valid if for all i, j in mask, compat_matrix[i][j] == 1 (where i<j, and if i==j ignore)
                    // Actually, compat_matrix[i][j] defined for i!=j.
                    
                    // We can check validity by iterating i, j again.
                    // To save time, we can pre-calculate validity or check on the fly.
                    // Since K <= 8, iterating pairs takes <= 28 cycles.
                    // Total subsets 255. 255 * 28 ~ 7000 cycles. Too slow for 2000 cycles.
                    // We need to be faster.
                    // 
                    // Optimization: 
                    // We can check subsets incrementally or use a smarter check.
                    // Or just check subsets and assume < 2000 cycles is enough if we optimize.
                    // 2000 cycles / 255 subsets = ~7.8 cycles/subset. We need to check validity in ~8 cycles.
                    // Checking 28 pairs in 8 cycles is hard.
                    // 
                    // Alternative: Since K is small (8), we can brute force but optimize the validity check.
                    // Validity check logic: 
                    // A subset S is valid if (S & compat_matrix[i]) == S for all i in S.
                    // We can check this with a loop.
                    // 
                    // Let's do it in state FIND_MAX_SET with sub-iterations.
                    // State FIND_MAX_SET_INIT (prepare check)
                    // State FIND_MAX_SET_CHECK (iterate i)
                    // State FIND_MAX_SET_UPDATE (update best)
                    // State FIND_MAX_SET_NEXT (increment mask)
                    
                    // For simplicity in this block, let's assume we can process checking in a few cycles.
                    // Actually, let's use a specific checking state sequence.
                end
                
                // Let's split FIND_MAX_SET into sub-states
                FIND_MAX_SET: begin // This is actually the entry point, let's map to a sub-process
                    // We will use 'walk_node' as the index for iterating producers in the subset check
                    // We will use 'walk_dest' as a flag or second index
                    // Let's just do the check loop here.
                    
                    // Check subset subset_mask.
                    // We need to verify: for all p in subset, (compat_matrix[p] & subset) == subset (excluding p itself)
                    // More precisely: For all p in subset, and q in subset, if p!=q then compat_matrix[p][q] == 1.
                    
                    // Let's use 'walk_node' as i (producer index 0..7)
                    // Let's use 'walk_dest' as j (producer index 0..7)
                    // Use 'walk_step' as a flag: 0=checking valid, 1=done checking.
                    // Use 'visited' register to store temporary validity result (0=invalid, 1=valid).
                    
                    walk_node <= 0;
                    walk_dest <= 0;
                    visited[0] <= 1'b1; // Assume valid initially
                    state <= FIND_MAX_SET_CHECK;
                end

                FIND_MAX_SET_CHECK: begin
                    // Loop through pairs i<j in subset_mask
                    // If subset_mask[i] and subset_mask[j] are set, check compat_matrix[i][j]
                    // If invalid, set visited[0] = 0.
                    // If invalid, skip to next subset immediately to save time.
                    
                    // Increment logic
                    if (walk_node >= K) begin
                        // Finished checking all i
                        if (visited[0]) begin
                            // Valid subset. Count popcount.
                            temp_count <= popcount(subset_mask);
                            state <= FIND_MAX_SET_UPDATE;
                        end else begin
                            // Invalid, go to next subset
                            state <= FIND_MAX_SET_NEXT;
                        end
                    end else if (walk_dest >= K) begin
                        walk_node <= walk_node + 1;
                        walk_dest <= walk_node + 2; // Start j from i+1
                    end else begin
                        // Check pair (walk_node, walk_dest)
                        if (subset_mask[walk_node] && subset_mask[walk_dest]) begin
                            if (!compat_matrix[walk_node][walk_dest]) begin
                                visited[0] <= 1'b0; // Invalid
                                // Optimization: Can break early?
                                // Let's go to next subset immediately next cycle.
                                // We need to fast forward the iteration.
                                // Let's set a flag 'early_exit' in walk_step? 
                                // Or just let the loop finish, it's fast enough (max 28 iterations).
                                // With 2000 cycles, 255 * 28 = 7140. This is too slow.
                                // We MUST optimize.
                                
                                // Optimization Strategy:
                                // Max independent set on 8 nodes.
                                // We can use a recursive backtracking or smarter iteration.
                                // But here we are asked for brute force.
                                // Let's try to check validity faster.
                                // 
                                // Idea: Compute a 'valid_mask' for each producer i.
                                // valid_mask[i] = mask of producers compatible with i.
                                // Then subset S is valid if for all i in S, (S \\ {i}) subset of valid_mask[i].
                                // 
                                // Let's check: if subset_mask is not valid, break.
                                // We can stop iterating pairs as soon as we find a mismatch.
                                // 
                                // To fit in 2000 cycles, we assume 2000 cycles is sufficient for the problem spec.
                                // If K=8, 255 subsets. 2000/255 = 7.8 cycles/subset.
                                // We can check validity in 7 cycles if we unroll or parallelize.
                                // But we are writing synthesizable RTL.
                                // 
                                // Let's proceed with the loop but optimize the cycle count.
                                // If we stay in this state, we increment walk_dest.
                            end
                        end
                        walk_dest <= walk_dest + 1;
                    end
                end

                FIND_MAX_SET_UPDATE: begin
                    if (temp_count > best_count) begin
                        best_count <= temp_count;
                        best_subset <= subset_mask;
                    end
                    state <= FIND_MAX_SET_NEXT;
                end

                FIND_MAX_SET_NEXT: begin
                    // Next subset
                    subset_mask <= subset_mask + 1;
                    // Reset validity flag
                    visited[0] <= 1'b1;
                    // Check if we are done (subset_mask == 0 wraps around after 255)
                    if (subset_mask == 8'b11111111) begin // Or check against 2^K
                        // Actually, K producers. We only care about bits < K.
                        // If subset_mask exceeds 2^K - 1, we are done.
                        // 2^K = 1 << K.
                        if (subset_mask >= (1 << K)) begin
                            max_producers <= best_count;
                            state <= DONE;
                        end else begin
                            // Reset check state
                            walk_node <= 0;
                            walk_dest <= 0;
                            state <= FIND_MAX_SET_CHECK;
                        end
                    end else begin
                         if (subset_mask >= (1 << K)) begin // Should be <= 255. If K=8, 1<<8=256. subset_mask goes 0..255.
                            // Actually if K<8, say K=3, we only want masks 0..7.
                            // 1<<3 = 8. 
                            // So check if subset_mask >= (1 << K). 
                            // Wait, subset_mask starts at 1. 
                            // If K=1, mask 1 is valid, mask 2 (10) is invalid (since bit 1 is set, but K=1, only bit 0 exists).
                            // So we must ensure we only use bits < K.
                            // Let's just iterate mask from 1 to (1<<K)-1.
                            // 
                            // Let's change the loop logic:
                            // Start subset_mask = 1.
                            // End when subset_mask == (1 << K).
                            // So check if subset_mask == (1 << K).
                            // But 1 << K for K=8 is 256, which doesn't fit in 8 bits (256 is 9 bits).
                            // subset_mask is [2:0] in prompt? No, it's [7:0] implied by 8 producers.
                            // Prompt says K max 8. So subset_mask should be 8 bits.
                            // Wait, prompt: "output reg [2:0] max_producers". K is [2:0].
                            // So K is 3 bits. Max 8. So K=8 is 1000.
                            // 1 << K when K=8 is 256. 
                            // If subset_mask is 8 bits, it wraps to 0 at 256.
                            // So condition subset_mask == 0 means we finished all 256 possibilities (0 to 255).
                            // But we only want up to 2^K - 1.
                            // So check if subset_mask == 0 (wrapped) OR if subset_mask >= (1 << K).
                            // Let's just check if subset_mask == 0 after increment.
                            // Since we skip empty set (start at 1), 0 means wrapped.
                            // But if K=8, valid masks are 1..255. 255+1=0. So 0 is end.
                            // If K=3, valid masks 1..7. 7+1=8. 8 is valid? No, 8 is bit 3 set.
                            // So we need to check bits >= K.
                            // Check: if subset_mask has any bit set >= K, then skip?
                            // Or simpler: loop while subset_mask < (1 << K).
                            // Since (1 << K) might be 256, we can't store it in 8 bits if we want to compare.
                            // But we can check bits.
                            // If subset_mask[7] is 1 and K<8, it's invalid.
                            // We can just iterate 255 times (for K=8) or less.
                            // If K<8, we will check some invalid masks. That's fine, they will fail validity check.
                            // So we can just iterate mask from 1 to 255.
                            // When mask becomes 0, we are done.
                            
                            if (subset_mask == 0) begin
                                max_producers <= best_count;
                                state <= DONE;
                            end else begin
                                walk_node <= 0;
                                walk_dest <= 0;
                                state <= FIND_MAX_SET_CHECK;
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // Combinational Logic for BFS Neighbor Processing
    // We need to unroll the BFS neighbor check. 
    // The state BUILD_PATHS_BFS had an issue: it dequeued but didn't immediately process neighbors in the same state if we want to be cycle-accurate.
    // Let's refine BUILD_PATHS_BFS logic in combinational block or use a more explicit state.
    // To keep the FSM simple, let's use a combinational always block to drive next state logic or helper signals.
    
    // However, standard Verilog style often prefers everything in the sequential block.
    // Let's adjust the BFS state logic inside the sequential block to handle neighbors properly.
    // 
    // Redefining BUILD_PATHS_BFS:
    // We iterate queue. For each u, we iterate v=1..N. If adj[u][v] and !visited[v], enqueue.
    // This can take 1 cycle per u (if we check all v in parallel or sequentially in sub-states).
    // Since N is small (8), we can check all v in 1 cycle (combinational check).
    // 
    // Let's modify the BFS state to do:
    // If q_head < q_tail:
    //    u = queue[q_head]
    //    For v=1 to N: if adj[u-1][v-1] and !visited[v-1], then enqueue v.
    //    Increment q_head.
    // 
    // This requires an 'always_comb' or blocking assignment inside the sequential block, or a separate combinational block.
    // Let's use an always_comb block for the BFS enqueue logic.

    // --- Combinational Logic Section ---
    
    reg [2:0] bfs_u;
    reg [2:0] bfs_v;
    reg [7:0] new_visited;
    reg [2:0] new_q_tail;
    reg [2:0] new_queue [0:7];
    reg [3:0] new_bfs_dist [0:7];
    
    always @(*) begin
        // Defaults
        new_visited = visited;
        new_q_tail = q_tail;
        new_bfs_dist = bfs_dist;
        for (int k = 0; k < 8; k++) new_queue[k] = queue[k];
        
        if (state == BUILD_PATHS_BFS && q_head < q_tail) begin
            bfs_u = queue[q_head];
            // Check all neighbors v from 1 to N
            for (int v_idx = 1; v_idx <= 8; v_idx++) begin
                if (v_idx <= N) begin
                    if (adj_matrix[bfs_u - 1][v_idx - 1] && !visited[v_idx - 1]) begin
                        new_visited[v_idx - 1] = 1'b1;
                        new_queue[new_q_tail] = v_idx;
                        new_q_tail = new_q_tail + 1;
                        new_bfs_dist[v_idx - 1] = bfs_dist[bfs_u - 1] + 1;
                    end
                end
            end
        end
    end

    // --- Compatibility Check Combinational Logic ---
    // To speed up compatibility check (Iterate edges)
    reg pair_collision;
    always @(*) begin
        pair_collision = 0;
        if (state == CHECK_COMPATIBILITY && walk_step == 0) begin
            // We need to check if prod_i and prod_j collide.
            // We iterate edges (u,v) where adj_matrix[u][v] == 1.
            // If path_i uses u->v AND path_j uses u->v AND (dist_i[u] - dist_j[u]) is even -> Collision.
            // Since we are in combinational block, we can iterate all edges at once (fully parallel) or just check the current edge in a loop.
            // Wait, in the FSM I set walk_node=1, walk_dest=1.
            // To make it fast, let's just compute collision fully parallel here and update registers in sequential logic.
            // This avoids the need for the iteration loop in the FSM.
            // This consumes more logic gates but meets timing/latency.
            
            for (int u = 0; u < 8; u++) begin
                for (int v = 0; v < 8; v++) begin
                    if (adj_matrix[u][v]) begin
                        // Check if both producers use this edge
                        // u is 0-indexed, producers are prod_i, prod_j (1-indexed)
                        // dist_matrix index is producer-1
                        // dist_matrix[prod_i-1][u] + 1 == dist_matrix[prod_i-1][v] ?
                        // Note: If a producer is unreachable, path_len is F, dist_matrix might be 0 or F.
                        // We should ignore if dist_matrix is 0 (except for source).
                        // Actually, if producer cannot reach N, it doesn't matter, but we assume all reachable or handle it.
                        // If a producer is unreachable, it can't run.
                        
                        // Check Path i usage of u->v
                        // Note: BFS initializes dist[source] = 0. dist[others] = ? (Should init to INF or 0)
                        // In the sequential logic, we must ensure dist_matrix is initialized to INF or 0 properly.
                        // Let's assume dist_matrix tracks distances from producer.
                        // If dist_matrix[p][u] is valid and dist_matrix[p][v] == dist_matrix[p][u] + 1, then it's on a shortest path.
                        
                        // Edge u->v is used by P_i if:
                        //   dist_matrix[i][u] != INF && dist_matrix[i][v] == dist_matrix[i][u] + 1
                        // Collision if:
                        //   (dist_matrix[i][u] - dist_matrix[j][u]) is even.
                        
                        // Using 4'hF as INF (15).
                        if ((dist_matrix[prod_i - 1][u] != 4'hF) && (dist_matrix[prod_i - 1][v] == dist_matrix[prod_i - 1][u] + 1) &&
                            (dist_matrix[prod_j - 1][u] != 4'hF) && (dist_matrix[prod_j - 1][v] == dist_matrix[prod_j - 1][u] + 1)) begin
                            
                            if ((dist_matrix[prod_i - 1][u] - dist_matrix[prod_j - 1][u]) % 2 == 0) begin
                                pair_collision = 1;
                            end
                        end
                    end
                end
            end
        end
    end

    // --- Sequential Logic Update for BFS and Compatibility ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            // BFS Update
            if (state == BUILD_PATHS_BFS && q_head < q_tail) begin
                visited <= new_visited;
                q_tail <= new_q_tail;
                for (int k = 0; k < 8; k++) begin
                    queue[k] <= new_queue[k];
                    bfs_dist[k] <= new_bfs_dist[k];
                end
            end

            // Compatibility Update
            // If we are in CHECK_COMPATIBILITY state and we just computed collision
            if (state == CHECK_COMPATIBILITY && walk_step == 0) begin
                // Update compat_matrix
                if (pair_collision) begin
                    compat_matrix[prod_i - 1][prod_j - 1] <= 0;
                    compat_matrix[prod_j - 1][prod_i - 1] <= 0;
                end else begin
                    compat_matrix[prod_i - 1][prod_j - 1] <= 1;
                    compat_matrix[prod_j - 1][prod_i - 1] <= 1;
                end
                
                // Advance to next pair
                walk_step <= 1; // Mark as processed
                
                // Increment indices in the next cycle (handle in the main FSM block logic)
                // We need to increment prod_j/prod_i in the main block logic for CHECK_COMPATIBILITY.
                // But the main block logic is inside the 'always @(posedge clk)'.
                // To make the iteration flow:
                // In the main block case(CHECK_COMPATIBILITY):
                //   if (walk_step == 1) begin prod_j++; walk_step <= 0; end
                //   else begin // wait for combinational logic? No, combinational logic updates 'pair_collision' immediately.
                //   Actually, the combinational logic triggers on 'state' and 'walk_step' and 'dist_matrix'.
                //   Since 'dist_matrix' is stable, 'pair_collision' is available in the same cycle.
                //   So we can update compat_matrix and advance indices all in one cycle.
                //   But we need to ensure 'pair_collision' is available before the clock edge.
                //   It is.
                //   So we can just update indices here.
                //   Wait, if we update indices here, we need to handle the case where we are done with pairs.
                
                // Let's move the index increment logic here to avoid extra state cycles.
                // Logic from CHECK_COMPATIBILITY state:
                // If prod_i > K ... (checked before entering state)
                // If prod_j > K ... 
                // Else: check pair.
                // So here we just did the check. Now increment.
                
                // Increment logic:
                if (prod_j == K) begin
                    prod_i <= prod_i + 1;
                    prod_j <= prod_i + 2; // Wait, prod_i just updated? No.
                    // If prod_i=1, prod_j=2. Check done. prod_j=2. K=3.
                    // prod_j == K (3)? No.
                    // prod_j++ -> 3.
                    // Next: prod_i=1, prod_j=3. Check done. prod_j==K (3). Yes.
                    // prod_i++ -> 2. prod_j = 2+2 = 4.
                    // 4 > K. 
                    // So we need to handle the boundary.
                    // If prod_j == K, then prod_i++, prod_j = prod_i + 2.
                    // But we must ensure prod_i + 2 <= K ? No, we check > K later.
                    
                    prod_j <= prod_i + 2; // This uses OLD prod_i.
                    prod_i <= prod_i + 1;
                end else begin
                    prod_j <= prod_j + 1;
                end
            end
        end
    end

    // Fix for Compatibility State Transition in Main FSM
    // We need to check if we are done with all pairs.
    // Since we moved increment logic to sequential block, we need to detect end of pairs in main block.
    // We can check if (state == CHECK_COMPATIBILITY && walk_step == 1) then check if next pair is valid.
    // Or simpler: If (prod_i > K) transition to next state.
    // But we update prod_i/prod_j in the sequential block.
    // So in the main FSM block, we check condition BEFORE updating.
    // Wait, the sequential block executes AFTER the combinational logic.
    // The logic flow:
    // 1. Combinational block computes pair_collision based on current (prod_i, prod_j).
    // 2. Main FSM block is in CHECK_COMPATIBILITY.
    // 3. If walk_step == 0, we do nothing in main block (wait).
    // 4. If walk_step == 1, we just finished an iteration.
    //    Ideally, we want to start next iteration immediately.
    //    So in main block, if state == CHECK_COMPATIBILITY, we can check if we are done.
    //    If not done, we stay in state. But we need to reset walk_step to 0.
    
    // Revised Main FSM block for CHECK_COMPATIBILITY:
    // In the always block:
    // ...
    // CHECK_COMPATIBILITY: begin
    //     if (prod_i > K) begin state <= FIND_MAX_SET; ... end
    //     else if (walk_step == 1) begin
    //         // We just updated compat_matrix.
    //         // Increment indices.
    //         // Need to check if next iteration is needed.
    //         // Increment logic:
    //         reg [2:0] next_prod_j = (prod_j == K) ? prod_i + 2 : prod_j + 1;
    //         reg [2:0] next_prod_i = (prod_j == K) ? prod_i + 1 : prod_i;
    //         
    //         // Check bounds
    //         if (next_prod_i > K) begin
    //             state <= FIND_MAX_SET;
    //             subset_mask <= 1;
    //         end else begin
    //             prod_i <= next_prod_i;
    //             prod_j <= next_prod_j;
    //             walk_step <= 0; // Trigger next check
    //         end
    //     end
    //     else begin
    //         // walk_step == 0. This is the first cycle of a pair check.
    //         // The combinational logic has computed pair_collision.
    //         // But the sequential update happens at end of cycle.
    //         // So we need to wait 1 cycle for the sequential update to happen? 
    //         // No, we can update compat_matrix in the sequential block immediately if we are in this state.
    //         // Let's use the sequential block to update compat_matrix.
    //         // 
    //         // Let's simplify:
    //         // Cycle 1: State = CHECK, walk_step = 0. Combinational logic sets pair_collision.
    //         //         Sequential block sees State=CHECK, walk_step=0. It does nothing yet? 
    //         //         Wait, if sequential block updates compat_matrix NOW, it uses 'pair_collision' which is valid NOW.
    //         //         So we can update compat_matrix NOW.
    //         //         And we can increment indices NOW?
    //         //         If we increment indices NOW, then in the same cycle, 'prod_i', 'prod_j' update.
    //         //         But 'pair_collision' was computed based on OLD 'prod_i', 'prod_j'.
    //         //         This is fine.
    //         //         However, we must ensure we don't skip states.
    //         //         
    //         //         So in the sequential block (inside always @posedge):
    //         //         if (state == CHECK_COMPATIBILITY) begin
    //         //            // Update compat matrix based on 'pair_collision'
    //         //            compat_matrix[prod_i-1][prod_j-1] <= !pair_collision;
    //         //            // Increment indices logic...
    //         //            // If done, next state.
    //         //            // Else, stay in state (which effectively does next pair in next cycle).
    //         //         end
    //         //         
    //         //         This means we don't need walk_step.
    //         //         We just iterate one pair per cycle.
    //         //         Total pairs = 28. 28 cycles.
    //         //         This fits easily in 2000 cycles.
    //         //         Let's do this.
    //     end
    // end

endmodule

// Note: The code above implements the logic. 
// The actual Verilog code string needs to be merged carefully.
// The provided code in the 'always @(posedge clk)' block implements the logic flow.
// The 'always @(*)' block implements the combinational helper logic.

// To ensure correctness, the sequential block must handle the state transitions and updates.
// Let's rewrite the state machine parts to be cleaner and ensure it fits the synthesizable requirement.

module producer_routing_final(
    input clk,
    input rst_n,
    input start,
    input [2:0] K,
    input [2:0] N,
    input [5:0] M,
    input [2:0] edge_a,
    input [2:0] edge_b,
    input edges_valid,
    input edges_done,
    output reg [2:0] max_producers,
    output reg done
);

    // State Definitions
    localparam IDLE = 0;
    localparam LOAD_EDGES = 1;
    localparam BUILD_PATHS = 2;
    localparam CHECK_COMPAT = 3;
    localparam FIND_MAX_SET = 4;
    localparam DONE = 5;

    reg [2:0] state;
    
    // Storage
    reg [7:0] adj [0:7]; // Adjacency
    reg [3:0] dist [0:7] [0:7]; // dist[prod_idx][node]
    reg [7:0] compat [0:7]; // compat[i] bitmask of compatible producers
    
    // Counters and Indices
    reg [2:0] prod_idx; // 1..K
    reg [2:0] node_idx; // 1..N or 0..7
    reg [2:0] i, j; // For pair loops
    reg [5:0] m_cnt;
    reg [7:0] mask;
    reg [2:0] best;
    reg [2:0] count;
    
    // BFS Registers
    reg [7:0] visited;
    reg [7:0] q [0:7];
    reg [2:0] q_head, q_tail;
    reg [3:0] d [0:7]; // Current BFS distances
    reg [2:0] u, v;
    
    // Helper: Find max independent set
    // We'll iterate masks. 0 to 255. 
    // To be efficient, we iterate all masks.
    // Since K <= 8, we can just check all 255 masks.
    // We can use a loop in combinational logic or sequential.
    // Sequential is safer for timing.
    
    // Combinational logic for BFS neighbor processing (Parallel scan of N)
    // And for Compatibility check (Parallel scan of edges)
    
    reg [7:0] next_visited;
    reg [2:0] next_q_head, next_q_tail;
    reg [3:0] next_d [0:7];
    reg [7:0] next_q [0:7];
    
    reg collision_flag;
    
    integer k, l;

    always @(*) begin
        // Default BFS update
        next_visited = visited;
        next_q_head = q_head;
        next_q_tail = q_tail;
        next_d = d;
        next_q = q;
        
        if (state == BUILD_PATHS && q_head < q_tail) begin
            // Dequeue u
            u = q[q_head];
            next_q_head = q_head + 1;
            // Scan all potential neighbors v (0 to 7)
            for (l = 0; l < 8; l = l + 1) begin
                if (l < N && adj[u][l] && !visited[l]) begin
                    next_visited[l] = 1'b1;
                    next_q[next_q_tail] = l[2:0];
                    next_q_tail = next_q_tail + 1;
                    next_d[l] = d[u] + 1;
                end
            end
        end

        // Default Compatibility update
        collision_flag = 0;
        if (state == CHECK_COMPAT) begin
            // Check pair (i, j)
            // i and j are 0-indexed producer indices here (mapped from 1..K)
            // We iterate edges u->v. 
            // If edge used by both and (dist[u] parity diff == 0) -> Collision.
            
            for (int eu = 0; eu < 8; eu = eu + 1) begin
                for (int ev = 0; ev < 8; ev = ev + 1) begin
                    if (adj[eu][ev]) begin
                        // Check path i
                        if (dist[i][eu] != 4'hF && dist[i][ev] == dist[i][eu] + 1 &&
                            dist[j][eu] != 4'hF && dist[j][ev] == dist[j][eu] + 1) begin
                            if ((dist[i][eu] - dist[j][eu]) % 2 == 0) begin
                                collision_flag = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_producers <= 0;
            // Reset adj
            for (int r = 0; r < 8; r++) adj[r] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        m_cnt <= 0;
                        state <= LOAD_EDGES;
                    end
                end

                LOAD_EDGES: begin
                    if (edges_valid) begin
                        if (edge_a >= 1 && edge_a <= N && edge_b >= 1 && edge_b <= N) begin
                            adj[edge_a - 1][edge_b - 1] <= 1'b1;
                        end
                        m_cnt <= m_cnt + 1;
                    end
                    if (edges_done) begin
                        prod_idx <= 1;
                        state <= BUILD_PATHS;
                    end
                end

                BUILD_PATHS: begin
                    if (prod_idx > K) begin
                        // All paths built. Initialize compat matrix.
                        // Assuming all are compatible initially.
                        for (int p = 0; p < 8; p++) compat[p] <= 8'hFF;
                        // Ensure diagonal is 0
                        for (int p = 0; p < 8; p++) compat[p][p] <= 1'b0;
                        i <= 0;
                        j <= 1;
                        state <= CHECK_COMPAT;
                    end else begin
                        // Initialize BFS for this producer
                        // Source node = prod_idx - 1 (0-indexed junction)
                        // Note: Producers are at junctions 1..K. 
                        // So source index is prod_idx - 1.
                        
                        // Reset BFS vars
                        visited <= 0;
                        q_head <= 0;
                        q_tail <= 0;
                        // Reset distances to INF (15)
                        for (int r = 0; r < 8; r++) d[r] <= 4'hF;
                        
                        // Enqueue source
                        // If source is < N (since N is warehouse, producer at K <= N)
                        if (prod_idx <= N) begin
                            visited[prod_idx - 1] <= 1'b1;
                            q[0] <= prod_idx - 1;
                            q_tail <= 1;
                            d[prod_idx - 1] <= 0;
                        end
                        
                        // BFS Loop
                        // We stay in this state until queue empty.
                        // The combinational logic updates registers based on current state.
                        // We need to check if queue is empty to transition.
                        
                        // Update registers from combinational logic
                        visited <= next_visited;
                        q_head <= next_q_head;
                        q_tail <= next_q_tail;
                        d <= next_d;
                        q <= next_q;
                        
                        // If queue empty (q_head >= q_tail), move to next producer
                        if (q_head >= q_tail && q_head != 0) begin // q_head != 0 handles empty init case
                            // Save distances for this producer to dist matrix
                            for (int r = 0; r < 8; r++) begin
                                dist[prod_idx - 1][r] <= d[r];
                            end
                            prod_idx <= prod_idx + 1;
                        end
                        // Otherwise stay in BUILD_PATHS to continue BFS
                    end
                end

                CHECK_COMPAT: begin
                    // The combinational block calculates collision_flag.
                    // Update compat matrix based on collision_flag.
                    if (collision_flag) begin
                        compat[i][j] <= 1'b0;
                        compat[j][i] <= 1'b0;
                    end
                    
                    // Increment indices
                    if (j == K - 1) begin // j is 0-indexed, K-1 is max index
                        i <= i + 1;
                        j <= i + 2;
                    end else begin
                        j <= j + 1;
                    end
                    
                    // Check termination: if i >= K-1 (and j would be >= K)
                    // If i == K-1, j goes to K+1? No.
                    // If i == K-1, j is K-1? No j starts at i+1.
                    // If i == K-1, j == K. Since j is 3 bits, K is valid.
                    // If K=8, indices 0..7. i=7, j=8 (1000).
                    // If j >= K, we are done.
                    // Actually, we need to check if the pair (i,j) is valid before processing.
                    // The loop structure: 
                    // If i >= K -> Done.
                    // Else if j >= K -> next i.
                    // But we update here.
                    // Let's check condition BEFORE update? No, standard to update then check.
                    // But we need to know when to leave state.
                    
                    // Termination logic:
                    // If (i >= K-1 && j >= K) or (i >= K) -> Done.
                    // Let's check: if (j >= K || i >= K) after increment? 
                    // If we just incremented, and now j >= K, next iteration would be invalid.
                    // But we just processed (i, j-1) or (i, j) depending on logic.
                    // Let's rely on the simple condition:
                    // If i == K-1 and j == K (after increment), we are done with the last pair (K-2, K-1) -> (K-1, K) ??
                    // Producers are 1..K. Indices 0..K-1.
                    // Pairs: (0,1), (0,2)... (0, K-1), (1,2)... (K-2, K-1).
                    // Last pair is (K-2, K-1).
                    // After processing (K-2, K-1):
                    // i = K-2. j = K-1.
                    // Increment: j == K-1, so j++ -> j=K.
                    // Check: j >= K.
                    // Next: i++ -> i = K-1. j = i+2 = K+1.
                    // Now i >= K-1 and j >= K.
                    
                    if (i >= K - 1 && j >= K) begin
                        state <= FIND_MAX_SET;
                        mask <= 1; // Start from subset 1
                        best <= 0;
                    end
                end

                FIND_MAX_SET: begin
                    // We check subset 'mask'.
                    // 1. Check if mask is valid subset (only bits < K).
                    //    Actually, if K < 8, we should check if mask bits outside range are set.
                    //    But if we just iterate 1..2^K-1, we can check validity inside.
                    //    Or we can iterate 0..255 and ignore invalid masks.
                    //    Let's iterate 0..255. If mask wraps to 0, we are done.
                    
                    // Check Validity of mask:
                    // Is mask a subset of (1<<K)-1? No, we need to ensure no bits >= K are set.
                    // Actually, if K=3, (1<<3)-1 = 7 (111). Mask 8 (1000) is invalid.
                    // So check: if (mask & ~((1<<K)-1)) != 0, then invalid.
                    // Since K is variable, we compute (1<<K).
                    // But K is 3 bits. 1<<K can be up to 256.
                    // Since mask is 8 bits, we can compare.
                    // If K==8, (1<<K) is 256. mask < 256 always (since 8 bits). So all valid.
                    // If K < 8, we check.
                    
                    // To save logic, we can just check if mask has bits set >= K.
                    // This is a priority check.
                    
                    // Optimization: 
                    // Since 255 subsets is small, we can just check all.
                    // However, we need to check validity and compatibility.
                    // We can do this in one cycle using combinational logic for validity and compatibility.
                    // But we are in a sequential block.
                    // Let's use combinational logic to calculate: Is 'mask' valid and independent?
                    // And Is 'mask' > best?
                    // If yes, update best.
                    
                    // We can iterate states: 
                    // Just stay in FIND_MAX_SET, increment mask.
                    // Use combinational block to calculate 'is_valid_and_independent'.
                    // If valid, calculate popcount and compare to best.
                    
                    if (mask == 0) begin
                        max_producers <= best;
                        state <= DONE;
                    end else begin
                        // Check validity:
                        // If K < 8, check bits >= K.
                        // e.g. K=3, mask=8 (bit 3). 
                        // Valid bits are 0, 1, 2.
                        // Check: (mask >> K) != 0 ?
                        // If K=3, mask >> 3 = 1 (if mask=8). 
                        // So check if (mask >> K) != 0.
                        // But shift amount must be constant or variable? 
                        // Variable shift is synthesizable (usually).
                        
                        if ((mask >> K) == 0) begin
                            // Valid mask range. Now check independence.
                            // A mask is independent if for all i in mask, (compat[i] & mask) == mask without i.
                            // Or simpler: for all i, j in mask (i<j), compat[i][j] == 1.
                            // We can do this with a loop in combinational block or logic.
                            // Let's assume a helper signal 'valid_subset' computed combinationally.
                            
                            // Since we can't easily do nested loops in one synthesisable always block without sub-states,
                            // let's use a brute force check logic.
                            // For K=8, max 28 pairs.
                            // We can unroll the check for specific K? No, K is input.
                            // 
                            // Let's use the fact that we are iterating sequentially.
                            // We can iterate i and j in sub-states? No, that's slow.
                            // 
                            // Let's use combinational logic 'is_independent'.
                            // We will define it outside or infer it.
                            // 
                            // But wait, the prompt implies approx 2000 cycles.
                            // 2000 cycles / 255 subsets = ~7.8 cycles/subset.
                            // We can spend 7 cycles to check validity.
                            // Or 1 cycle if we parallelize.
                            
                            // Let's try to parallelize.
                            // Check: 
                            // Condition 1: (mask >> K) == 0. (1 cycle or combinational)
                            // Condition 2: Independence. 
                            // We can define a combinational block that computes independence for the current 'mask'.
                            // 
                            // Let's define 'valid_independent' combinationally.
                            // 
                            // If valid_independent, then update best.
                            
                            // Let's assume 'valid_independent' is computed combinationally.
                            // We need to implement it.
                            
                            // Actually, let's just do the check in the FSM with a small loop.
                            // Since 28 pairs is small, let's use 'i' and 'j' registers to iterate pairs for the current mask.
                            // This is a sub-loop.
                            // We can reuse 'i' and 'j' from the compat check? No, they were used there.
                            // Let's use 'prod_idx' and 'node_idx' for this loop.
                            // 
                            // Sub-state for mask check:
                            // Reset prod_idx=0, node_idx=1. Assume valid.
                            // Loop:
                            // If prod_idx >= K: done checking. If valid, update best.
                            // If node_idx >= K: prod_idx++, node_idx=prod_idx+1.
                            // Else: if mask[prod_idx] && mask[node_idx] && !compat[prod_idx][node_idx] -> Invalid.
                            //      node_idx++.
                            
                            // This requires a separate state logic or nesting.
                            // Given the "2000 cycles" constraint, we might be tight with nested loops.
                            // 255 subsets * ~28 pairs = 7140 checks. 
                            // But if we only check valid subsets (where bits < K), how many valid subsets?
                            // For K=8, 255 subsets.
                            // For K=4, 15 subsets.
                            // 
                            // Maybe the 2000 cycles is for the whole process, and we can assume K is usually smaller? 
                            // Or we need a more optimized solver.
                            // 
                            // Wait, the prompt says "Approximately 2000 clock cycles (sufficient for K=8, N=8, M=1000)".
                            // This implies we MUST find a solution that fits in 2000 cycles for K=8.
                            // 255 subsets.
                            // If we spend 1 cycle per subset, we need to check validity in 1 cycle.
                            // This implies combinational logic for subset validity.
                            // 
                            // Let's implement the subset validity check combinationally.
                            // 
                            // Logic:
                            // wire [7:0] valid_bits = mask & ~((1 << K) - 1);
                            // wire range_valid = (valid_bits == 0);
                            // wire independent = 1'b1;
                            // // Check all pairs
                            // // This is a large combinational loop, but for 8 nodes, it's manageable.
                            // // We can use a generate block or nested loops in combinational always.
                            // 
                            // Let's implement this logic in the sequential block by assuming it's done in 0 cycles (combinational).
                            // But we need to handle the logic inside.
                            // 
                            // Let's create a combinational block for 'subset_valid_and_independent'.
                            // Since we are writing the code as a string, we can define it.
                            // 
                            // But we are inside the module. 
                            // We will calculate 'independent' combinationally.
                            // 
                            // Then in sequential block:
                            // if (range_valid && independent) begin
                            //    count = popcount(mask);
                            //    if (count > best) best <= count;
                            // end
                            // mask <= mask + 1;
                            // 
                            // This takes 1 cycle per mask. 255 cycles + overhead. Fits in 2000.
                            
                            // Implementation detail: Nested loops for 'independent' are fine in combinational block.
                        end
                        
                        mask <= mask + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // Combinational Logic for Subset Validity and Independence
    reg subset_ok;
    reg [7:0] valid_bits;
    integer p, q;
    
    always @(*) begin
        // Check range
        valid_bits = mask >> K;
        if (valid_bits != 0) begin
            subset_ok = 0;
        end else begin
            // Check independence
            subset_ok = 1;
            // Iterate pairs
            for (p = 0; p < 8; p = p + 1) begin
                for (q = p + 1; q < 8; q = q + 1) begin
                    if (mask[p] && mask[q]) begin
                        if (!compat[p][q]) begin
                            subset_ok = 0;
                        end
                    end
                end
            end
        end
    end

    // Update for FIND_MAX_SET state to use this combinational logic
    // We need to modify the sequential block logic for FIND_MAX_SET.
    // In the sequential block above, I had a comment about using combinational logic.
    // Let's explicitly update that part.
    // We can't easily modify the code block string once written, but we can ensure the logic flows.
    // The sequential block for FIND_MAX_SET currently does:
    // if (mask == 0) done.
    // else if ((mask >> K) == 0) ... 
    // This is incomplete without the independent check.
    
    // Let's refine the FIND_MAX_SET sequential block to be correct.
    // Since we need to output the final code string, I will assume the sequential block needs to be fully specified.
    
    // Re-write the FIND_MAX_SET block logic in the sequential process:
    // It will look like:
    /*
    FIND_MAX_SET: begin
        if (mask == 0) begin
            max_producers <= best;
            state <= DONE;
        end else begin
            if (subset_ok) begin
                count = popcount(mask);
                if (count > best) best <= count;
            end
            mask <= mask + 1;
        end
    end
    */
    // And we keep the combinational block for 'subset_ok'.

endmodule

// Note: The actual module provided in the final response must be a single module.
// I will combine the sequential logic and combinational logic into one module 'producer_routing'.
// I will include the 'subset_ok' logic.

module producer_routing(
    input clk,
    input rst_n,
    input start,
    input [2:0] K,
    input [2:0] N,
    input [5:0] M,
    input [2:0] edge_a,
    input [2:0] edge_b,
    input edges_valid,
    input edges_done,
    output reg [2:0] max_producers,
    output reg done
);

    // State Definitions
    localparam IDLE = 0;
    localparam LOAD_EDGES = 1;
    localparam BUILD_PATHS = 2;
    localparam CHECK_COMPAT = 3;
    localparam FIND_MAX_SET = 4;
    localparam DONE = 5;

    reg [2:0] state;
    
    // Storage
    reg [7:0] adj [0:7];
    reg [3:0] dist [0:7] [0:7];
    reg [7:0] compat [0:7];
    
    // Indices
    reg [2:0] prod_idx; // 1..K
    reg [2:0] i, j; // For loops
    reg [7:0] mask;
    reg [2:0] best;
    reg [2:0] count;
    
    // BFS Registers
    reg [7:0] visited;
    reg [7:0] q [0:7];
    reg [2:0] q_head, q_tail;
    reg [3:0] d [0:7];
    reg [2:0] u;
    
    // Combinational BFS Updates
    reg [7:0] next_visited;
    reg [2:0] next_q_head, next_q_tail;
    reg [3:0] next_d [0:7];
    reg [7:0] next_q [0:7];
    
    // Combinational Collision Check
    reg collision_flag;
    
    // Combinational Subset Check
    reg subset_ok;
    reg [7:0] valid_bits;
    
    integer l, p, q_idx;
    
    // --- Combinational Logic ---
    always @(*) begin
        // 1. BFS Updates
        next_visited = visited;
        next_q_head = q_head;
        next_q_tail = q_tail;
        next_d = d;
        next_q = q;
        
        if (state == BUILD_PATHS && q_head < q_tail) begin
            u = q[q_head];
            next_q_head = q_head + 1;
            for (l = 0; l < 8; l++) begin
                if (l < N && adj[u][l] && !visited[l]) begin
                    next_visited[l] = 1'b1;
                    next_q[next_q_tail] = l[2:0];
                    next_q_tail = next_q_tail + 1;
                    next_d[l] = d[u] + 1;
                end
            end
        end

        // 2. Compatibility Collision Check
        collision_flag = 0;
        if (state == CHECK_COMPAT) begin
            // i, j are 0-indexed producers to check
            for (int eu = 0; eu < 8; eu++) begin
                for (int ev = 0; ev < 8; ev++) begin
                    if (adj[eu][ev]) begin
                        if (dist[i][eu] != 4'hF && dist[i][ev] == dist[i][eu] + 1 &&
                            dist[j][eu] != 4'hF && dist[j][ev] == dist[j][eu] + 1) begin
                            if ((dist[i][eu] - dist[j][eu]) % 2 == 0) begin
                                collision_flag = 1;
                            end
                        end
                    end
                end
            end
        end

        // 3. Subset Validity & Independence Check
        subset_ok = 0;
        if (state == FIND_MAX_SET && mask != 0) begin
            valid_bits = mask >> K;
            if (valid_bits == 0) begin
                // Check independence
                subset_ok = 1;
                for (p = 0; p < 8; p++) begin
                    for (q_idx = p + 1; q_idx < 8; q_idx++) begin
                        if (mask[p] && mask[q_idx] && !compat[p][q_idx]) begin
                            subset_ok = 0;
                        end
                    end
                end
            end
        end
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_producers <= 0;
            for (int r = 0; r < 8; r++) adj[r] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_EDGES;
                    end
                end

                LOAD_EDGES: begin
                    if (edges_valid) begin
                        if (edge_a >= 1 && edge_a <= N && edge_b >= 1 && edge_b <= N) begin
                            adj[edge_a - 1][edge_b - 1] <= 1'b1;
                        end
                    end
                    if (edges_done) begin
                        prod_idx <= 1;
                        state <= BUILD_PATHS;
                    end
                end

                BUILD_PATHS: begin
                    if (prod_idx > K) begin
                        // Initialize compat matrix
                        for (int p = 0; p < 8; p++) compat[p] <= 8'hFF;
                        for (int p = 0; p < 8; p++) compat[p][p] <= 1'b0;
                        i <= 0;
                        j <= 1;
                        state <= CHECK_COMPAT;
                    end else begin
                        // Update BFS registers
                        visited <= next_visited;
                        q_head <= next_q_head;
                        q_tail <= next_q_tail;
                        d <= next_d;
                        q <= next_q;
                        
                        // Check if BFS finished for this producer
                        if (q_head >= q_tail && q_head != 0) begin
                            for (int r = 0; r < 8; r++) begin
                                dist[prod_idx - 1][r] <= d[r];
                            end
                            prod_idx <= prod_idx + 1;
                            // Reset BFS for next producer (done in next cycle implicitly by checking prod_idx)
                            // We need to ensure visited etc are reset for the new producer.
                            // But 'visited' is updated from 'next_visited' above.
                            // If we are starting a new producer, we need to reset 'visited' and 'q'.
                            // However, 'next_visited' logic depends on current state.
                            // When q_head >= q_tail, we are done. In next cycle, prod_idx is incremented.
                            // The combinational block will run again.
                            // But 'visited' still holds old values.
                            // We need to force reset of BFS registers when starting a new producer.
                            // This happens when we enter BUILD_PATHS with prod_idx updated.
                            // But we are staying in BUILD_PATHS.
                            // Let's add a condition: If we just finished (q_head >= q_tail), we should reset vars before next BFS.
                            // But we can't easily reset in same state.
                            // Instead, let's go to a sub-state or handle it.
                            // Actually, we can stay in BUILD_PATHS, and if q_head >= q_tail, we check if we just finished.
                            // If we just finished, we save distances and increment prod_idx.
                            // But we need to reset visited for the new producer.
                            // 
                            // Let's use a flag or just handle it by checking if q_head == 0 (initial state) vs done.
                            // We can set visited=0 when prod_idx increments.
                            // Wait, we are inside the always block. We can add logic here.
                            
                            // If we are done with current producer, we increment prod_idx.
                            // In the NEXT cycle, we need to start BFS for new producer.
                            // In the NEXT cycle, we will be in BUILD_PATHS again.
                            // At that time, we need visited=0, q_tail=0, etc.
                            // But our sequential logic updates them from 'next_visited', which is calculated based on current 'visited'.
                            // If we just incremented prod_idx, we need to force the reset.
                            // 
                            // Solution: 
                            // When prod_idx is incremented, set a flag 'start_new_bfs' or just reset registers in this block.
                            
                            // Let's reset BFS registers here because we are done.
                            visited <= 0;
                            q_head <= 0;
                            q_tail <= 0;
                            for (int r = 0; r < 8; r++) d[r] <= 4'hF;
                        end
                    end
                end

                CHECK_COMPAT: begin
                    // Update compat matrix
                    if (collision_flag) begin
                        compat[i][j] <= 1'b0;
                        compat[j][i] <= 1'b0;
                    end
                    
                    // Increment indices
                    if (j == K - 1) begin
                        i <= i + 1;
                        j <= i + 2;
                    end else begin
                        j <= j + 1;
                    end
                    
                    // Termination
                    if (i >= K - 1 && j >= K) begin
                        state <= FIND_MAX_SET;
                        mask <= 1;
                        best <= 0;
                    end
                end

                FIND_MAX_SET: begin
                    if (mask == 0) begin
                        max_producers <= best;
                        state <= DONE;
                    end else begin
                        if (subset_ok) begin
                            // Popcount logic
                            count = mask[0] + mask[1] + mask[2] + mask[3] + mask[4] + mask[5] + mask[6] + mask[7];
                            if (count > best) begin
                                best <= count;
                            end
                        end
                        mask <= mask + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule