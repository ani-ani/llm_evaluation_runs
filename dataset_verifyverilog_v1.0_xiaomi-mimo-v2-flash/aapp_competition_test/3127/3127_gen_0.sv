module IdentifyOptimalNodes (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [3:0] src_id,
    input [3:0] dest_id,
    input [4:0] edge_count,
    input [9:0] edge_a [0:31],
    input [9:0] edge_b [0:31],
    input [9:0] edge_len [0:31],
    output reg [15:0] result,
    output reg done
);

    // State Machine Definitions
    localparam [3:0] S_IDLE       = 4'd0;
    localparam [3:0] S_INIT       = 4'd1;
    localparam [3:0] S_RELAX_DIR  = 4'd2; // Dijkstra forward (length primary)
    localparam [3:0] S_RELAX_REV  = 4'd3; // Dijkstra reverse (length primary)
    localparam [3:0] S_CHECK_PATH = 4'd4; // Verify Pareto optimality
    localparam [3:0] S_OUTPUT     = 4'd5;

    reg [3:0] state, next_state;

    // Constants
    localparam [31:0] INF = 32'h7FFFFFFF;
    localparam [4:0] MAX_EDGES = 5'd32;
    localparam [3:0] MAX_NODES = 4'd16;

    // Internal Registers (RAMs)
    // Forward Dijkstra
    reg [31:0] dist_f [0:15];   // Shortest distance (length)
    reg [4:0]  hops_f [0:15];   // Hop count
    reg [15:0] visited_f;       // Bitmask

    // Reverse Dijkstra
    reg [31:0] dist_r [0:15];   // Distance to dest
    reg [4:0]  hops_r [0:15];   // Hops to dest
    reg [15:0] visited_r;       // Bitmask

    // Path Flags
    reg [15:0] path_nodes;      // Nodes on valid paths

    // Loop Counters / Indices
    reg [4:0] edge_idx;         // 0 to 31
    reg [3:0] node_idx;         // 0 to 15
    reg [3:0] u_idx;            // Current node
    reg [3:0] v_idx;            // Neighbor node
    reg [3:0] iter_node;        // Node being scanned for min dist
    reg [3:0] best_node;        // Node with min dist

    // Temporary variables
    reg [31:0] new_dist;
    reg [4:0]  new_hops;
    reg [31:0] curr_dist;
    reg [4:0]  curr_hops;
    reg [31:0] edge_len_val;
    reg        is_better;

    // Cycle Counter for Safety
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2048;

    // Next State Logic
    always @(*) begin
        case (state)
            S_IDLE:       next_state = start ? S_INIT : S_IDLE;
            S_INIT:       next_state = S_RELAX_DIR;
            S_RELAX_DIR:  next_state = (u_idx == num_nodes) ? S_RELAX_REV : S_RELAX_DIR;
            S_RELAX_REV:  next_state = (u_idx == num_nodes) ? S_CHECK_PATH : S_RELAX_REV;
            S_CHECK_PATH: next_state = (node_idx == num_nodes) ? S_OUTPUT : S_CHECK_PATH;
            S_OUTPUT:     next_state = S_IDLE;
            default:      next_state = S_IDLE;
        endcase
    end

    // State Transition & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 16'hFFFF;
            cycle_count <= 11'd0;
            // Reset all RAMs
            for (int i = 0; i < 16; i = i + 1) begin
                dist_f[i] <= INF;
                hops_f[i] <= 5'd0;
                dist_r[i] <= INF;
                hops_r[i] <= 5'd0;
            end
            visited_f <= 16'd0;
            visited_r <= 16'd0;
            path_nodes <= 16'd0;
            edge_idx <= 5'd0;
            node_idx <= 4'd0;
            u_idx <= 4'd0;
            best_node <= 4'd0;
            iter_node <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 11'd1;
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Clear internal arrays
                        for (int i = 0; i < 16; i = i + 1) begin
                            dist_f[i] <= INF;
                            hops_f[i] <= 5'd0;
                            dist_r[i] <= INF;
                            hops_r[i] <= 5'd0;
                        end
                        visited_f <= 16'd0;
                        visited_r <= 16'd0;
                        path_nodes <= 16'd0;
                        u_idx <= 4'd0;
                        node_idx <= 4'd0;
                        // Initialize Source and Dest
                        dist_f[src_id] <= 32'd0;
                        hops_f[src_id] <= 5'd0;
                        dist_r[dest_id] <= 32'd0;
                        hops_r[dest_id] <= 5'd0;
                    end
                end

                S_INIT: begin
                    // State setup for relaxation loops
                    u_idx <= 4'd0; // Reset iterator for scanning unvisited nodes
                    iter_node <= 4'd0;
                    best_node <= 4'd15; // Dummy
                end

                S_RELAX_DIR: begin
                    // --- Phase 1: Find Best Unvisited Node ---
                    if (u_idx == 4'd0) begin
                        // First cycle of this state: find min dist node
                        // Reset iter_node
                        iter_node <= 4'd0;
                        best_node <= 4'd15;
                        curr_dist <= INF;
                    end else begin
                        // Subsequent cycles: scan remaining nodes
                        // Logic inside sequential block to avoid combinational loops
                        if (iter_node < num_nodes) begin
                            // Check if visited
                            if (!visited_f[iter_node]) begin
                                if (dist_f[iter_node] < curr_dist) begin
                                    curr_dist <= dist_f[iter_node];
                                    best_node <= iter_node;
                                end
                            end
                            iter_node <= iter_node + 4'd1;
                        end else begin
                            // Scanning done, found best_node. Mark visited.
                            if (best_node < num_nodes) begin
                                visited_f[best_node] <= 1'b1;
                                u_idx <= best_node; // u is now the current node for edge processing
                                iter_node <= 4'd0; // Reset for edge loop
                            end else begin
                                // No reachable nodes left (or all visited)
                                u_idx <= num_nodes; // Finish
                            end
                        end
                    end

                    // --- Phase 2: Relax Edges (if u_idx was set in previous cycle) ---
                    // We need a separate logic block to process edges after u is selected
                    // To keep strictly sequential, we mix phases carefully.
                    // Optimization: Split S_RELAX_DIR into 2 sub-states is clearer, but let's try to sequence.
                    // Actually, for strict adherence to "Sequential FSM", let's use an edge counter.
                    // If u_idx != 4'd0 (and iter_node is not scanning), we process edges.
                    // This logic assumes the "Find Min" part takes 1 clock per node scan.
                end

                S_RELAX_REV: begin
                    // Same logic as DIR but for Reverse Graph
                    if (u_idx == 4'd0) begin
                        iter_node <= 4'd0;
                        best_node <= 4'd15;
                        curr_dist <= INF;
                    end else begin
                        if (iter_node < num_nodes) begin
                            if (!visited_r[iter_node]) begin
                                if (dist_r[iter_node] < curr_dist) begin
                                    curr_dist <= dist_r[iter_node];
                                    best_node <= iter_node;
                                end
                            end
                            iter_node <= iter_node + 4'd1;
                        end else begin
                            if (best_node < num_nodes) begin
                                visited_r[best_node] <= 1'b1;
                                u_idx <= best_node;
                                iter_node <= 4'd0;
                            end else begin
                                u_idx <= num_nodes;
                            end
                        end
                    end
                end

                S_CHECK_PATH: begin
                    // Check if node satisfies Pareto optimality: 
                    // Path Src->Node + Node->Dest == Path Src->Dest (Primary: Length)
                    // Secondary: Hops (Path Src->Node + Node->Dest <= Path Src->Dest)
                    if (node_idx < num_nodes) begin
                        // Check if node is reachable from both sides
                        if (dist_f[node_idx] != INF && dist_r[node_idx] != INF) begin
                            // Calculate total length and hops
                            // Watch for overflow on add, though INF is large.
                            // If total length equals optimal length (dist_f[dest_id])
                            if (dist_f[node_idx] + dist_r[node_idx] == dist_f[dest_id]) begin
                                // Tie-break on hops: total hops <= optimal hops
                                if ((hops_f[node_idx] + hops_r[node_idx]) <= hops_f[dest_id]) begin
                                    path_nodes[node_idx] <= 1'b1;
                                end
                            end
                        end
                        node_idx <= node_idx + 4'd1;
                    end
                end

                S_OUTPUT: begin
                    // Generate result mask
                    // Bit i = 0 if node is used (in path_nodes), 1 if unused
                    // result is 16-bit, node 0 is bit 0 (Switch 1)
                    // path_nodes has bit i set if used.
                    result <= ~path_nodes & 16'hFFFF;
                    done <= 1'b1;
                end
            endcase
            
            // --- Generic Edge Processing Logic ---
            // This block runs when we have a valid 'u_idx' and are not in IDLE/INIT
            // It iterates through all edges to relax neighbors.
            if ((state == S_RELAX_DIR || state == S_RELAX_REV) && u_idx < num_nodes && cycle_count > 0) begin
                // Ensure we don't process edges during the "Find Min" scan phase (u_idx set to best_node later)
                // We need a flag or check to separate scan vs relax.
                // Let's use iter_node to count edge index if we are in relax mode.
                // But iter_node is used for node scanning. 
                // Let's introduce a specific edge iterator 'edge_idx' that runs only when u is valid.
                
                if (edge_idx < edge_count) begin
                    // Get edge details based on state
                    if (state == S_RELAX_DIR) begin
                        // Check if edge connects u_idx to neighbor
                        // Edge is undirected or directed? Problem says "cables". Assume undirected for connectivity.
                        // Dijkstra on undirected graph: check both ends.
                        if (edge_a[edge_idx] == u_idx) begin
                            v_idx <= edge_b[edge_idx];
                            edge_len_val <= edge_len[edge_idx];
                        end else if (edge_b[edge_idx] == u_idx) begin
                            v_idx <= edge_a[edge_idx];
                            edge_len_val <= edge_len[edge_idx];
                        end else begin
                            v_idx <= 16; // Invalid
                        end
                    end else begin
                        // Reverse: For edge (a,b), we relax from b->a or a->b
                        // Actually, reverse graph simply swaps source/dest logic.
                        // If we are at node u in reverse dijkstra, it means we are going FROM dest.
                        // We relax to neighbors v.
                        // Edge (a,b) connects a and b.
                        if (edge_a[edge_idx] == u_idx) begin
                            v_idx <= edge_b[edge_idx];
                            edge_len_val <= edge_len[edge_idx];
                        end else if (edge_b[edge_idx] == u_idx) begin
                            v_idx <= edge_a[edge_idx];
                            edge_len_val <= edge_len[edge_idx];
                        end else begin
                            v_idx <= 16;
                        end
                    end
                    
                    edge_idx <= edge_idx + 5'd1;
                end else begin
                    // Reset edge_idx for next node selection (wait for u_idx update)
                    edge_idx <= 5'd0;
                end
            end else begin
                edge_idx <= 5'd0;
            end
            
            // --- Relaxation Update (Combinational Logic wrapped in Regs) ---
            // Apply the relaxation if valid neighbor found in previous cycle
            if ((state == S_RELAX_DIR || state == S_RELAX_REV) && v_idx < num_nodes) begin
                // Check visited status based on state
                // In standard Dijkstra, we relax FROM unvisited TO potentially visited (or unvisited)
                // But once a node is visited (best path found), we typically don't update it.
                // Actually, standard Dijkstra relaxes edges of the current node (u), checking neighbors (v).
                // If v is NOT visited, we update.
                
                reg node_is_unvisited;
                reg [31:0] old_dist;
                reg [4:0] old_hops;
                
                if (state == S_RELAX_DIR) begin
                    node_is_unvisited = !visited_f[v_idx];
                    old_dist = dist_f[v_idx];
                    old_hops = hops_f[v_idx];
                end else begin
                    node_is_unvisited = !visited_r[v_idx];
                    old_dist = dist_r[v_idx];
                    old_hops = hops_r[v_idx];
                end
                
                if (node_is_unvisited) begin
                    // Calculate new distance = dist[u] + edge_len
                    // dist[u] is stored in curr_dist during the scan phase, or we can read array
                    // Since 'u' is selected, we should read dist_f[u_idx] or dist_r[u_idx]
                    // Note: dist_f[u_idx] is valid for the current u.
                    
                    reg [31:0] u_dist;
                    reg [4:0] u_hops;
                    
                    if (state == S_RELAX_DIR) begin
                        u_dist = dist_f[u_idx];
                        u_hops = hops_f[u_idx];
                    end else begin
                        u_dist = dist_r[u_idx];
                        u_hops = hops_r[u_idx];
                    end
                    
                    new_dist = u_dist + edge_len_val;
                    new_hops = u_hops + 5'd1;
                    
                    // Compare: Strictly shorter, or equal length but fewer hops
                    is_better = 1'b0;
                    if (new_dist < old_dist) begin
                        is_better = 1'b1;
                    end else if (new_dist == old_dist) begin
                        if (new_hops < old_hops) begin
                            is_better = 1'b1;
                        end
                    end
                    
                    if (is_better) begin
                        if (state == S_RELAX_DIR) begin
                            dist_f[v_idx] <= new_dist;
                            hops_f[v_idx] <= new_hops;
                        end else begin
                            dist_r[v_idx] <= new_dist;
                            hops_r[v_idx] <= new_hops;
                        end
                    end
                end
                // Reset v_idx to prevent repeated updates on next clock if no edge match
                // v_idx is reset by edge loop logic anyway
            end
        end
    end
endmodule