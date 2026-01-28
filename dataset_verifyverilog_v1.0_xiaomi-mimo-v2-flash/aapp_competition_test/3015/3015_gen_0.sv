module shortest_path_2player (
    input clk,
    input rst_n,
    input start,
    input [23:0] edges [0:31],
    input [5:0] valid_edges,
    input [3:0] start_node,
    input [3:0] target_node,
    output reg [31:0] result,
    output reg done
);

    localparam [7:0] MAX_NODES = 16;
    localparam [7:0] MAX_EDGES = 32;
    localparam [7:0] MAX_CYCLES = 256;
    localparam [31:0] INF_SENTINEL = 32'hFFFFFFFE;
    localparam [31:0] LARGE_NEG = 32'hF0000000; // Large negative for max
    localparam [31:0] LARGE_POS = 32'h0FFFFFFF; // Large positive for min

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_DIST = 3'd1;
    localparam [2:0] EDGE_ITER = 3'd2;
    localparam [2:0] CONVERGENCE_CHECK = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    localparam [2:0] INFINITE_DETECT = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [5:0] edge_idx;
    reg [3:0] node_idx;
    reg [1:0] turn_idx; // 0 for A, 1 for B
    
    // Dist array: 32 entries (16 nodes * 2 turns), 32 bits each
    // Using packed array for Icarus compatibility
    reg [31:0] dist [0:31];
    // Buffer for next iteration values
    reg [31:0] next_dist [0:31];
    
    // Adjacency parsing
    wire [3:0] src;
    wire [3:0] dst;
    wire [15:0] w;
    
    assign src = edges[edge_idx][23:20];
    assign dst = edges[edge_idx][19:16];
    assign w = edges[edge_idx][15:0];
    
    // Combinatorial logic for relaxation
    reg [31:0] val_A; // Max over outgoing edges (w + dist[dst][1])
    reg [31:0] val_B; // Min over outgoing edges (w + dist[dst][0])
    reg [31:0] temp_val;
    reg [31:0] current_dist_src;
    reg [31:0] current_dist_dst_turn0;
    reg [31:0] current_dist_dst_turn1;
    
    integer i;
    reg change_detected;
    
    // Helper to index dist array: {node, turn}
    wire [4:0] idx_src;
    wire [4:0] idx_dst_turn0;
    wire [4:0] idx_dst_turn1;
    assign idx_src = {src, 1'b0}; // Turn 0 for A (max), Turn 1 for B (min) logic depends on context
    // Actually, the state is (node, turn). 
    // dist[node][0] = value when A is at node.
    // dist[node][1] = value when B is at node.
    // For calculation: 
    // At (node, A): val = max(w + dist[dst][1])
    // At (node, B): val = min(w + dist[dst][0])

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 8'd0;
            edge_idx <= 6'd0;
            node_idx <= 4'd0;
            turn_idx <= 2'd0;
            change_detected <= 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                dist[i] <= 32'd0;
                next_dist[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    edge_idx <= 6'd0;
                    node_idx <= 4'd0;
                    turn_idx <= 2'd0;
                    if (start) begin
                        state <= INIT_DIST;
                    end
                end

                INIT_DIST: begin
                    // Initialize distances
                    // dist[node][turn] initialization:
                    // Target node: 0 for both turns
                    // Others: A turn -> LARGE_NEG (looking for max), B turn -> LARGE_POS (looking for min)
                    if (node_idx < MAX_NODES) begin
                        if (node_idx == target_node) begin
                            dist[{node_idx, 1'b0}] <= 32'd0;
                            dist[{node_idx, 1'b1}] <= 32'd0;
                            next_dist[{node_idx, 1'b0}] <= 32'd0;
                            next_dist[{node_idx, 1'b1}] <= 32'd0;
                        end else begin
                            // Initialize A (max) to large negative, B (min) to large positive
                            dist[{node_idx, 1'b0}] <= LARGE_NEG;
                            dist[{node_idx, 1'b1}] <= LARGE_POS;
                            next_dist[{node_idx, 1'b0}] <= LARGE_NEG;
                            next_dist[{node_idx, 1'b1}] <= LARGE_POS;
                        end
                        node_idx <= node_idx + 4'd1;
                    end else begin
                        node_idx <= 4'd0;
                        turn_idx <= 2'd0;
                        state <= CONVERGENCE_CHECK;
                    end
                end

                EDGE_ITER: begin
                    // Iterate through all valid edges
                    if (edge_idx < valid_edges) begin
                        // Parse edge
                        // Logic depends on whose turn it is at the source node
                        // We update 'next_dist' based on current 'dist'
                        
                        // Calculate potential value
                        // If turn A (0): value = w + dist[dst][1] (Next is B)
                        // If turn B (1): value = w + dist[dst][0] (Next is A)
                        
                        // Current dist of source (for comparison)
                        // Note: We are iterating edges. 
                        // We need to update dist[src][turn] based on this edge.
                        // So we are effectively doing: 
                        // if turn == 0: next_dist[src][0] = max(next_dist[src][0], w + dist[dst][1])
                        // if turn == 1: next_dist[src][1] = min(next_dist[src][1], w + dist[dst][0])
                        
                        if (turn_idx == 2'd0) begin
                            // Player A: Maximize
                            if (dist[{dst, 1'b1}] != LARGE_POS) begin // Only if valid path exists from dst
                                temp_val = w + dist[{dst, 1'b1}];
                                // Check overflow
                                if (temp_val > LARGE_POS) temp_val = INF_SENTINEL;
                                
                                if (temp_val > next_dist[{src, 1'b0}]) begin
                                    next_dist[{src, 1'b0}] <= temp_val;
                                    change_detected <= 1'b1;
                                end
                            end
                        end else begin
                            // Player B: Minimize
                            if (dist[{dst, 1'b0}] != LARGE_NEG) begin
                                temp_val = w + dist[{dst, 1'b0}];
                                // Check overflow/underflow
                                if (temp_val > LARGE_POS) temp_val = INF_SENTINEL;
                                
                                if (temp_val < next_dist[{src, 1'b1}]) begin
                                    next_dist[{src, 1'b1}] <= temp_val;
                                    change_detected <= 1'b1;
                                end
                            end
                        end
                        
                        edge_idx <= edge_idx + 6'd1;
                    end else begin
                        edge_idx <= 6'd0;
                        // Move to next node or turn
                        if (turn_idx == 2'd0) begin
                            turn_idx <= 2'd1;
                        end else begin
                            turn_idx <= 2'd0;
                            if (node_idx == MAX_NODES - 1) begin
                                node_idx <= 4'd0;
                                state <= CONVERGENCE_CHECK;
                            end else begin
                                node_idx <= node_idx + 4'd1;
                            end
                        end
                    end
                end

                CONVERGENCE_CHECK: begin
                    if (change_detected) begin
                        // Update dist array with next_dist for next iteration
                        // In hardware, we can swap pointers or copy. Here we copy.
                        for (i = 0; i < 32; i = i + 1) begin
                            dist[i] <= next_dist[i];
                        end
                        // Reset next_dist for next iteration? 
                        // No, next_dist is overwritten in EDGE_ITER.
                        // But we need to reset next_dist to current dist values for accumulation? 
                        // Actually, standard Bellman-Ford relaxes edges against the OLD dist array.
                        // Here we compute new values and store in next_dist.
                        // Then we copy next_dist to dist.
                        // Wait, for min/max accumulation, we need next_dist to start as current dist (or infinity/neg infinity)
                        // because we are taking max/min over edges.
                        // So we must reset next_dist to dist values before EDGE_ITER.
                        // However, resetting 32 registers takes cycles.
                        // Optimization: In EDGE_ITER, we compare with dist (read-only) and write to next_dist.
                        // But we must initialize next_dist properly before starting EDGE_ITER.
                        
                        cycle_count <= cycle_count + 8'd1;
                        change_detected <= 1'b0;
                        
                        // Check for infinite cycles
                        // If any value reached INF_SENTINEL, propagate or detect.
                        // Simple check: if dist[start_node][0] is INF_SENTINEL
                        if (dist[{start_node, 1'b0}] == INF_SENTINEL) begin
                            state <= INFINITE_DETECT;
                        end else if (cycle_count >= MAX_CYCLES) begin
                            // Convergence not reached
                            state <= INFINITE_DETECT;
                        end else begin
                            // Prepare for next iteration
                            // Reset next_dist to dist (to accumulate max/min over edges)
                            // Actually, for max: next_dist = dist. Then max(w + next_dist[dst][1])
                            // For min: next_dist = dist. Then min(w + next_dist[dst][1])
                            // Wait, the formula is dist_new[u] = max(edge (u,v)) w + dist_old[v].
                            // So next_dist[u] starts at -inf/+inf or dist_old[u] (which is better).
                            // Given we initialized next_dist to dist in INIT, we are good.
                            // But we updated next_dist in EDGE_ITER. 
                            // So for the next cycle, we need to copy next_dist -> dist.
                            // And we need to reset next_dist for accumulation? 
                            // No, we are comparing against dist (old values) for the relaxation.
                            // But we wrote to next_dist. 
                            // Let's rethink: 
                            // Iteration N: dist holds values from N-1.
                            // We compute new values into next_dist.
                            // We need to reset next_dist to -inf/+inf before processing edges for this iteration?
                            // OR: next_dist starts as dist (current best).
                            // In EDGE_ITER: val = w + dist[dst]. (Read old dist)
                            // Compare val with next_dist[src].
                            // If better, update next_dist[src].
                            // This works if next_dist is initialized to dist at start of iteration.
                            
                            // So, here, we copy next_dist (which now has the best values for this iteration) to dist.
                            // Then we need to reset next_dist for the NEXT iteration.
                            // Actually, for the next iteration, we want to relax edges again based on the NEW dist.
                            // So we need to set next_dist to the NEW dist (which we just copied).
                            // Wait, if we just copied, dist == next_dist. 
                            // We need to prepare next_dist for accumulation in the next iteration.
                            // Since we take max/min, we should reset next_dist to -inf/+inf (or keep dist? no).
                            // If we keep dist in next_dist, then we are doing: max(w + dist[dst], dist[src]).
                            // This is correct for Relaxation.
                            
                            // Re-initialize next_dist to dist for the next iteration
                            // This is required because we want to improve upon the current best.
                            for (i = 0; i < 32; i = i + 1) begin
                                next_dist[i] <= dist[i];
                            end
                            
                            state <= EDGE_ITER;
                        end
                    end else begin
                        // No changes, converged
                        state <= FINISHED;
                    end
                end
                
                INFINITE_DETECT: begin
                    // Mark as infinite
                    result <= INF_SENTINEL;
                    done <= 1'b1;
                    state <= IDLE;
                end

                FINISHED: begin
                    // Output result
                    // Result is dist[start_node][0] (Player A starts)
                    if (dist[{start_node, 1'b0}] == LARGE_NEG) begin
                        // Never reached (disconnected graph)
                        result <= INF_SENTINEL;
                    end else begin
                        result <= dist[{start_node, 1'b0}];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule