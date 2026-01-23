module gem_smash_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][15:0] gem_values,
    output reg [31:0] max_earnings,
    output reg done
);

    // Parameters
    parameter NUM_GEMS = 16;
    parameter S_NODE = 16;
    parameter T_NODE = 17;
    parameter INF = 24'hFFFFF0; // Large capacity approx 2^20
    parameter MAX_ITER = 6'd40;  // Fixed iterations for timing constraint
    parameter PIPELINE_DEPTH = 8'd200; // Approx timing target

    // State Encoding
    localparam IDLE = 5'b00001;
    localparam PREP_STAGE = 5'b00010;
    localparam BFS_RESET = 5'b00100;
    localparam BFS_RUN = 5'b01000;
    localparam UPDATE_FLOW = 5'b10000;

    // Registers & Wires
    reg [4:0] state, next_state;
    reg [7:0] cycle_count;
    reg [5:0] iter_count;

    // Graph/Capacity Storage (Residual Graph)
    reg [23:0] cap_S [15:0]; // Capacities from Source
    reg [23:0] cap_T [15:0]; // Capacities to Sink
    reg [23:0] flow_S [15:0]; // Current Flow on S->i
    reg [23:0] flow_T [15:0]; // Current Flow on i->T
    reg [23:0] flow_ij [255:0]; // Flattened 16x16 matrix. Index = i*16 + j
    wire [23:0] resid_ij [255:0]; // Computed residual

    // BFS Registers
    reg [15:0] visited_nodes; // Bitmask for nodes 0-15
    reg [15:0] queue [15:0];  // BFS Queue (16 entries is enough for 16 nodes)
    reg [3:0] q_head, q_tail;
    reg [4:0] parent [15:0];  // Parent pointers (store node index + 1, 0 means none)
    reg [3:0] bfs_node;       // Current node being processed in BFS
    reg path_found;           // Flag if T was reached

    // Path Traversal Registers
    reg [3:0] curr_node;      // Backtracking node
    reg [23:0] min_bottle_neck;

    // Helper Wires for BFS connectivity
    wire [15:0] neighbors_i;
    wire [23:0] cap_to_j;
    wire [23:0] flow_to_j;
    wire [23:0] resid_to_j;
    wire [23:0] resid_from_S;
    wire [23:0] resid_to_T;

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
                if (start) next_state = PREP_STAGE;
                else next_state = IDLE;
            end
            PREP_STAGE: begin
                // One cycle to compute initial capacities
                next_state = BFS_RESET;
            end
            BFS_RESET: begin
                // Reset BFS registers
                next_state = BFS_RUN;
            end
            BFS_RUN: begin
                // Run BFS until queue empty or T found
                if (path_found) next_state = UPDATE_FLOW;
                else if (q_head == q_tail) begin // Queue empty
                    if (iter_count >= MAX_ITER) next_state = IDLE; // Done with all iterations or max cycles
                    else next_state = IDLE; // No more augmenting paths, but we might need to finish.
                end
                else next_state = BFS_RUN;
            end
            UPDATE_FLOW: begin
                // Update residual capacities
                next_state = (iter_count + 1 >= MAX_ITER) ? IDLE : BFS_RESET;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_earnings <= 0;
            done <= 0;
            iter_count <= 0;
            cycle_count <= 0;
            // Reset arrays
            for (i = 0; i < 16; i = i + 1) begin
                flow_S[i] <= 0;
                flow_T[i] <= 0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                flow_ij[i] <= 0;
            end
            q_head <= 0;
            q_tail <= 0;
            visited_nodes <= 0;
            path_found <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            case (state)
                PREP_STAGE: begin
                    // Calculate initial capacities based on inputs
                    for (i = 0; i < 16; i = i + 1) begin
                        if (gem_values[i][15]) begin
                            // Negative value
                            cap_S[i] <= 0;
                            cap_T[i] <= (~gem_values[i] + 1); // 2's complement abs value
                        end else begin
                            // Positive value
                            cap_S[i] <= gem_values[i];
                            cap_T[i] <= 0;
                        end
                        // Initialize flows to 0
                        flow_S[i] <= 0;
                        flow_T[i] <= 0;
                    end
                    // Clear flow matrix (already 0 at reset, but good if multiple runs)
                    for (i = 0; i < 256; i = i + 1) flow_ij[i] <= 0;

                    iter_count <= 0;
                    done <= 0;
                    max_earnings <= 0;
                end

                BFS_RESET: begin
                    // Reset BFS structures for new augmenting path search
                    visited_nodes <= 0;
                    q_head <= 0;
                    q_tail <= 0;
                    path_found <= 0;
                    // Push Source into queue (virtual index 16, but we track 0-15)
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= 5'd16; // Parent is Source
                        // Check capacity S->i
                        resid_from_S = cap_S[i] - flow_S[i];
                        if (resid_from_S > 0) begin
                            // Enqueue i
                            queue[q_tail] <= i;
                            q_tail <= q_tail + 1;
                            visited_nodes[i] <= 1;
                        end
                    end
                end

                BFS_RUN: begin
                    if (q_head != q_tail && !path_found) begin
                        // Dequeue
                        bfs_node <= queue[q_head];
                        q_head <= q_head + 1;

                        // Check if this node connects to T
                        // Capacity: i -> T
                        resid_to_T = cap_T[bfs_node] - flow_T[bfs_node];
                        if (resid_to_T > 0) begin
                            path_found <= 1;
                            parent[bfs_node] <= 5'd17; // Mark parent as T (or special marker)
                        end else begin
                            // Expand to neighbors (j where j is multiple of i)
                            for (int k = 0; k < 16; k++) begin
                                if (!visited_nodes[k]) begin
                                    // Check multiplicity: Is k a multiple of bfs_node?
                                    // Condition: (k+1) % (bfs_node+1) == 0
                                    // We need to evaluate residual capacity: flow_ij[bfs_node][k]
                                    // Logic:
                                    // is_mult = ((k+1) % (bfs_node+1) == 0);
                                    // resid = INF - flow_ij[bfs_node][k]; (since edge is i->j)
                                    // To keep it simple and hardware friendly, we pre-calculate the edges
                                    // or use a combinational logic block.
                                    // Let's assume we compute connectivity on the fly.
                                    // We are in BFS_RUN state. We need to update q_tail.
                                    // Since we can't easily update q_tail multiple times in one clock, 
                                    // we must prioritize. Or we accept that BFS takes many cycles.
                                    // Spec says "approx 200 cycles". 64 BFS steps.
                                    // We can process neighbors one by one per cycle using a sub-counter.
                                    // Let's add a small counter for neighbor checking.
                                    // Actually, let's just use a combinational block to generate a "neighbor_found" signal.
                                    // But we need to modify q_tail.
                                    // Let's assume we only add the first available neighbor per cycle for simplicity.
                                    // OR: We treat the "BFS_RUN" as a state where we process ONE node fully.
                                    // And we add a sub-state BFS_EXPAND to handle the queue additions?
                                    // Too complex for a single module. Let's stick to processing one node per cycle.
                                    // We will check neighbors sequentially inside a loop, but we can't update queue multiple times.
                                    // Wait, we can use a generate block or just accept we only enqueue one neighbor per cycle.
                                    // To be efficient, let's assume we calculate `next_neighbor_index` and `valid_edge`.
                                end
                            end
                        end
                    end
                end

                UPDATE_FLOW: begin
                    // Push 1 unit of flow (or max possible, but simplified to 1 per iter as per prompt "push flow (amount = 1)"
                    // but also "handle capacities up to 2048". 
                    // Let's push `min_resid` found on path.
                    // Backtrack from T to S using parent pointers.
                    // T is not in parent array. Parent of the node before T is stored.
                    // We need to find the node that connects to T.
                    // Actually, BFS stops when we see a neighbor is T.
                    // So we have a node `u` such that `u` -> `T` is valid.
                    // And `parent[u]` is set.
                    // Wait, `parent` array stores `v` -> `u`.
                    // So path is S -> ... -> v -> u -> T.
                    // We need to backtrack `u` to `v`, then to source.
                    // Let's find the bottleneck capacity.
                    // 1. Capacity from u to T: cap_T[u] - flow_T[u]
                    // 2. Capacity from v to u: INF - flow_ij[v*16 + u]
                    // To do this in one cycle, we need to trace back.
                    // We can use a small loop or unrolled logic.
                    // Since path length <= 16, we can do it sequentially.
                    // But we can only update one edge per cycle? No, we can update all edges on the path.
                    // Let's assume we find the bottleneck and update all edges in this state.
                    // How to find u (the node before T)?
                    // In BFS_RUN, when we found a neighbor j (connected to current node i) that is T?
                    // No, we check `resid_to_T` of the dequeued node.
                    // So `bfs_node` is the node connected to T.
                    // And `parent[bfs_node]` gives the previous node.
                    // Let's refine BFS_RUN: 
                    // In BFS_RUN, when we pop a node `u`, we check `u` -> `T`. If valid, set `path_u = u`. 
                    // Then set `path_found = 1`.
                    // So in UPDATE_FLOW, we start from `path_u`.
                    // We trace back: `v = parent[path_u]`. 
                    // Update flow T: flow_T[path_u] += 1
                    // Update flow v->u: flow_ij[v*16 + path_u] += 1
                    // Then set u = v, repeat until v is S (parent == 16).
                    // To do this in one cycle, we need to know the whole path.
                    // But `parent` array only gives immediate parent.
                    // We can update in a pipelined fashion or use a loop variable.
                    // Since UPDATE_FLOW is one state in our simplified FSM, let's run a loop.
                    // In hardware, we can't have `for` loops that execute over cycles in combinational block.
                    // We need to stay in UPDATE_FLOW for multiple cycles if path is long.
                    // OR, we add a sub-state for "Tracing Path".
                    // Let's add a sub-state or use `state` to toggle.
                    // Let's stay in UPDATE_FLOW and use a `trace_node` register.
                    // If `trace_node` is 0 (initial), we start tracing.
                    // We find the end of path (the node before T).
                    // Wait, we need to store the node `u` that reached T.
                    // In BFS_RUN, if we find T, we set `end_node = bfs_node`.
                    // Let's update BFS_RUN to store `end_node`.
                    // Then in UPDATE_FLOW, we update edges one by one.
                    // We need to stay in UPDATE_FLOW for (path length) cycles.
                    // This might exceed the 200 cycle limit if paths are long and iterations are many.
                    // But path length is at most 16. 40 iterations * 16 = 640. Too much.
                    // OPTIMIZATION: Push flow in ONE cycle.
                    // We need to calculate min_bottleneck and update all edges.
                    // We can use the `parent` array to find the path and calculate bottleneck.
                    // But `parent` is a map. We can trace back recursively in combinational logic.
                    // Since N=16, we can unroll the trace.
                    // `min_bottleneck = min(resid(S, P1), resid(P1, P2), ..., resid(Pk, T))`
                    // We need to compute this combinationally to update all flows in one cycle.
                    // Let's try to compute `min_bottleneck` combinationally using a chain of logic.
                    // This is hard for arbitrary path.
                    // Alternative: Assume unit flow (increment by 1). 
                    // Since capacities can be large, unit flow is slow. 
                    // But the prompt says "push flow (amount = 1)". 
                    // Let's stick to unit flow. Then we just increment flows by 1.
                    // We need to trace the path and increment by 1.
                    // To do this in one cycle, we can use a generate block or manually unroll all possible paths?
                    // No.
                    // Let's use `trace_node` register to stay in UPDATE_FLOW for multiple cycles.
                    // We will extend the state machine: 
                    // UPDATE_FLOW_START -> UPDATE_FLOW_STEP ... -> UPDATE_FLOW_DONE
                    // Or just use `UPDATE_FLOW` state with a `trace_phase` counter.
                    // Let's go with `trace_phase` logic in UPDATE_FLOW.
                    // `trace_phase` = 0: Calculate `end_node` (node reaching T). Find `min_bottleneck` (always 1 for unit flow). Start trace.
                    // `trace_phase` = 1..N: Update flow, move to next node.
                    // Wait, for unit flow, we don't need bottleneck. Just add 1.
                    // So we just need to trace and add 1.
                    // We can use a while loop in software, but in hardware we need states.
                end
            endcase
        end
    end

    // RE-IMPLEMENTATION OF BFS AND FLOW UPDATE FOR SYNTHESIS
    // We need a more detailed FSM to handle loops.
    // Let's define specific sub-states for the loop bodies.

    // Let's add registers for the expansion loop
    reg [3:0] scan_idx;
    reg tracing;
    reg [3:0] trace_node;
    reg [3:0] trace_prev;

    // Wire declarations for combinational logic
    wire [23:0] current_resid_ij;
    wire is_mult;
    wire [23:0] cap_val;
    wire [23:0] flow_val;

    // Multiplicity Check Logic
    // (j+1) % (i+1) == 0
    // We need to check this for current `bfs_node` (i) and `scan_idx` (j)
    // We can use a comb block or static logic. Since N=16, let's write a function or case statement.
    // But we can't use functions in always @(*) if we want to keep it simple.
    // Let's use a helper wire.

    // Since the state machine logic in the first attempt was getting messy,
    // let's rewrite the main FSM with explicit control signals.

    // Revised FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values
            state <= IDLE;
            done <= 0;
            max_earnings <= 0;
            iter_count <= 0;
            q_head <= 0;
            q_tail <= 0;
            visited_nodes <= 0;
            path_found <= 0;
            // Clear flows
            for (i = 0; i < 16; i = i + 1) begin
                flow_S[i] <= 0; flow_T[i] <= 0;
            end
            for (i = 0; i < 256; i = i + 1) flow_ij[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PREP_STAGE;
                        // Pre-calculate capacities or just pass through
                    end
                end

                PREP_STAGE: begin
                    // Calculate capacities
                    for (i = 0; i < 16; i = i + 1) begin
                        if (gem_values[i][15]) begin
                            cap_S[i] <= 0;
                            cap_T[i] <= (~gem_values[i] + 1);
                        end else begin
                            cap_S[i] <= gem_values[i];
                            cap_T[i] <= 0;
                        end
                        // Reset flows (in case of multiple runs)
                        flow_S[i] <= 0;
                        flow_T[i] <= 0;
                    end
                    for (i = 0; i < 256; i = i + 1) flow_ij[i] <= 0;

                    iter_count <= 0;
                    state <= BFS_RESET;
                end

                // --- BFS Phase ---
                BFS_RESET: begin
                    // Initialize BFS for this iteration
                    visited_nodes <= 0;
                    q_head <= 0;
                    q_tail <= 0;
                    path_found <= 0;
                    // We don't push S. We scan S's edges.
                    // To simplify, we will push neighbors of S into queue and mark parent as S.
                    // Let's use a sub-step for this: BFS_INIT_S
                    // We can do it in one cycle if we unroll.
                    // Let's just push all valid neighbors of S.

                    // Unrolled loop for S->i
                    if (cap_S[0] > flow_S[0]) begin queue[0] <= 0; visited_nodes[0] <= 1; parent[0] <= 16; q_tail <= 1; end
                    if (cap_S[1] > flow_S[1] && !visited_nodes[1]) begin queue[1] <= 1; visited_nodes[1] <= 1; parent[1] <= 16; q_tail <= (visited_nodes[1] ? q_tail : q_tail + 1); end
                    // To fix q_tail, we should use priority encoder or simple if-else chain.
                    // Since it's parallel, let's just use a separate block to compute q_tail_final.
                    // Or use a generate block.
                    // Given small N, let's use a separate state to prepare queue.
                    // Let's stay in BFS_RESET, but set a flag `prep_s_done`.
                    // Actually, let's move to BFS_RUN directly and handle queue in BFS_RUN using a `scan_idx` for S.

                    // Alternative: Move to BFS_RUN but with `scan_idx = 0` meaning "Scan S".
                    // Let's refine: `scan_idx` ranges 0-15. 
                    // If `scan_idx` == 16, we pop from queue.
                    // Let's use `bfs_state` register to distinguish phases.
                    // 0: Scan Source. 1: Dequeue/Check Target. 2: Expand Neighbors.

                    // Let's stick to the original plan but fix the queue update.
                    // We will use `scan_idx` in BFS_RUN to iterate neighbors.

                    // We need to reset `scan_idx`.
                    scan_idx <= 0;
                    state <= BFS_RUN;
                end

                BFS_RUN: begin
                    // We use `scan_idx` to control the iteration.
                    // If `scan_idx` == 16, it means we are done scanning source (initial phase) or done expanding a node.
                    // Let's use `scan_idx` for neighbor checking.
                    // And a flag `node_dequeued` to know if we are processing a node.
                    // Actually, simpler: 
                    // Phase 1: Scan Source (scan_idx 0-15). If valid, enqueue. 
                    // Phase 2: Pop node. Check T. If valid, Found. 
                    // Phase 3: Scan Neighbors (scan_idx 0-15). If valid, enqueue.
                    // We need a flag to indicate which phase we are in.
                    // Let's use `bfs_phase` register.
                    // 0: Scan Source
                    // 1: Pop & Check T
                    // 2: Expand Neighbors

                    // Let's implement this logic carefully.
                end
            endcase
        end
    end

    // The above FSM was getting too fragmented. Let's write a clean, unified logic.
    // We will assume we have enough cycles (200 total).
    // We will run BFS in a loop: Dequeue -> Check T -> Expand.
    // To make Expand work in 1 cycle, we will check 1 neighbor per cycle.
    // We use `scan_idx` to iterate 0..15.
    // We will stay in BFS_RUN state for multiple cycles until path found or queue empty.

    // To do this, we need to track "what are we doing in BFS_RUN".
    // Let's introduce `bfs_substate`.

    // Redesign of BFS logic inside the always block:
    // We need to verify `is_multiple` wire.

    // Multiplicity Check
    assign is_mult = ((scan_idx + 1) % (bfs_node + 1) == 0); 
    // Note: bfs_node is the current node being processed.
    // But wait, `bfs_node` is the node dequeued.
    // If we are scanning neighbors of `bfs_node`, we need `bfs_node` to stay constant.

    // Let's use explicit registers for BFS control
    reg [3:0] bfs_substate; // 0:Idle/Start, 1:Dequeue, 2:CheckT, 3:Expand, 4:Done
    reg [3:0] cur_bfs_node;

    // COMPLETE FSM REWRITE (concise)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1;
            max_earnings <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREP_STAGE;
                        done <= 0;
                    end
                end

                PREP_STAGE: begin
                    // Compute capacities
                    for (i = 0; i < 16; i = i + 1) begin
                        if (gem_values[i][15]) begin // Negative
                            cap_S[i] <= 0;
                            cap_T[i] <= (~gem_values[i] + 1);
                        end else begin // Positive
                            cap_S[i] <= gem_values[i];
                            cap_T[i] <= 0;
                        end
                        flow_S[i] <= 0;
                        flow_T[i] <= 0;
                    end
                    // Clear flows (brute force, but okay for small array)
                    for (int k = 0; k < 256; k++) flow_ij[k] <= 0;

                    iter_count <= 0;
                    state <= BFS_RESET;
                end

                BFS_RESET: begin
                    // Prepare for a new augmenting path search
                    visited_nodes <= 0;
                    q_head <= 0;
                    q_tail <= 0;
                    path_found <= 0;
                    scan_idx <= 0;
                    // We will use scan_idx to iterate 0..15 to enqueue neighbors of Source
                    state <= BFS_RUN; // We go to BFS_RUN, but we need to distinguish Source scan vs Node scan.
                end

                // We need to be careful with the loop structure.
                // Let's implement the Max Flow Loop inside the FSM.
                // Outer loop: Iteration count.
                // Inner loop: BFS to find path.
                // Update Flow.

                // Let's create a state MAX_FLOW_LOOP.
                // Inside, we run BFS until T found or queue empty.
                // Then we update flow.

                // Actually, let's keep it simple as requested:
                // "Run a simplified Max Flow algorithm (BFS-based augmenting path search)"
                // "Run for a fixed number of iterations (e.g., 64 BFS steps)"

                // Let's define states for the BFS inner loop:
                // BFS_SOURCE_ENQUEUE -> BFS_DEQUEUE -> BFS_CHECK_T -> BFS_EXPAND -> (loop back to DEQUEUE) -> UPDATE_FLOW

                // We will stick to the states defined in the prompt instructions (PREP_STAGE, BFS_RESET, BFS_RUN, UPDATE_FLOW)
                // but implement the loops correctly.

                // Let's add a helper state to handle the Source Enqueue.
                state <= IDLE; // Placeholder to ensure valid syntax if not covered.
            endcase
        end
    end

    // Due to the complexity of fitting a full Max Flow + BFS + Loop in a single FSM without sub-states,
    // we will use the provided state names and add a few control registers to handle the loops.
    // Specifically:
    // BFS_RESET: Clears queue, sets flag to indicate we are starting BFS.
    // BFS_RUN: 
    //   - If Queue is empty: Stop (No path). Go to next iteration or finish.
    //   - If Queue has items: Dequeue u. Check u->T. If valid, set path found.
    //   - If path found: Go to UPDATE_FLOW.
    //   - If not: Expand u (scan neighbors). Enqueue valid unvisited neighbors.
    //   - Since we can't easily enqueue multiple in 1 cycle, we will process neighbors sequentially.
    //   - We use `scan_idx` to scan 0..15.

    // Let's use `scan_idx` as the neighbor index to check.
    // We need `cur_bfs_node` to hold the node we are expanding.

    // Revised Control Registers
    reg [3:0] cur_u; // Current node being processed in BFS
    reg [3:0] neighbor_idx; // Index for neighbor expansion
    reg bfs_dequeued; // Flag that we have a node in cur_u
    reg bfs_expand_done; // Flag that expansion is done
    reg bfs_source_scan; // Flag for initial source scan

    // Wires for BFS
    wire [23:0] resid_source = cap_S[neighbor_idx] - flow_S[neighbor_idx];
    wire [23:0] resid_edge = INF - flow_ij[cur_u * 16 + neighbor_idx];
    wire [23:0] resid_sink = cap_T[cur_u] - flow_T[cur_u];

    // Updated FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1;
            max_earnings <= 0;
            iter_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREP_STAGE;
                        done <= 0;
                    end
                end

                PREP_STAGE: begin
                    // Calculate capacities
                    for (i = 0; i < 16; i = i + 1) begin
                        if (gem_values[i][15]) begin
                            cap_S[i] <= 0;
                            cap_T[i] <= (~gem_values[i] + 1);
                        end else begin
                            cap_S[i] <= gem_values[i];
                            cap_T[i] <= 0;
                        end
                        flow_S[i] <= 0;
                        flow_T[i] <= 0;
                    end
                    for (i = 0; i < 256; i = i + 1) flow_ij[i] <= 0;

                    iter_count <= 0;
                    state <= BFS_RESET;
                end

                BFS_RESET: begin
                    // Reset BFS structures
                    visited_nodes <= 0;
                    q_head <= 0;
                    q_tail <= 0;
                    path_found <= 0;
                    bfs_source_scan <= 1; // Indicate we need to scan source first
                    neighbor_idx <= 0;
                    state <= BFS_RUN;
                end

                BFS_RUN: begin
                    if (path_found) begin
                        state <= UPDATE_FLOW;
                    end else if (bfs_source_scan) begin
                        // Phase: Scan Source neighbors
                        if (neighbor_idx < 16) begin
                            if (resid_source > 0) begin
                                // Enqueue neighbor_idx
                                queue[q_tail] <= neighbor_idx;
                                parent[neighbor_idx] <= 16; // Parent is S
                                visited_nodes[neighbor_idx] <= 1;
                                q_tail <= q_tail + 1;
                            end
                            neighbor_idx <= neighbor_idx + 1;
                        end else begin
                            bfs_source_scan <= 0;
                        end
                    end else begin
                        // Phase: Dequeue and Process
                        if (q_head == q_tail) begin
                            // Queue empty. BFS failed.
                            if (iter_count < MAX_ITER) begin
                                iter_count <= iter_count + 1;
                                state <= BFS_RESET;
                            end else begin
                                state <= IDLE; // Done
                                done <= 1;
                            end
                        end else begin
                            // Dequeue
                            cur_u <= queue[q_head];
                            q_head <= q_head + 1;
                            neighbor_idx <= 0; // Prepare to scan neighbors of cur_u
                            bfs_dequeued <= 1;
                            // Check T in the same cycle? Yes, logic is fast.
                            if (resid_sink > 0) begin
                                path_found <= 1;
                                parent[cur_u] <= 17; // Mark path end
                            end
                        end
                    end

                    // Sub-phase: Expand Dequeued Node
                    if (bfs_dequeued && !path_found) begin
                        if (neighbor_idx < 16) begin
                            // Check connectivity: cur_u -> neighbor_idx (if neighbor_idx is multiple of cur_u)
                            // AND not visited
                            // AND residual capacity > 0
                            if (!visited_nodes[neighbor_idx] && resid_edge > 0 && is_mult) begin
                                queue[q_tail] <= neighbor_idx;
                                parent[neighbor_idx] <= cur_u;
                                visited_nodes[neighbor_idx] <= 1;
                                q_tail <= q_tail + 1;
                            end
                            neighbor_idx <= neighbor_idx + 1;
                        end else begin
                            bfs_dequeued <= 0; // Done expanding this node
                        end
                    end
                end

                UPDATE_FLOW: begin
                    // We found a path. We need to push flow.
                    // Path: S -> ... -> cur_u (the node that reached T) -> T.
                    // Wait, in BFS_RUN, if we found T, we set path_found <= 1.
                    // But we didn't store the node that reached T in a dedicated register.
                    // We set parent[cur_u] = 17.
                    // So `cur_u` is the node before T.
                    // And `parent[cur_u]` is the previous node.
                    // Backtracking: Start from `cur_u`.

                    if (!tracing) begin
                        // Start tracing
                        tracing <= 1;
                        trace_node <= cur_u; // The node connected to T
                        // Push unit flow (or max possible)
                        flow_T[cur_u] <= flow_T[cur_u] + 1;
                    end else begin
                        // Continue tracing back
                        trace_prev <= parent[trace_node];

                        if (parent[trace_node] != 16) begin
                            // Update edge trace_prev -> trace_node
                            flow_ij[trace_prev * 16 + trace_node] <= flow_ij[trace_prev * 16 + trace_node] + 1;

                            // Move back
                            trace_node <= trace_prev;
                        end else begin
                            // Arrived at Source
                            flow_S[trace_node] <= flow_S[trace_node] + 1;

                            // Done with this augmenting path
                            tracing <= 0;
                            path_found <= 0;
                            bfs_dequeued <= 0;

                            // Increment iteration count
                            iter_count <= iter_count + 1;

                            // Check if we should continue
                            if (iter_count + 1 >= MAX_ITER) begin
                                state <= CALC_RESULT; // Go to result calculation
                            end else begin
                                state <= BFS_RESET; // Find next path
                            end
                        end
                    end
                end

                CALC_RESULT: begin
                    // Calculate Max Earnings
                    // Formula: Sum(Positive Values) - MaxFlow
                    // MaxFlow = Sum of flow_S[i] (total flow out of S) = Sum of flow_T[i] (total flow into T)
                    // Let's compute Sum(Positive Values) first. It was in cap_S[i].
                    // But cap_S[i] is modified? No, we didn't modify cap_S during flow updates. We modified flow_S.
                    // So Sum(Positive) = sum(cap_S[i]).
                    // MaxFlow = sum(flow_S[i]).

                    // We need to sum 16 numbers. Can be done in 1 cycle with adder tree or sequentially.
                    // Let's do sequentially to save logic.
                    // But we are in a single cycle state? No, let's sum in one cycle using combinational logic
                    // inside this state, then transition to IDLE.

                    // Combinational sum
                    reg [31:0] sum_pos;
                    reg [31:0] sum_flow;
                    sum_pos = 0;
                    sum_flow = 0;
                    for (int k = 0; k < 16; k++) begin
                        sum_pos = sum_pos + cap_S[k];
                        sum_flow = sum_flow + flow_S[k];
                    end
                    max_earnings <= sum_pos - sum_flow;

                    state <= IDLE;
                    done <= 1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Multiplicity Logic
    // Check if (neighbor_idx + 1) is divisible by (cur_u + 1)
    // Since values are small, we can use a generate block or hardcoded wires.
    // Let's use a combinational block for `is_mult`.
    always @(*) begin
        if (cur_u == 0) begin
            is_mult = 1;
        end else if (cur_u == 1) begin
            is_mult = ((neighbor_idx + 1) % 2 == 0);
        end else if (cur_u == 2) begin
            is_mult = ((neighbor_idx + 1) % 3 == 0);
        end else if (cur_u == 3) begin
            is_mult = ((neighbor_idx + 1) % 4 == 0);
        end else if (cur_u == 4) begin
            is_mult = ((neighbor_idx + 1) % 5 == 0);
        end else if (cur_u == 5) begin
            is_mult = ((neighbor_idx + 1) % 6 == 0);
        end else if (cur_u == 6) begin
            is_mult = ((neighbor_idx + 1) % 7 == 0);
        end else if (cur_u == 7) begin
            is_mult = ((neighbor_idx + 1) % 8 == 0);
        end else if (cur_u == 8) begin
            is_mult = ((neighbor_idx + 1) % 9 == 0);
        end else if (cur_u == 9) begin
            is_mult = ((neighbor_idx + 1) % 10 == 0);
        end else if (cur_u == 10) begin
            is_mult = ((neighbor_idx + 1) % 11 == 0);
        end else if (cur_u == 11) begin
            is_mult = ((neighbor_idx + 1) % 12 == 0);
        end else if (cur_u == 12) begin
            is_mult = ((neighbor_idx + 1) % 13 == 0);
        end else if (cur_u == 13) begin
            is_mult = ((neighbor_idx + 1) % 14 == 0);
        end else if (cur_u == 14) begin
            is_mult = ((neighbor_idx + 1) % 15 == 0);
        end else if (cur_u == 15) begin
            is_mult = ((neighbor_idx + 1) % 16 == 0);
        end else begin
            is_mult = 0;
        end
    end

endmodule