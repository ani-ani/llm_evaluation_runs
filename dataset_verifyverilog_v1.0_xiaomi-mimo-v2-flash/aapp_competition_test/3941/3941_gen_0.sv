module door_unlocker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] door_status,
    input wire [255:0] switch_ctrl,
    input wire [3:0] room_index,
    input wire load_room,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] LOAD_ADJ      = 3'd2;
    localparam [2:0] CHECK_BFS     = 3'd3;
    localparam [2:0] PROCESS_NODE  = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] current_node;
    reg [3:0] node_idx;
    reg [3:0] neighbor_idx;
    reg [3:0] switch_a, switch_b;
    reg [7:0] cycle_count;
    reg [3:0] bfs_queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;
    reg [15:0] visited;
    reg [15:0] color;
    
    // Adjacency matrix: adj[15:0][15:0]
    reg [15:0] adj [0:15];
    
    // Helper variables
    integer i;
    reg found_switch;
    reg conflict;
    reg edge_weight;
    reg [3:0] dequeued_node;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_node <= 4'd0;
            node_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            switch_a <= 4'd0;
            switch_b <= 4'd0;
            cycle_count <= 8'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            visited <= 16'd0;
            color <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                bfs_queue[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Clear adjacency matrix and counters
                    for (i = 0; i < 16; i = i + 1) begin
                        adj[i] <= 16'd0;
                    end
                    visited <= 16'd0;
                    color <= 16'd0;
                    node_idx <= 4'd0;
                    state <= LOAD_ADJ;
                end
                
                LOAD_ADJ: begin
                    // Wait for load_room signal from external
                    if (load_room) begin
                        // Extract the two switches from switch_ctrl
                        found_switch <= 1'b0;
                        switch_a <= 4'd0;
                        switch_b <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (switch_ctrl[i]) begin
                                if (!found_switch) begin
                                    switch_a <= i[3:0];
                                    found_switch <= 1'b1;
                                end else begin
                                    switch_b <= i[3:0];
                                end
                            end
                        end
                        // Wait one cycle to ensure switch_a/b are captured
                        state <= 3'd6; // Intermediate state
                    end else if (node_idx >= 4'd16) begin
                        // All rooms loaded, proceed to BFS
                        node_idx <= 4'd0;
                        state <= CHECK_BFS;
                    end
                end
                
                3'd6: begin
                    // Update adjacency matrix based on door status
                    if (door_status[room_index]) begin
                        // Door unlocked: same color required (weight 1)
                        adj[switch_a][switch_a] <= 1'b1;
                        adj[switch_b][switch_b] <= 1'b1;
                    end else begin
                        // Door locked: different color required (weight 0)
                        adj[switch_a][switch_b] <= 1'b1;
                        adj[switch_b][switch_a] <= 1'b1;
                    end
                    node_idx <= node_idx + 4'd1;
                    state <= LOAD_ADJ;
                end
                
                CHECK_BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if all nodes visited or cycle limit reached
                    if (cycle_count >= 8'd100 || node_idx >= 4'd16) begin
                        // Done with BFS, result remains 1 if no conflict
                        state <= FINISH;
                    end else if (!visited[node_idx]) begin
                        // Start BFS for unvisited node
                        current_node <= node_idx;
                        visited[node_idx] <= 1'b1;
                        color[node_idx] <= 1'b0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        queue_count <= 4'd1;
                        bfs_queue[0] <= node_idx;
                        state <= PROCESS_NODE;
                    end else begin
                        // Move to next node
                        node_idx <= node_idx + 4'd1;
                    end
                end
                
                PROCESS_NODE: begin
                    if (queue_count == 4'd0) begin
                        // Queue empty, move to next node
                        node_idx <= node_idx + 4'd1;
                        state <= CHECK_BFS;
                    end else begin
                        // Dequeue
                        dequeued_node <= bfs_queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_count <= queue_count - 4'd1;
                        neighbor_idx <= 4'd0;
                        conflict <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for neighbor processing and conflict detection
    always @(*) begin
        if (state == PROCESS_NODE && queue_count > 4'd0) begin
            // Process neighbors
            if (neighbor_idx < 4'd16) begin
                if (adj[dequeued_node][neighbor_idx]) begin
                    // Edge exists
                    if (visited[neighbor_idx]) begin
                        // Check color consistency
                        if (adj[dequeued_node][neighbor_idx]) begin
                            // If edge weight is 1 (unlocked), colors must be same
                            if (color[neighbor_idx] != color[dequeued_node]) begin
                                conflict = 1'b1;
                            end
                        end else begin
                            // If edge weight is 0 (locked), colors must be different
                            if (color[neighbor_idx] == color[dequeued_node]) begin
                                conflict = 1'b1;
                            end
                        end
                    end else begin
                        // Visit neighbor
                        // Note: This is tricky in combinational logic. We handle updates in sequential block below.
                    end
                end
            end
        end else begin
            conflict = 1'b0;
        end
    end
    
    // Sequential logic for neighbor updates and conflict handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == PROCESS_NODE && queue_count > 4'd0) begin
                if (neighbor_idx < 4'd16) begin
                    if (adj[dequeued_node][neighbor_idx]) begin
                        if (visited[neighbor_idx]) begin
                            // Conflict check logic (repeated for safety)
                            if (adj[dequeued_node][neighbor_idx]) begin
                                if (color[neighbor_idx] != color[dequeued_node]) begin
                                    result <= 1'b0;
                                    state <= FINISH;
                                end
                            end else begin
                                if (color[neighbor_idx] == color[dequeued_node]) begin
                                    result <= 1'b0;
                                    state <= FINISH;
                                end
                            end
                        end else begin
                            // Visit neighbor
                            visited[neighbor_idx] <= 1'b1;
                            // Determine neighbor color based on edge type
                            // adj[u][v] is 1 if edge exists. Weight logic:
                            // If adj[u][v] was set in LOAD_ADJ for unlocked: we used diagonal bits.
                            // If adj[u][v] was set for locked: we used symmetric bits.
                            // Wait, we need to distinguish edge weights.
                            // Let's use a separate weight matrix or encode in adj.
                            // Modification: Use adj for connectivity, separate weight array.
                            // Since we are constrained, let's reinterpret adj.
                            // Actually, standard bipartite check just needs connectivity.
                            // The problem is edge constraints. 
                            // If unlocked (1): u and v same color.
                            // If locked (0): u and v different color.
                            // We need to know the weight of the edge dequeued_node -> neighbor_idx.
                            // In LOAD_ADJ we only set bits. We lost weight info.
                            // Fix: Use adj_weight[15:0][15:0] or reuse bits.
                            // Let's assume we can store weight in MSB or separate array.
                            // Given constraints, we'll infer weight from the index check performed in LOAD_ADJ.
                            // If we set adj[a][a] it was unlocked. If adj[a][b] it was locked.
                            // This is ambiguous. Let's use a separate weight register.
                        end
                        neighbor_idx <= neighbor_idx + 4'd1;
                    end else begin
                        neighbor_idx <= neighbor_idx + 4'd1;
                    end
                end else begin
                    // Finished neighbors
                    state <= PROCESS_NODE; // Stay in process to dequeue next
                end
            end
        end
    end

    // Re-implementation of BFS logic with proper weight handling
    // We need to store weights. Let's define weight_reg.
    reg [15:0] weight_reg [0:15]; // 0 = locked (diff), 1 = unlocked (same)
    
    // Override LOAD_ADJ to write to weight_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else begin
            if (state == 3'd6) begin
                if (door_status[room_index]) begin
                    weight_reg[switch_a][switch_a] <= 1'b1; // Dummy self-reference for unlocked
                    weight_reg[switch_b][switch_b] <= 1'b1;
                end else begin
                    weight_reg[switch_a][switch_b] <= 1'b0; // Locked
                    weight_reg[switch_b][switch_a] <= 1'b0;
                end
            end
        end
    end

    // Complete rewrite of PROCESS_NODE to be robust
    // We will split PROCESS_NODE into sub-states or handle carefully in one block.
    // Given the complexity and Icarus Verilog restrictions, a multi-always approach is risky.
    // Let's consolidate into the main FSM block with better structure.

endmodule

// Corrected complete module
module door_unlocker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] door_status,
    input wire [255:0] switch_ctrl,
    input wire [3:0] room_index,
    input wire load_room,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] LOAD_ADJ      = 3'd2;
    localparam [2:0] CHECK_BFS     = 3'd3;
    localparam [2:0] BFS_START     = 3'd4;
    localparam [2:0] BFS_LOOP      = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Registers
    reg [2:0] state;
    reg [3:0] current_node;
    reg [3:0] node_idx;
    reg [3:0] neighbor_idx;
    reg [3:0] switch_a, switch_b;
    reg [7:0] cycle_count;
    reg [3:0] queue [0:15];
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [3:0] q_count;
    reg [15:0] visited;
    reg [15:0] color;
    reg [15:0] adj [0:15];
    reg [15:0] weight [0:15]; // 0=locked (diff), 1=unlocked (same)
    
    // Temporary vars
    integer i;
    reg [3:0] u;
    reg [3:0] v;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            visited <= 16'd0;
            color <= 16'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            q_count <= 4'd0;
            node_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                weight[i] <= 16'd0;
                queue[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        result <= 1'b1; // Assume YES until conflict
                    end
                end
                
                INIT: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        adj[i] <= 16'd0;
                        weight[i] <= 16'd0;
                    end
                    visited <= 16'd0;
                    color <= 16'd0;
                    node_idx <= 4'd0;
                    state <= LOAD_ADJ;
                end
                
                LOAD_ADJ: begin
                    if (load_room) begin
                        // Find switches
                        found = 1'b0;
                        switch_a = 4'd0;
                        switch_b = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (switch_ctrl[i]) begin
                                if (!found) begin
                                    switch_a = i[3:0];
                                    found = 1'b1;
                                end else begin
                                    switch_b = i[3:0];
                                end
                            end
                        end
                        // Update Matrix
                        if (door_status[room_index]) begin
                            // Unlocked: requires same color
                            adj[switch_a][switch_a] <= 1'b1; // Self-loop for connectivity? No, just flags.
                            adj[switch_b][switch_b] <= 1'b1;
                            weight[switch_a][switch_a] <= 1'b1;
                            weight[switch_b][switch_b] <= 1'b1;
                        end else begin
                            // Locked: requires diff color
                            adj[switch_a][switch_b] <= 1'b1;
                            adj[switch_b][switch_a] <= 1'b1;
                            weight[switch_a][switch_b] <= 1'b0;
                            weight[switch_b][switch_a] <= 1'b0;
                        end
                    end
                    if (load_room || node_idx >= 4'd16) begin
                        node_idx <= node_idx + 4'd1;
                        if (node_idx >= 4'd16) begin
                            node_idx <= 4'd0;
                            cycle_count <= 8'd0;
                            state <= CHECK_BFS;
                        end
                    end
                end
                
                CHECK_BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd100) begin
                        state <= FINISH;
                    end else if (node_idx < 4'd16) begin
                        if (!visited[node_idx]) begin
                            state <= BFS_START;
                        end else begin
                            node_idx <= node_idx + 4'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                BFS_START: begin
                    // Initialize BFS for current_node = node_idx
                    current_node <= node_idx;
                    visited[node_idx] <= 1'b1;
                    color[node_idx] <= 1'b0;
                    queue[0] <= node_idx;
                    q_head <= 4'd0;
                    q_tail <= 4'd1;
                    q_count <= 4'd1;
                    neighbor_idx <= 4'd0;
                    state <= BFS_LOOP;
                end
                
                BFS_LOOP: begin
                    if (q_count == 4'd0) begin
                        // BFS complete for this component
                        node_idx <= node_idx + 4'd1;
                        state <= CHECK_BFS;
                    end else begin
                        u = queue[q_head];
                        q_head <= q_head + 4'd1;
                        q_count <= q_count - 4'd1;
                        
                        // Check all neighbors of u
                        if (neighbor_idx < 4'd16) begin
                            if (adj[u][neighbor_idx]) begin
                                v = neighbor_idx;
                                if (visited[v]) begin
                                    // Check conflict
                                    if (weight[u][v] == 1'b1) begin
                                        // Unlocked (same color required)
                                        if (color[u] != color[v]) begin
                                            result <= 1'b0;
                                            state <= FINISH;
                                        end
                                    end else begin
                                        // Locked (different color required)
                                        if (color[u] == color[v]) begin
                                            result <= 1'b0;
                                            state <= FINISH;
                                        end
                                    end
                                end else begin
                                    // Visit v
                                    visited[v] <= 1'b1;
                                    if (weight[u][v] == 1'b1) begin
                                        color[v] <= color[u]; // Same
                                    end else begin
                                        color[v] <= ~color[u]; // Different
                                    end
                                    // Enqueue v
                                    queue[q_tail] <= v;
                                    q_tail <= q_tail + 4'd1;
                                    q_count <= q_count + 4'd1;
                                end
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end else begin
                            // Done with this node's neighbors
                            neighbor_idx <= 4'd0;
                            // Loop will dequeue next node if q_count > 0
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule