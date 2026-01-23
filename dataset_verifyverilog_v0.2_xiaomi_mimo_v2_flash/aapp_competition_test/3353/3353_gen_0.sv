module river_crossing_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] P,
    input [4:0] num_nodes,
    input [4:0] num_edges,
    input [5:0] edges_src [15:0],
    input [5:0] edges_dst [15:0],
    output reg [15:0] total_time,
    output reg [4:0] people_left,
    output reg done,
    output reg possible
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam FIND_PATH = 3'b010;
    localparam UPDATE_GRAPH = 3'b011;
    localparam CHECK_DONE = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;
    
    // Internal Registers
    reg [3:0] p_cnt;           // Count of people crossed
    reg [4:0] active_edges;    // Number of edges currently valid (indices 0 to active_edges-1)
    reg [4:0] bfs_head;        // Queue head pointer
    reg [4:0] bfs_tail;        // Queue tail pointer
    
    // Arrays for BFS and Graph
    reg [4:0] parent_node [7:0];   // Parent node for path reconstruction
    reg visited [7:0];             // Visited flag for BFS
    reg edge_active [15:0];        // Status of each edge (1=active, 0=removed)
    reg [4:0] q_nodes [31:0];      // BFS Queue (sized for worst case expansion)
    
    // Path reconstruction state
    reg [4:0] curr_node;
    reg [5:0] prev_node;
    
    // Status flags
    reg path_found;
    reg [4:0] path_edge_idx;
    reg [4:0] path_len;

    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_time <= 0;
            people_left <= 0;
            done <= 0;
            possible <= 0;
            p_cnt <= 0;
            active_edges <= 0;
            path_found <= 0;
            // Clear arrays
            for (i = 0; i < 8; i = i + 1) begin
                parent_node[i] <= 0;
                visited[i] <= 0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                edge_active[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize values for new computation
                    total_time <= 0;
                    p_cnt <= 0;
                    people_left <= 0;
                    possible <= 0;
                    // Set up active edges (initially all valid edges)
                    // Cap at num_edges input
                    active_edges <= (num_edges > 16) ? 16 : num_edges;
                    
                    // Mark all edges as active
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < num_edges)
                            edge_active[i] <= 1;
                        else
                            edge_active[i] <= 0;
                    end
                    
                    state <= FIND_PATH;
                end

                FIND_PATH: begin
                    // BFS Logic: We implement BFS over multiple cycles to avoid deep combinational logic
                    // Cycle 1: Reset BFS structures
                    if (bfs_head == 0 && bfs_tail == 0 && !visited[0]) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            visited[i] <= 0;
                            parent_node[i] <= 5'h1F; // Invalid parent
                        end
                        visited[0] <= 1;
                        q_nodes[0] <= 0;
                        bfs_head <= 0;
                        bfs_tail <= 1;
                        path_found <= 0;
                    end else if (bfs_head < bfs_tail && !path_found) begin
                        // Process queue
                        reg [4:0] u;
                        u = q_nodes[bfs_head];
                        bfs_head <= bfs_head + 1;
                        
                        if (u == 1) begin // Sink found
                            path_found <= 1;
                            // Start path reconstruction logic next cycle
                            // We will handle reconstruction in UPDATE_GRAPH state or a sub-state
                            // But here we found the sink. 
                            // Since we want to be robust, let's transition once sink is found
                            state <= UPDATE_GRAPH;
                            curr_node <= 1; // Start tracing from sink
                        end else begin
                            // Iterate edges to find neighbors
                            // We need to iterate through edges sequentially in hardware to save space
                            // Let's use a temporary counter for edge iteration within this state
                            // To handle this cleanly, we can add a sub-state or reuse variables.
                            // Let's simplify: Assume we check all edges in one cycle (combinational check) 
                            // but sequential queue update.
                            
                            // Checking neighbors combinational logic
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < active_edges && edge_active[i]) begin
                                    // Check if edge starts at u
                                    if (edges_src[i] == u) begin
                                        reg [4:0] v;
                                        v = edges_dst[i];
                                        if (!visited[v]) begin
                                            visited[v] <= 1;
                                            parent_node[v] <= u; // Store parent, but we need edge index too for removal
                                            // Actually, to remove edges, we need the edge index.
                                            // Let's use parent_edge array instead.
                                            // Since this is always block, we can't easily return. 
                                            // Let's refine: We need an array parent_edge_idx.
                                        end
                                    end
                                end
                            end
                            // Since we can't easily handle the loop inside a sequential block for multiple edges per cycle 
                            // without causing multiple drivers or complex state, let's restructure FIND_PATH.
                            // Let's process 1 edge per cycle of the iteration.
                        end
                    end else if (bfs_head >= bfs_tail && !path_found) begin
                        // Queue empty, no path found
                        state <= CHECK_DONE;
                    end
                    
                    // RE-IMPLEMENTATION of FIND_PATH for strict sequential logic:
                    // We will use a dedicated edge counter `bfs_edge_idx` to scan edges.
                end

                UPDATE_GRAPH: begin
                    // We need to trace back from Sink (1) to Source (0) using parent info
                    // Remove the edges found.
                    // Since parent_node only stored source node, we need to find the edge connecting parent->child.
                    // We will iterate edges to find the match.
                    
                    // Step 1: Trace back logic (cycle efficient)
                    // If curr_node != 0:
                    //   Find edge where src == parent_node[curr_node] && dst == curr_node && edge_active
                    //   Mark that edge inactive.
                    //   Update total_time.
                    //   curr_node = parent_node[curr_node].
                    //   Repeat until curr_node == 0.
                    
                    // We can do this in one cycle if logic permits, but safer to do step-by-step.
                    // However, "Latency ~1000 cycles" allows iteration.
                    // Let's do one edge removal per cycle.
                    
                    if (curr_node != 0) begin
                        prev_node = parent_node[curr_node];
                        // Find edge
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < active_edges && edge_active[i]) begin
                                if (edges_src[i] == prev_node && edges_dst[i] == curr_node) begin
                                    edge_active[i] <= 0;
                                    total_time <= total_time + 1;
                                end
                            end
                        end
                        curr_node <= prev_node;
                    end else begin
                        // Path fully removed
                        state <= CHECK_DONE;
                        p_cnt <= p_cnt + 1;
                    end
                end

                CHECK_DONE: begin
                    if (p_cnt >= P) begin
                        possible <= 1;
                        people_left <= 0;
                        state <= FINISHED;
                    end else begin
                        // Check if more paths exist by attempting a BFS peek
                        // If no path, finish. If yes, go to FIND_PATH.
                        // We can just go to FIND_PATH. FIND_PATH will handle empty queue case.
                        // But we need to reset BFS variables for the next path search.
                        
                        // Reset BFS variables for next search
                        bfs_head <= 0;
                        bfs_tail <= 0;
                        
                        // We need to peek if a path exists. 
                        // Since we already transitioned from FIND_PATH (where no path was found) 
                        // or UPDATE_GRAPH (where path was found), we need to trigger a new search.
                        // However, CHECK_DONE is after a potential FIND_PATH failure or after UPDATE.
                        // If we came from UPDATE, we need to search again.
                        // If we came from FIND_PATH (no path), we are done.
                        
                        // Let's add a flag or logic to distinguish why we are here.
                        // Better approach: The transitions to CHECK_DONE:
                        // 1. From FIND_PATH: path_found == 0 (implicit, queue empty). -> Done.
                        // 2. From UPDATE_GRAPH: Always try next person.
                        
                        // Let's modify logic: 
                        // If p_cnt < P:
                        //   Try to find one more path.
                        //   We need to go back to FIND_PATH but we must ensure we don't loop forever if no path.
                        
                        // Revised logic for CHECK_DONE:
                        // If (p_cnt >= P) -> FINISHED.
                        // Else -> We need to check if another path exists.
                        // We can go to FIND_PATH. 
                        // But FIND_PATH needs to know if it's a fresh search or continuing.
                        // Let's assume we always reset BFS context before entering FIND_PATH from here.
                        
                        // To handle "no path found" termination in FIND_PATH:
                        // In FIND_PATH, if queue is empty and we haven't found a sink, we should go to FINISHED.
                        // So, if we are here (CHECK_DONE) and p_cnt < P, we assume a path was found in previous cycle (UPDATE_GRAPH).
                        // Wait, if previous state was FIND_PATH and it failed, we wouldn't be in CHECK_DONE, we would be in IDLE or FINISHED.
                        
                        // Let's fix the state transition logic:
                        // FIND_PATH: If path found -> UPDATE_GRAPH.
                        //            If no path (queue empty) -> FINISHED (Impossible).
                        // UPDATE_GRAPH -> CHECK_DONE.
                        // CHECK_DONE: If p_cnt >= P -> FINISHED.
                        //             Else -> FIND_PATH.
                        
                        // The issue: "If no path found, go to FINISHED" from CHECK_DONE requirement.
                        // This implies CHECK_DONE might be reached without a path just found.
                        // Let's assume CHECK_DONE handles the decision.
                        
                        // Let's rely on a 'temp_search_failed' flag set in FIND_PATH if it exhausts queue.
                        // But we don't have that.
                        
                        // Alternative: 
                        // We stay in CHECK_DONE. 
                        // If p_cnt >= P: FINISHED.
                        // Else: 
                        //   We need to try finding a path. 
                        //   We set up BFS (reset head/tail) and go to FIND_PATH.
                        //   But how do we know if it fails? 
                        //   We can go to FIND_PATH. 
                        //   In FIND_PATH, we check if a path exists. 
                        //   If the BFS finishes (queue empty) without reaching sink, we transition to FINISHED (Impossible).
                        
                        state <= FIND_PATH;
                    end
                end

                FINISHED: begin
                    done <= 1;
                    if (p_cnt < P) begin
                        possible <= 0;
                        people_left <= P - p_cnt;
                    end
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
            
            // ----------------------------------------------------------
            // SEPARATE LOGIC FOR BFS IMPLEMENTATION
            // The state machine above handles flow. 
            // The actual BFS traversal (queue filling) needs to happen in FIND_PATH.
            // Since standard always block can't easily do sequential processing of edges inside a state without variables,
            // we will define auxiliary registers to control BFS steps.
            // ----------------------------------------------------------
        end
    end

    // Auxiliary registers for BFS sequential logic
    reg [4:0] bfs_edge_idx; // Current edge index being scanned in BFS
    reg [4:0] bfs_node;     // Node currently being explored
    reg bfs_stage;          // 0: Pop node, 1: Scan edges
    reg [4:0] parent_edge_idx_store [7:0]; // Store edge index used to reach node
    
    // We need to re-write the always block to include this logic cleanly. 
    // Since the prompt asks for ONE module, I will merge the auxiliary logic into the main FSM block above,
    // but I need to declare the aux regs. I will refine the code in the final step.
    // Actually, I will rewrite the FSM block to be fully self-contained and correct.

endmodule

// Refined Module with integrated BFS control
module river_crossing_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] P,
    input [4:0] num_nodes,
    input [4:0] num_edges,
    input [5:0] edges_src [15:0],
    input [5:0] edges_dst [15:0],
    output reg [15:0] total_time,
    output reg [4:0] people_left,
    output reg done,
    output reg possible
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam FIND_PATH_RESET = 3'b010;
    localparam FIND_PATH_BFS = 3'b011;
    localparam UPDATE_PATH = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;
    
    // Registers
    reg [3:0] p_cnt;
    reg [4:0] active_edges;
    reg [15:0] total_time_reg;
    reg [4:0] people_left_reg;
    
    // Edge Status
    reg edge_active [15:0];
    
    // BFS Registers
    reg [4:0] q_nodes [15:0]; // Small queue (max 8 nodes typically, 16 is safe)
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [7:0] visited; // 8 nodes max
    reg [4:0] parent_node [7:0]; // Parent node ID
    reg [4:0] parent_edge [7:0]; // Edge index used to reach node
    
    // Path Reconstruction Registers
    reg [4:0] curr_node;
    reg [2:0] recon_step; // 0: find edge, 1: update stats, 2: move next
    reg [4:0] edge_scan_idx; // Counter for scanning edges to find path segment
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_time <= 0;
            people_left <= 0;
            done <= 0;
            possible <= 0;
            // Clear edge active
            for (i = 0; i < 16; i = i + 1) edge_active[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= INIT;
                end

                INIT: begin
                    total_time <= 0;
                    p_cnt <= 0;
                    // Setup edges
                    active_edges <= (num_edges > 16) ? 16 : num_edges;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < num_edges) edge_active[i] <= 1;
                        else edge_active[i] <= 0;
                    end
                    state <= FIND_PATH_RESET;
                end

                // Reset BFS structures for a new path search
                FIND_PATH_RESET: begin
                    q_head <= 0;
                    q_tail <= 0;
                    // Clear visited
                    for (i = 0; i < 8; i = i + 1) visited[i] <= 0;
                    // Start from Source (Node 0)
                    q_nodes[0] <= 0;
                    q_tail <= 1;
                    visited[0] <= 1;
                    parent_node[0] <= 5'h1F;
                    parent_edge[0] <= 5'h1F;
                    state <= FIND_PATH_BFS;
                end

                FIND_PATH_BFS: begin
                    // Standard BFS: Dequeue U, Find neighbors, Enqueue V
                    if (q_head == q_tail) begin
                        // Queue empty, no path found
                        state <= FINISHED;
                    end else begin
                        // Pop queue
                        reg [4:0] u;
                        u = q_nodes[q_head];
                        q_head <= q_head + 1;
                        
                        if (u == 1) begin // Sink found (Node 1)
                            state <= UPDATE_PATH;
                            curr_node <= 1;
                            recon_step <= 0;
                            edge_scan_idx <= 0;
                        end else begin
                            // Scan all edges to find neighbors
                            // We iterate through edges to find those starting at u
                            // To keep it cycle-efficient, we scan one edge per clock or do all in one block.
                            // With 16 edges, doing it in one block is efficient for FSM speed.
                            // Let's do combinational check inside sequential block.
                            
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < active_edges && edge_active[i]) begin
                                    if (edges_src[i] == u) begin
                                        reg [4:0] v;
                                        v = edges_dst[i];
                                        if (!visited[v]) begin
                                            visited[v] <= 1;
                                            parent_node[v] <= u;
                                            parent_edge[v] <= i[4:0];
                                            // Enqueue
                                            if (q_tail < 16) begin
                                                q_nodes[q_tail] <= v;
                                                q_tail <= q_tail + 1;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                UPDATE_PATH: begin
                    // Reconstruct path: Start at sink (1), trace parents to source (0)
                    // Remove edges as we go.
                    if (curr_node == 0) begin
                        // Path removed, person crossed
                        p_cnt <= p_cnt + 1;
                        state <= CHECK_DONE;
                    end else begin
                        // Find edge corresponding to curr_node and parent_node[curr_node]
                        // We use the stored parent_edge array to get the index directly!
                        // This is much faster than re-scanning.
                        reg [4:0] e_idx;
                        e_idx = parent_edge[curr_node];
                        
                        if (e_idx != 5'h1F && edge_active[e_idx]) begin
                            edge_active[e_idx] <= 0;
                            total_time <= total_time + 1;
                        end
                        
                        curr_node <= parent_node[curr_node];
                    end
                end

                CHECK_DONE: begin
                    if (p_cnt >= P) begin
                        possible <= 1;
                        people_left <= 0;
                        state <= FINISHED;
                    end else begin
                        // Check if any edge exists from source to allow another path
                        // Just proceed to find next path
                        state <= FIND_PATH_RESET;
                    end
                end

                FINISHED: begin
                    done <= 1;
                    if (p_cnt < P) begin
                        possible <= 0;
                        people_left <= P - p_cnt;
                    end
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule