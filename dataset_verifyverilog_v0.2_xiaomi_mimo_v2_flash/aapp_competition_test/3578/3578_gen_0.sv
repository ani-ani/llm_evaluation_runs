module airline_review_opt(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [2:0] num_req_edges,
    input [2:0] num_add_edges,
    input [31:0] req_edges_data, // Packed array: 4 entries * 8 bits each
    input [63:0] add_edges_data, // Packed array: 8 entries * 8 bits each
    output reg [23:0] min_cost,
    output reg done
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam PRECOMP_INIT = 4'd1;
    localparam PRECOMP_WAIT = 4'd2;
    localparam REQ_COMP_INIT = 4'd3;
    localparam REQ_COMP_WAIT = 4'd4;
    localparam DP_PREP = 4'd5; // New state
    localparam DP_INIT = 4'd6;
    localparam DP_ITERATE = 4'd7; // Main loop state
    localparam FINISHED = 4'd8;

    reg [3:0] state;
    
    // Memory: 8x8 Shortest Path Matrix
    reg [15:0] dist_matrix [0:63]; 
    
    // Memory: DP Table (Flattened: mask * K + u)
    reg [15:0] dp [0:2047]; // 2^K * K max
    
    // List of nodes to visit (Required nodes + Start)
    reg [2:0] vis_nodes [0:7];
    reg [2:0] K; // Number of nodes to visit
    
    // Registers for Loops and Counters
    reg [7:0] req_nodes_mask;
    reg [2:0] req_nodes_count;
    reg [7:0] iter; // Flat iterator for DP
    reg [2:0] i, j, k; // General loop counters
    reg [2:0] proc_idx;
    
    // Intermediate values
    reg [15:0] dist_val;
    reg [15:0] prev_val;
    reg [15:0] curr_val;
    reg [15:0] new_val;
    reg [7:0] current_mask;
    reg [2:0] u_idx, v_idx;
    reg [2:0] node_u, node_v;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 24'd0;
            req_nodes_mask <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize Dist Matrix: 0 on diagonal, INF elsewhere
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (i == j) dist_matrix[i*8+j] <= 16'd0;
                                else dist_matrix[i*8+j] <= 16'hFFFF;
                            end
                        end
                        req_nodes_mask <= 8'd0;
                        proc_idx <= 3'd0;
                        state <= PRECOMP_INIT;
                    end
                end

                PRECOMP_INIT: begin
                    // Process Required Edges (4 entries in 32-bit input)
                    if (proc_idx < num_req_edges && proc_idx < 4) begin
                        // Extract 8-bit chunks
                        // Assuming format: {src[2:0], dst[2:0], cost[1:0]} for simplicity of "Simplified Interface"
                        // To be generic, we use bits [7:0] of the chunk.
                        // Let's assume cost is embedded. I will use bits [7:6] as multiplier.
                        // But to support costs up to 10000, we should use full byte if possible.
                        // Given input width mismatch (32 bits for 4 edges, 10000 needs 14 bits), I will map byte to cost.
                        // Cost = byte * 10 (scaled).
                        
                        // Extract byte
                        current_edge_cost <= {8'b0, req_edges_data[8*proc_idx +: 8]};
                        
                        // Extract src/dst (3 bits each from the same byte, assuming packed)
                        // Src = [2:0], Dst = [5:3]
                        i <= req_edges_data[8*proc_idx + 2 : 8*proc_idx]; // src
                        j <= req_edges_data[8*proc_idx + 5 : 8*proc_idx + 3]; // dst
                        
                        proc_idx <= proc_idx + 1;
                    end else begin
                        proc_idx <= 3'd0;
                        state <= PRECOMP_WAIT;
                    end
                end

                PRECOMP_WAIT: begin
                    // Process Additional Edges (64-bit input, 8 entries)
                    if (proc_idx < num_add_edges && proc_idx < 8) begin
                        // Similar extraction
                        i <= add_edges_data[8*proc_idx + 2 : 8*proc_idx];
                        j <= add_edges_data[8*proc_idx + 5 : 8*proc_idx + 3];
                        current_edge_cost <= {8'b0, add_edges_data[8*proc_idx +: 8]};
                        proc_idx <= proc_idx + 1;
                    end else begin
                        // Identify Required Nodes
                        // We have req_nodes_mask set during PRECOMP_INIT (if we did it there)
                        // But we need to set it now. 
                        // Actually, we should have set it in PRECOMP_INIT.
                        // Let's set req_nodes_mask[i] and req_nodes_mask[j] in the states above.
                        // 
                        // Correct logic: In PRECOMP_INIT/PRECOMP_WAIT, when we read src/dst 'i' and 'j',
                        // we should also set req_nodes_mask[i] <= 1 and req_nodes_mask[j] <= 1.
                        // And update dist_matrix.
                        // Let's apply updates here based on i, j, current_edge_cost.
                        // We need to check if current_edge_cost is valid (new proc_idx).
                        
                        // Since we are in a sequential block, the values i, j, current_edge_cost are from the PREVIOUS cycle.
                        // Wait, in PRECOMP_INIT, we assigned i, j, cost. Then proc_idx increments.
                        // So in PRECOMP_INIT, we should perform the write.
                        // To simplify, let's do the write in the same cycle as assignment? No, registers update next cycle.
                        // So we should do the write in the *next* state or using combinational logic.
                        // 
                        // Let's restructure slightly: 
                        // PRECOMP_INIT reads, PRECOMP_WAIT writes (or combined).
                        // I will use a dedicated `update_dist` flag or just do it in the state where inputs are stable.
                        // 
                        // Let's assume we handle the write in the cycle after assignment.
                        // But `PRECOMP_INIT` loops. It assigns, then increments proc_idx.
                        // So the assignment happens in cycle N, logic for prev cycle happens in N+1.
                        // So the values i, j, cost in state PRECOMP_INIT are OLD (from previous iteration).
                        // This is messy. 
                        
                        // CLEANUP: 
                        // I will handle edge processing in a single state `PRECOMP_LOOP`.
                        // But given the strict state definitions, I will use `PRECOMP_INIT` to loop.
                        // And I will update dist_matrix using the values assigned in the PREVIOUS clock.
                        // 
                        // Special handling: 
                        // In the first iteration of PRECOMP_INIT, proc_idx=0, i/j/cost are Z or old.
                        // We need to initialize or handle carefully.
                        // 
                        // BETTER: Do the update in the state where we have the data.
                        // Let's modify `PRECOMP_INIT` logic in the always block.
                        // 
                        // Let's restart the logic flow for this part in the final code assembly.
                        // I will assume we jump to REQ_COMP_INIT here.
                        // But I need to apply the updates for the *last* edge processed in PRECOMP_INIT.
                        // And for the *last* edge processed in PRECOMP_WAIT.
                        // 
                        // I will use a small trick: In PRECOMP_INIT/WAIT, we will process the edge *immediately*.
                        // We read inputs based on proc_idx, calculate, and update dist_matrix in the same cycle.
                        // This requires combinational logic to select the correct edge data.
                        // I will add that combinational logic.
                        
                        state <= REQ_COMP_INIT;
                        proc_idx <= 0;
                        i <= 0;
                    end
                end

                REQ_COMP_INIT: begin
                    // Build list of required nodes from mask
                    if (i < num_nodes) begin
                        if (req_nodes_mask[i]) begin
                            req_nodes_count <= req_nodes_count + 1;
                            // Store in list? We need list later. 
                            // Let's store in vis_nodes directly for now, we will shift if needed later.
                            vis_nodes[req_nodes_count] <= i;
                        end
                        i <= i + 1;
                    end else begin
                        // Reset counters for Floyd-Warshall
                        i <= 0; j <= 0; k <= 0;
                        state <= REQ_COMP_WAIT;
                    end
                end

                REQ_COMP_WAIT: begin
                    // Floyd-Warshall loops
                    if (k < num_nodes) begin
                        if (i < num_nodes) begin
                            if (j < num_nodes) begin
                                // Compute dist[i][j] <= min(dist[i][j], dist[i][k] + dist[k][j])
                                // Read dist_matrix at indices
                                // dist_matrix[{i, k}] and dist_matrix[{k, j}]
                                // To avoid read/write conflict on the same index (rare but possible), we rely on non-blocking reads.
                                // Actually, Verilog non-blocking read of array returns OLD value.
                                // So dist_matrix[{i, k}] is the value at start of cycle.
                                // dist_matrix[{k, j}] is value at start of cycle.
                                // We write to dist_matrix[{i, j}].
                                
                                if (dist_matrix[{i, k}] != 16'hFFFF && dist_matrix[{k, j}] != 16'hFFFF) begin
                                    if (dist_matrix[{i, j}] > dist_matrix[{i, k}] + dist_matrix[{k, j}]) begin
                                        dist_matrix[{i, j}] <= dist_matrix[{i, k}] + dist_matrix[{k, j}];
                                    end
                                end
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= 0;
                            k <= k + 1;
                        end
                    end else begin
                        state <= DP_PREP;
                    end
                end

                DP_PREP: begin
                    // Identify which nodes to visit in TSP.
                    // We need to visit: Start Node (0) + All Required Nodes.
                    // 
                    // Check if 0 is in req_nodes_mask. 
                    // If not, add 0 to list, then add all required nodes.
                    // If yes, add 0, then add others (avoiding duplicate 0).
                    // 
                    // We have req_nodes_list in vis_nodes from REQ_COMP_INIT.
                    // We need to reorder/insert.
                    
                    // Let's do this:
                    // We will use a temp array or just reorder in place.
                    // 
                    // Strategy:
                    // `vis_nodes` currently holds all required nodes.
                    // We need to build the final TSP list in `vis_nodes`.
                    // 
                    // We can do: 
                    // If 0 is not in vis_nodes, shift all vis_nodes up by 1, set vis_nodes[0] = 0. K = req_nodes_count + 1.
                    // If 0 is in vis_nodes, move it to index 0. K = req_nodes_count.
                    
                    // We need to iterate to check for 0.
                    // Let's use `k` as iterator.
                    
                    if (k < req_nodes_count) begin
                        if (vis_nodes[k] == 0) begin
                            // 0 found. Move it to index 0.
                            // Swap vis_nodes[0] and vis_nodes[k].
                            if (k != 0) begin
                                vis_nodes[0] <= vis_nodes[k];
                                vis_nodes[k] <= vis_nodes[0];
                            end
                        end
                        k <= k + 1;
                    end else begin
                        // Check if 0 is present now (in vis_nodes[0]).
                        // Actually, we need to check if 0 was in the original set.
                        // We can check `req_nodes_mask[0]`.
                        
                        if (req_nodes_mask[0]) begin
                            K <= req_nodes_count;
                        end else begin
                            // Need to insert 0.
                            // Shift vis_nodes[0..N-1] to vis_nodes[1..N]
                            for (iter = 0; iter < 7; iter = iter + 1) begin
                                if (iter < req_nodes_count) begin
                                    vis_nodes[iter + 1] <= vis_nodes[iter];
                                end
                            end
                            vis_nodes[0] <= 0;
                            K <= req_nodes_count + 1;
                        end
                        
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table with Infinity
                    // dp[mask][u] = INF
                    // We only need to clear the memory we will use.
                    // We will clear it iteratively or just use a for loop (takes cycles).
                    // Since we are state-based, we can use the `iter` counter.
                    // But to save states, let's just clear it in a loop here.
                    // 
                    // We will use `iter` to index 0 to (1<<K)*K - 1.
                    // 
                    // However, we need to set Start State: dp[1 (mask where bit 0 is set)][0 (index of node 0)] = 0.
                    // Since vis_nodes[0] is always 0 (Start Node), mask bit 0 corresponds to index 0.
                    
                    // Let's clear memory in `DP_PREP` or here.
                    // Let's use `DP_ITERATE` to clear first? No.
                    
                    // We will just assume we only read valid data, but it's safer to clear.
                    // Let's iterate `iter` to clear.
                    // 
                    // Optimization: We only need to clear `dp` up to (1<<K)*K.
                    // 
                    // Let's use `proc_idx` to loop through clearing.
                    // But `dp` is 2048 entries. 2048 cycles is fine within 10k budget (512 + 2048 + 2048).
                    // Actually, we don't need to clear everything. We can initialize `dp` with INF and rely on the DP logic to overwrite.
                    // We should clear the memory or at least the start state.
                    // 
                    // Let's just set the start state and assume the rest is INF (which we initialized in IDLE? No, IDLE only init dist_matrix).
                    // We need to init `dp`.
                    // 
                    // Let's create a sub-state or just do it in DP_INIT.
                    // I will use `proc_idx` to loop 0..255 and clear `dp` in chunks? 
                    // Or just use `DP_ITERATE` to clean up implicitly.
                    // 
                    // Let's do this: 
                    // In DP_INIT, we set `dp[1] = 0`.
                    // We must ensure `dp` is initially INF.
                    // I will add a loop to clear `dp` in `DP_PREP` before `DP_INIT`.
                    // 
                    // Actually, `dp` is large. I will clear it in `DP_INIT` using `iter`.
                    // If `iter` < 2048, clear `dp[iter]` and increment. 
                    // Once cleared, set `dp[1] = 0`.
                    
                    if (iter < 2048) begin
                        dp[iter] <= 16'hFFFF;
                        iter <= iter + 1;
                    end else begin
                        // Done clearing
                        // Set Start State: dp[1] = 0 (Mask 1, Node 0)
                        // Address = (1 << 0) * K + 0 = K + 0? No.
                        // Address = mask * K + u_idx.
                        // mask = 1 (binary 00000001). u_idx = 0 (index in vis_nodes).
                        // Address = 1 * K + 0 = K.
                        // Wait, mask 1 (binary) corresponds to integer value 1.
                        // Index = (1 * K) + 0 = K.
                        // 
                        // Example: K=3. Mask 001 (binary) = 1. Index = 1*3 + 0 = 3.
                        // 
                        // We need to calculate address correctly.
                        // Let's use a helper wire.
                        // But we can just assign it.
                        
                        dp[K * 1 + 0] <= 16'd0;
                        
                        // Reset Iterators for DP Loop
                        iter <= 0;
                        state <= DP_ITERATE;
                    end
                end

                DP_ITERATE: begin
                    // Main DP Loop
                    // iter = 0 to (1<<K)*K*K - 1
                    // Decode iter -> mask (0..2^K-1), u (0..K-1), v (0..K-1)
                    
                    // Total Iterations
                    if (iter >= ((1 << K) * K * K)) begin
                        state <= FINISHED;
                    end else begin
                        // Decode
                        // mask = iter / (K*K)
                        // u = (iter % (K*K)) / K
                        // v = (iter % (K*K)) % K
                        
                        // We need to perform these divisions/combinations in hardware.
                        // Since K is small (<=8), we can use a loop in combinational logic or compute directly.
                        // In sequential block, we can compute them using standard division if synthesis supports, or we use iterative logic.
                        // Given constraints, let's use the variable `iter` and compute using logic.
                        // 
                        // To avoid complex division, we can maintain separate counters: mask, u, v.
                        // But `iter` is simpler for state transition.
                        // 
                        // Let's calculate:
                        // current_mask = iter / (K*K);
                        // remaining = iter % (K*K);
                        // u_idx = remaining / K;
                        // v_idx = remaining % K;
                        
                        // Since we are in always block, we can't do this continuously. We do it in a combinational block outside.
                        // Let's assume we have combinational logic `dp_mask`, `dp_u`, `dp_v` derived from `iter` and `K`.
                        
                        // Logic:
                        // if (mask >= 2) and (mask has bit u) and (mask has bit v) and (u != v) then
                        //    Update dp[mask][u]
                        // 
                        // Address Calculation:
                        // curr_addr = (mask * K) + u
                        // prev_addr = ((mask ^ (1<<u)) * K) + v
                        
                        // We need to perform the read-modify-write.
                        // We read dp[curr_addr] and dp[prev_addr].
                        // We update dp[curr_addr].
                        
                        // Check conditions:
                        // if (mask >= 2 && (mask & (1<<u)) && (mask & (1<<v)) && u != v)
                        // 
                        // We also need dist between actual nodes:
                        // node_u = vis_nodes[u]
                        // node_v = vis_nodes[v]
                        // dist_val = dist_matrix[{node_v, node_u}] (from v to u)
                        // 
                        // update_cost = dp[prev_addr] + dist_val
                        // dp[curr_addr] = min(dp[curr_addr], update_cost)
                        
                        // In the sequential block:
                        // 1. Compute indices and conditions (combinational logic needed).
                        // 2. Read from dp array. Since we read dp[curr_addr] and dp[prev_addr], and write to dp[curr_addr],
                        //    we need to ensure we don't write to an address we need to read in the same cycle if they overlap.
                        //    curr_addr != prev_addr because mask ^ (1<<u) != mask (unless u is out of range, handled by condition).
                        //    So read/write to different addresses is fine.
                        // 
                        // However, Verilog `dp[addr]` on RHS is asynchronous read. 
                        // We can do: 
                        // if (condition) begin
                        //   if (dp[prev_addr] + dist_val < dp[curr_addr])
                        //     dp[curr_addr] <= dp[prev_addr] + dist_val;
                        // end
                        // This is valid in one cycle.
                        
                        // We need to define the helper wires for addresses and values.
                        // Since we can't define wires inside the always block easily without cluttering, 
                        // I will compute them using `integer` variables or assume they are computed combinational logic.
                        // 
                        // Let's use `current_mask`, `u_idx`, `v_idx` registers to hold the current iteration state.
                        // But we need to update them based on `iter`.
                        // 
                        // Let's do this: In `DP_ITERATE`, we update `iter`. 
                        // The combinational logic derived values of `mask`, `u`, `v` must be stable for the read/write.
                        // 
                        // I will use a combinational block to compute `mask_val`, `u_val`, `v_val` from `iter`.
                        // And `check_cond`.
                        // And `addr_curr`, `addr_prev`.
                        // 
                        // Let's write the code structure.
                        
                        // We need to increment iter at the end.
                        
                        // Implement the update logic here using combinational logic from the previous cycle's `iter`.
                        // 
                        // Wait, if I compute `iter` update at the end, then the values for the current cycle are stable.
                        // 
                        // Let's do it step by step in the code below.
                        
                        iter <= iter + 1;
                    end
                end

                FINISHED: begin
                    // Compute final result: min cost to visit all nodes and return to start.
                    // We need to check dp[FullMask][u] + dist[vis_nodes[u]][0] for all u.
                    // FullMask = (1<<K) - 1.
                    // We can compute this in one cycle or a small loop.
                    // Let's use `iter` to loop through u and find min.
                    // 
                    // But we are in FINISHED state. We should have computed the min before or do it now.
                    // 
                    // Let's switch to a `RESULT_CALC` state or do it here.
                    // Since we are here, let's assume we calculated it in the last step of DP_ITERATE.
                    // 
                    // No, DP_ITERATE ends when `iter` reaches max. At that point, the DP values are correct.
                    // But we haven't added the return cost.
                    // 
                    // I will use `DP_ITERATE` to handle the loop, and `FINISHED` to output.
                    // 
                    // But `FINISHED` is 1 state. We need to iterate to find min.
                    // I will change `FINISHED` to a loop state.
                    // 
                    // Let's repurpose `DP_ITERATE` or add `RESULT_ITERATE`.
                    // Given state limit, let's use `DP_ITERATE` for the final calc if we iterate differently.
                    // No, `DP_ITERATE` logic is specific.
                    // 
                    // Let's use `FINISHED` as a state that does:
                    // 1. Calculate Final Answer.
                    // 2. Set done = 1.
                    // 3. Wait for reset or start.
                    // 
                    // To calculate answer, we need to loop over `u` from 0 to K-1.
                    // MinCost = min(dp[FullMask][u] + dist[vis_nodes[u]][0]).
                    // 
                    // We can do this in `FINISHED` state using `iter` to loop 0..K-1.
                    // 
                    if (iter < K) begin
                        // Calculate candidate
                        // Read dp[FullMask][iter]
                        // FullMask = (1<<K) - 1.
                        // Address = FullMask * K + iter.
                        // Node index = vis_nodes[iter]
                        // Cost = dp_val + dist_matrix[{node_index, 0}]
                        
                        // We need to read dp and dist.
                        // Accumulate min.
                        
                        // Let's use `min_cost` register to store the running minimum.
                        // Initialize `min_cost` to INF before the loop.
                        // We can use the transition to FINISHED to set `min_cost` = INF.
                        // Then in FINISHED, update.
                        
                        iter <= iter + 1;
                        
                        // Logic:
                        // current_candidate = dp[FullMask * K + iter] + dist_matrix[{vis_nodes[iter], 0}]
                        // if (current_candidate < min_cost) min_cost <= current_candidate;
                        
                    end else begin
                        // Done
                        done <= 1'b1;
                        // Stay in FINISHED until reset
                    end
                end
            endcase
        end
    end

    // ---------------------------------------------------------
    // Combinational Logic (Next State & Helper Logic)
    // ---------------------------------------------------------
    // We need to handle the messy logic for:
    // 1. Edge loading in PRECOMP_INIT/PRECOMP_WAIT (combining read and write)
    // 2. DP Update calculation in DP_ITERATE.
    // 3. Final result calculation in FINISHED.
    
    // 1. Edge Loading Logic
    wire [2:0] edge_src, edge_dst;
    wire [15:0] edge_cost;
    wire edge_valid;
    
    assign edge_valid = (state == PRECOMP_INIT && proc_idx < num_req_edges) || 
                        (state == PRECOMP_WAIT && proc_idx < num_add_edges);
    
    // Mux for data source
    wire [7:0] current_edge_byte;
    assign current_edge_byte = (state == PRECOMP_INIT) ? 
                                req_edges_data[8*proc_idx +: 8] : 
                                add_edges_data[8*proc_idx +: 8];
    
    // Extraction (fixed mapping: src[2:0], dst[5:3], cost[7:0] -> 8 bit cost)
    assign edge_src = current_edge_byte[2:0];
    assign edge_dst = current_edge_byte[5:3];
    assign edge_cost = {8'b0, current_edge_byte[7:0]};

    // DP Logic Wires
    wire [7:0] dp_mask;
    wire [2:0] dp_u, dp_v;
    wire [10:0] dp_full_iter_limit; // (1<<K)*K*K max 8*8*256=16384. 11 bits.
    wire [15:0] dp_read_curr;
    wire [15:0] dp_read_prev;
    wire [15:0] dist_read;
    wire [15:0] dp_new_val;
    wire dp_update_enable;
    wire [2:0] vis_node_u, vis_node_v;
    wire [10:0] iter_addr_curr, iter_addr_prev;
    wire [7:0] mask_calc;
    wire [2:0] u_calc, v_calc;
    
    // Combinational Logic for State Transitions
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PRECOMP_INIT;
            
            PRECOMP_INIT: begin
                if (proc_idx < num_req_edges) next_state = PRECOMP_INIT;
                else next_state = PRECOMP_WAIT;
            end
            
            PRECOMP_WAIT: begin
                if (proc_idx < num_add_edges) next_state = PRECOMP_WAIT;
                else next_state = REQ_COMP_INIT;
            end
            
            REQ_COMP_INIT: begin
                if (i < num_nodes) next_state = REQ_COMP_INIT;
                else next_state = REQ_COMP_WAIT;
            end
            
            REQ_COMP_WAIT: begin
                if (k < num_nodes) next_state = REQ_COMP_WAIT;
                else next_state = DP_PREP;
            end
            
            DP_PREP: begin
                // Check if we are done shifting/finding 0
                // We used k to loop. If k >= req_nodes_count, we are done checking.
                // Then we need to handle insertion of 0.
                // I will assume insertion is done in one cycle or use another temp variable.
                // Let's assume we need one extra cycle after loop.
                // If k >= req_nodes_count, next_state = DP_INIT. 
                // But we need to do the "insert 0 if missing" logic.
                // Let's assume `req_nodes_mask[0]` tells us if 0 was required.
                // If 0 was not required, we insert. This takes 1 cycle (shift loop is combinational or sequential?).
                // I'll make `DP_PREP` take 1 cycle for simplicity of design flow, assuming combinational logic handles shift.
                // But Verilog sequential block is better for shifts.
                // I will make `DP_PREP` loop until `k` is handled.
                if (k < req_nodes_count) next_state = DP_PREP;
                else next_state = DP_INIT;
            end
            
            DP_INIT: begin
                if (iter < 2048) next_state = DP_INIT;
                else next_state = DP_ITERATE;
            end
            
            DP_ITERATE: begin
                // Calculate limit: (1 << K) * K * K
                // K is max 8. (1<<8)*8*8 = 16384.
                if (iter < ((1 << K) * K * K)) next_state = DP_ITERATE;
                else next_state = FINISHED;
            end
            
            FINISHED: begin
                if (iter < K) next_state = FINISHED;
                else next_state = FINISHED; // Stay here
            end
            
            default: next_state = IDLE;
        endcase
    end

    // ---------------------------------------------------------
    // Helper Combinational Logic for DP Iterations
    // ---------------------------------------------------------
    // Decompose `iter` into mask, u, v
    // Since we are in SystemVerilog (implied), we can use division, but for synthesis, it's better to use pre-calc if possible.
    // However, K is variable. Division by K is heavy but okay for low frequency, or we use a loop in combinational logic.
    // Given the requirements, I will use simple arithmetic.
    // 
    // Note: `iter` is 11 bits max. `K` is 3 bits.
    // We need (iter / (K*K)) and (iter % (K*K)).
    // Let's assume synthesis handles these divisions reasonably.
    // Or, we can iterate `mask`, `u`, `v` separately and pack into a flat counter.
    // 
    // Let's define the decomposition:
    integer dp_loop_idx; // Used for comb logic
    always @(*) begin
        // Default values
        dp_full_iter_limit = (1 << K) * K * K;
        
        // Decomposition
        // We need integer division for synthesis. 
        // If K=0, handle gracefully.
        if (K == 0) begin
            dp_mask = 0;
            dp_u = 0;
            dp_v = 0;
        end else begin
            // iter / (K*K)
            dp_loop_idx = iter / (K * K);
            dp_mask = dp_loop_idx[7:0];
            
            // iter % (K*K)
            dp_loop_idx = iter % (K * K);
            // dp_loop_idx / K
            dp_u = dp_loop_idx / K;
            // dp_loop_idx % K
            dp_v = dp_loop_idx % K;
        end
    end
    
    // ---------------------------------------------------------
    // Memory Updates in Sequential Logic
n    //---------
    
    // Edge Loading Update
    always @(posedge clk) begin
        if (edge_valid && edge_src < num_nodes && edge_dst < num_nodes) begin
            // Check if this is better than existing
            if (edge_cost < dist_matrix[{edge_src, edge_dst}]) begin
                dist_matrix[{edge_src, edge_dst}] <= edge_cost;
            end
            // Update Required Mask
            if (state == PRECOMP_INIT) begin
                req_nodes_mask[edge_src] <= 1'b1;
                req_nodes_mask[edge_dst] <= 1'b1;
            end
        end
    end

    // DP Update
    // We need to read dp[addr_curr] and dp[addr_prev].
    // In Verilog, reading from array in always block gives the current value (before update).
    // So we can do the check and update in the same cycle.
    
    // Calculations for DP update in DP_ITERATE state
    always @(posedge clk) begin
        if (state == DP_ITERATE && K > 0) begin
            // Calculate addresses and values based on `iter` from PREVIOUS cycle (which corresponds to current logic)
            // Wait, `iter` is updated at the end of the cycle in the main block.
            // So inside this block, `iter` is the OLD value if I am checking conditions based on `iter`.
            // To fix this, I should perform the update logic based on `iter` *before* it increments.
            // But I am inside a clocked block.
            // 
            // Let's calculate values based on `iter` (current value, which is the iteration we just finished or about to start?)
            // 
            // In the main block: `iter <= iter + 1;` happens at the end.
            // So the `iter` value used in this block is the one we want to process.
            
            // Decompose `iter` -> mask, u, v
            // We need integer math. 
            // To save logic, let's assume we use the combinational logic defined above.
            // `dp_mask`, `dp_u`, `dp_v` are derived from `iter`.
            
            // Check conditions
            if (dp_mask >= 2 && dp_mask < (1 << K)) begin
                if ((dp_mask >> dp_u) & 1 && (dp_mask >> dp_v) & 1 && dp_u != dp_v) begin
                    // Addresses
                    // curr_addr = dp_mask * K + dp_u
                    // prev_addr = (dp_mask ^ (1 << dp_u)) * K + dp_v
                    // Note: dp_mask is 8 bits, K is 3 bits. Result fits in 11 bits.
                    
                    // Need to compute these indices. 
                    // Since multiplication by K is shift+add, let's do it in combinational logic.
                    // We will use helper wires for addresses.
                    
                    // Read data
                    // We need to access `dp` array. 
                    // Since `dp` is large, synthesis might infer RAM. RAM usually has 1 cycle read latency if read/write are separate ports.
                    // If we use the same port for read and write, we might have issues.
                    // 
                    // Assuming dual port RAM or registers (since we write and read in same cycle):
                    // We can read the OLD value of `dp[curr_addr]` and `dp[prev_addr]`.
                    // 
                    // Let's define the indices.
                    // We need to compute them in combinational logic.
                    
                    // Let's define `curr_addr` and `prev_addr` in the combinational block.
                    // But we are inside the sequential block. 
                    // I will use the values computed in the combinational block `dp_update_enable` logic.
                    // 
                    // Actually, I can't easily read the array here without declaring the index variables.
                    // Let's move the update logic to a combinational block and use `always @(posedge clk)` for the actual write.
                    // 
                    // Let's try a hybrid:
                    // We use the `dp` array. 
                    // In `always @(posedge clk)`, we assign `dp[addr] <= value`.
                    // In combinational logic, we calculate `value` based on current `dp` contents.
                    // 
                    // This works if `dp` is updated correctly. 
                    // 
                    // Let's use a helper combinational block to calculate `new_dp_val` and `write_addr`.
                    // We need to capture `iter` value.
                    // 
                    // I'll add a register `curr_iter` that holds the `iter` value for the current update.
                    // 
                    // Let's stick to the plan: Calculate in `always @(*)` and update in `always @(posedge clk)`.
                end
            end
        end
    end

    // To make the DP update robust and synthesizable without RAM inference issues in this complex FSM:
    // I will explicitly define the DP update logic.
    // I will compute the DP update in a combinational block and use an enable signal to write to `dp`.
    
    // Define the indices for current iteration
    wire [10:0] curr_addr_calc = dp_mask * K + dp_u;
    wire [10:0] prev_addr_calc = ((dp_mask ^ (1 << dp_u)) * K) + dp_v;
    
    // Compute node indices
    assign vis_node_u = (dp_u < K) ? vis_nodes[dp_u] : 3'd0;
    assign vis_node_v = (dp_v < K) ? vis_nodes[dp_v] : 3'd0;
    
    // Read data from memories (Combinational)
    // We need to declare `dp` as a reg array, so reading is combinational.
    // But we are writing to `dp` in the clocked block. 
    // To read the value being written in the SAME cycle, we need to be careful.
    // If we write `dp[addr] <= val`, then `dp[addr]` in the combinational block reads the OLD value.
    // This is correct for DP (we want the old value to compare).
    
    // So we can do:
    wire [15:0] read_curr_val = dp[curr_addr_calc];
    wire [15:0] read_prev_val = dp[prev_addr_calc];
    wire [15:0] read_dist_val = dist_matrix[{vis_node_v, vis_node_u}];
    
    // Calculate new value
    // We only update if valid
    wire update_valid = (state == DP_ITERATE) && 
                        (dp_mask >= 2) && 
                        ((dp_mask >> dp_u) & 1) && 
                        ((dp_mask >> dp_v) & 1) && 
                        (dp_u != dp_v) &&
                        (K > 0);
    
    wire [15:0] candidate_val = read_prev_val + read_dist_val;
    wire [15:0] new_dp_val = (read_curr_val < candidate_val) ? read_curr_val : candidate_val;
    
    // Update dp array
    always @(posedge clk) begin
        if (update_valid) begin
            // Only update if we found a shorter path
            // Note: We must be careful not to overwrite a value that was updated earlier in this same iteration batch?
            // No, DP logic ensures we update `dp[mask][u]` based on `dp[mask\u][v]`. Since `mask\u] < mask`, it's safe.
            // Wait, `dp` array is shared. If we update `dp[mask][u]` and later `dp[mask][v]` reads `dp[mask][u]`?
            // No, `dp[mask][v]` reads `dp[mask \u v]`. `mask \u v` is smaller than `mask`. 
            // So `dp[mask][u]` and `dp[mask][v]` are independent writes for the same mask.
            // 
            // However, we update `dp` in place. 
            // If `dp[mask][u]` is updated, and later `dp[mask][v]` is computed, it reads `dp[mask\u]` (safe) and `dp[mask\u v]` (safe).
            // It does NOT read `dp[mask][u]` because `u` is removed from the mask.
            // 
            // So in-place update is safe.
            
            // BUT: `read_curr_val` is `dp[curr_addr_calc]`. This is the OLD value.
            // `new_dp_val` is min(old, candidate).
            // We write `new_dp_val` to `dp[curr_addr_calc]`.
            dp[curr_addr_calc] <= new_dp_val;
        end
    end

    // Final Result Calculation (in FINISHED state)
    // We need to compute min(dp[FullMask][u] + dist[vis_nodes[u]][0])
    // We will use `iter` to loop u = 0..K-1.
    // `min_cost` register is used to store the result.
    
    wire [7:0] full_mask = (1 << K) - 1;
    wire [10:0] res_addr = full_mask * K + iter;
    wire [15:0] res_dp_val = dp[res_addr];
    wire [2:0] res_node = vis_nodes[iter];
    wire [15:0] res_dist = dist_matrix[{res_node, 0}]; // Return to 0
    wire [23:0] cand_res = res_dp_val + res_dist;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_cost <= 24'd0;
        end else begin
            if (state == DP_INIT && iter >= 2048) begin
                // Initialize min_cost to INF before finishing DP
                // Actually, we do this when we transition to FINISHED.
                // Let's handle that in the state transition or here.
            end
            
            if (state == FINISHED && iter < K) begin
                // Accumulate min
                if (iter == 0) begin
                    min_cost <= {8'b0, cand_res}; // Reset and set first
                    // But we need to handle the case where res_dist or res_dp_val is INF.
                    // If INF, skip or keep min_cost as INF.
                end else begin
                    if (cand_res < min_cost && res_dp_val != 16'hFFFF && res_dist != 16'hFFFF) begin
                        min_cost <= {8'b0, cand_res};
                    end
                end
                // Check for INF condition for the first element
                if (iter == 0 && (res_dp_val == 16'hFFFF || res_dist == 16'hFFFF)) begin
                    min_cost <= 24'hFFFFFF; // INF
                end
            end
        end
    end

    // Logic to initialize min_cost to INF when entering FINISHED
    // We need to detect transition to FINISHED.
    reg prev_state_finished;
    always @(posedge clk) prev_state_finished <= (state == FINISHED);
    
    always @(posedge clk) begin
        if (state == FINISHED && !prev_state_finished) begin
            // Just entered FINISHED
            min_cost <= 24'hFFFFFF; // Initialize to INF
        end
    end

endmodule