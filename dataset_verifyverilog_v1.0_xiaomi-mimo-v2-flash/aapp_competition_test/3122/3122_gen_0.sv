module GraphColoring (
    input clk,
    input rst_n,
    input start,
    input [3:0] edge_count,
    input [2:0] u_0, v_0, u_1, v_1, u_2, v_2, u_3, v_3,
    input [2:0] u_4, v_4, u_5, v_5, u_6, v_6, u_7, v_7,
    input [2:0] u_8, v_8, u_9, v_9, u_10, v_10, u_11, v_11,
    input [2:0] u_12, v_12, u_13, v_13, u_14, v_14, u_15, v_15,
    input [1:0] c_0, c_1, c_2, c_3,
    input [1:0] c_4, c_5, c_6, c_7,
    input [1:0] c_8, c_9, c_10, c_11,
    input [1:0] c_12, c_13, c_14, c_15,
    output reg done,
    output reg impossible,
    output reg [3:0] min_lounges
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT_NODES  = 3'd1;
    localparam [2:0] PROCESS_EDGES = 3'd2;
    localparam [2:0] CHECK_COMPONENT = 3'd3;
    localparam [2:0] COUNT_LOUNGES = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] assigned [0:7];      // Node assignment (0 or 1)
    reg [7:0] visited [0:7];       // Visited flag
    reg [2:0] current_node;
    reg [3:0] edge_idx;
    reg [2:0] node_idx;
    reg [3:0] lounge_count;
    reg conflict_detected;
    reg [7:0] component_visited [0:7]; // For component BFS
    reg [2:0] queue [0:7];         // Simple FIFO for BFS
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg queue_empty;
    reg [2:0] queue_node;
    reg [2:0] neighbor_node;
    reg [1:0] constraint_val;
    reg [2:0] u_reg, v_reg;
    reg [1:0] c_reg;
    reg [2:0] node_iter;
    reg [7:0] total_lounges;

    // Store edges locally (16 edges, each 3+3+2 = 8 bits)
    reg [2:0] stored_u [0:15];
    reg [2:0] stored_v [0:15];
    reg [1:0] stored_c [0:15];

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT_NODES : IDLE;
            INIT_NODES: next_state = PROCESS_EDGES;
            PROCESS_EDGES: next_state = (edge_idx >= edge_count) ? CHECK_COMPONENT : PROCESS_EDGES;
            CHECK_COMPONENT: begin
                if (queue_empty) begin
                    if (node_iter >= 8'd8) next_state = COUNT_LOUNGES;
                    else next_state = CHECK_COMPONENT;
                end else begin
                    next_state = CHECK_COMPONENT;
                end
            end
            COUNT_LOUNGES: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            min_lounges <= 4'd0;
            edge_idx <= 4'd0;
            node_iter <= 3'd0;
            cycle_count <= 8'd0;
            conflict_detected <= 1'b0;
            total_lounges <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                assigned[i] <= 8'd0;
                visited[i] <= 8'd0;
                component_visited[i] <= 8'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                stored_u[i] <= 3'd0;
                stored_v[i] <= 3'd0;
                stored_c[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            
            // Cycle counter
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                impossible <= 1'b1;
                done <= 1'b1;
                state <= FINISH;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Sample edge inputs
                        stored_u[0] <= u_0; stored_v[0] <= v_0; stored_c[0] <= c_0;
                        stored_u[1] <= u_1; stored_v[1] <= v_1; stored_c[1] <= c_1;
                        stored_u[2] <= u_2; stored_v[2] <= v_2; stored_c[2] <= c_2;
                        stored_u[3] <= u_3; stored_v[3] <= v_3; stored_c[3] <= c_3;
                        stored_u[4] <= u_4; stored_v[4] <= v_4; stored_c[4] <= c_4;
                        stored_u[5] <= u_5; stored_v[5] <= v_5; stored_c[5] <= c_5;
                        stored_u[6] <= u_6; stored_v[6] <= v_6; stored_c[6] <= c_6;
                        stored_u[7] <= u_7; stored_v[7] <= v_7; stored_c[7] <= c_7;
                        stored_u[8] <= u_8; stored_v[8] <= v_8; stored_c[8] <= c_8;
                        stored_u[9] <= u_9; stored_v[9] <= v_9; stored_c[9] <= c_9;
                        stored_u[10] <= u_10; stored_v[10] <= v_10; stored_c[10] <= c_10;
                        stored_u[11] <= u_11; stored_v[11] <= v_11; stored_c[11] <= c_11;
                        stored_u[12] <= u_12; stored_v[12] <= v_12; stored_c[12] <= c_12;
                        stored_u[13] <= u_13; stored_v[13] <= v_13; stored_c[13] <= c_13;
                        stored_u[14] <= u_14; stored_v[14] <= v_14; stored_c[14] <= c_14;
                        stored_u[15] <= u_15; stored_v[15] <= v_15; stored_c[15] <= c_15;
                    end
                end

                INIT_NODES: begin
                    // Initialize all nodes to unassigned (-1 means unassigned)
                    for (i = 0; i < 8; i = i + 1) begin
                        assigned[i] <= 8'hFF; // Use 255 as unassigned marker
                        visited[i] <= 8'd0;
                        component_visited[i] <= 8'd0;
                    end
                    edge_idx <= 4'd0;
                    node_iter <= 3'd0;
                    conflict_detected <= 1'b0;
                    total_lounges <= 8'd0;
                end

                PROCESS_EDGES: begin
                    // Apply constraints to assigned values
                    // If unassigned, set based on constraint
                    // c=0: both 0, c=2: both 1, c=1: one 0 one 1
                    u_reg <= stored_u[edge_idx];
                    v_reg <= stored_v[edge_idx];
                    c_reg <= stored_c[edge_idx];
                    
                    edge_idx <= edge_idx + 4'd1;
                    
                    // Logic handled in combinational below or here
                end

                CHECK_COMPONENT: begin
                    if (!queue_empty) begin
                        // Process queue head
                        // Pop from queue
                        queue_head <= queue_head + 3'd1;
                        if (queue_head + 3'd1 == queue_tail) begin
                            queue_empty <= 1'b1;
                        end
                        
                        // Get node
                        queue_node <= queue[queue_head];
                    end else begin
                        // Find next unvisited node for new component
                        if (node_iter < 8'd8) begin
                            if (!component_visited[node_iter]) begin
                                // Start BFS from this node
                                component_visited[node_iter] <= 8'd1;
                                assigned[node_iter] <= 8'd0; // Assign 0 initially
                                visited[node_iter] <= 8'd1;
                                queue[0] <= node_iter;
                                queue_tail <= 3'd1;
                                queue_head <= 3'd0;
                                queue_empty <= 1'b0;
                            end
                            node_iter <= node_iter + 3'd1;
                        end
                    end
                end

                COUNT_LOUNGES: begin
                    // Count total lounges
                    if (!conflict_detected) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (assigned[i] == 8'd1) begin
                                total_lounges <= total_lounges + 8'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    impossible <= conflict_detected;
                    if (!conflict_detected) begin
                        min_lounges <= total_lounges[3:0];
                    end else begin
                        min_lounges <= 4'd0;
                    end
                end
            endcase
        end
    end

    // Edge processing logic (combinational for immediate conflict check)
    always @(*) begin
        if (state == PROCESS_EDGES) begin
            // Check constraint consistency
            if (stored_c[edge_idx] == 2'd0) begin
                // Both must be 0
                if (stored_u[edge_idx] == stored_v[edge_idx]) begin
                    // Self loop with c=0 is valid (0)
                end else begin
                    // If one is 1, conflict
                    if (assigned[stored_u[edge_idx]] == 8'd1 || assigned[stored_v[edge_idx]] == 8'd1) begin
                        if (assigned[stored_u[edge_idx]] != 8'hFF && assigned[stored_u[edge_idx]] == 8'd1) conflict_detected = 1'b1;
                        if (assigned[stored_v[edge_idx]] != 8'hFF && assigned[stored_v[edge_idx]] == 8'd1) conflict_detected = 1'b1;
                    end
                    // Assign 0 to unassigned
                    if (assigned[stored_u[edge_idx]] == 8'hFF) assigned[stored_u[edge_idx]] = 8'd0;
                    if (assigned[stored_v[edge_idx]] == 8'hFF) assigned[stored_v[edge_idx]] = 8'd0;
                end
            end else if (stored_c[edge_idx] == 2'd2) begin
                // Both must be 1
                if (stored_u[edge_idx] == stored_v[edge_idx]) begin
                    // Self loop with c=2 is valid (1)
                    if (assigned[stored_u[edge_idx]] == 8'hFF) assigned[stored_u[edge_idx]] = 8'd1;
                    else if (assigned[stored_u[edge_idx]] == 8'd0) conflict_detected = 1'b1;
                end else begin
                    // If one is 0, conflict
                    if (assigned[stored_u[edge_idx]] == 8'd0 || assigned[stored_v[edge_idx]] == 8'd0) begin
                        if (assigned[stored_u[edge_idx]] != 8'hFF && assigned[stored_u[edge_idx]] == 8'd0) conflict_detected = 1'b1;
                        if (assigned[stored_v[edge_idx]] != 8'hFF && assigned[stored_v[edge_idx]] == 8'd0) conflict_detected = 1'b1;
                    end
                    // Assign 1 to unassigned
                    if (assigned[stored_u[edge_idx]] == 8'hFF) assigned[stored_u[edge_idx]] = 8'd1;
                    if (assigned[stored_v[edge_idx]] == 8'hFF) assigned[stored_v[edge_idx]] = 8'd1;
                end
            end else begin // c=1
                // XOR constraint
                if (stored_u[edge_idx] == stored_v[edge_idx]) begin
                    // Self loop with c=1 is impossible
                    conflict_detected = 1'b1;
                end else begin
                    if (assigned[stored_u[edge_idx]] != 8'hFF && assigned[stored_v[edge_idx]] != 8'hFF) begin
                        // Both assigned, check conflict
                        if (assigned[stored_u[edge_idx]] == assigned[stored_v[edge_idx]]) conflict_detected = 1'b1;
                    end else if (assigned[stored_u[edge_idx]] != 8'hFF) begin
                        // Only U assigned
                        assigned[stored_v[edge_idx]] = assigned[stored_u[edge_idx]] ^ 8'd1;
                    end else if (assigned[stored_v[edge_idx]] != 8'hFF) begin
                        // Only V assigned
                        assigned[stored_u[edge_idx]] = assigned[stored_v[edge_idx]] ^ 8'd1;
                    end else begin
                        // Neither assigned - wait for BFS to handle
                        // (This path is less optimal for initialization, BFS will handle)
                    end
                end
            end
        end else begin
            conflict_detected = conflict_detected; // Hold value
        end
    end

    // Queue and BFS processing logic
    always @(*) begin
        if (state == CHECK_COMPONENT && !queue_empty) begin
            // Process neighbors of queue_node
            // Check all edges
            for (i = 0; i < 16; i = i + 1) begin
                if (i < edge_count) begin
                    if (stored_u[i] == queue_node) begin
                        neighbor_node = stored_v[i];
                        constraint_val = stored_c[i];
                    end else if (stored_v[i] == queue_node) begin
                        neighbor_node = stored_u[i];
                        constraint_val = stored_c[i];
                    end else begin
                        neighbor_node = 3'd7; // Dummy
                        constraint_val = 2'd0;
                    end
                    
                    // Only process if neighbor matches queue_node
                    if ((stored_u[i] == queue_node) || (stored_v[i] == queue_node)) begin
                        if (constraint_val == 2'd0) begin
                            // Neighbor must be 0
                            if (assigned[neighbor_node] == 8'hFF) begin
                                assigned[neighbor_node] = 8'd0;
                            end else if (assigned[neighbor_node] == 8'd1) begin
                                conflict_detected = 1'b1;
                            end
                        end else if (constraint_val == 2'd2) begin
                            // Neighbor must be 1
                            if (assigned[neighbor_node] == 8'hFF) begin
                                assigned[neighbor_node] = 8'd1;
                            end else if (assigned[neighbor_node] == 8'd0) begin
                                conflict_detected = 1'b1;
                            end
                        end else begin // c=1
                            // Neighbor must be opposite
                            if (assigned[neighbor_node] == 8'hFF) begin
                                assigned[neighbor_node] = assigned[queue_node] ^ 8'd1;
                            end else if (assigned[neighbor_node] == assigned[queue_node]) begin
                                conflict_detected = 1'b1;
                            end
                        end
                        
                        // Add to queue if not visited
                        if (!component_visited[neighbor_node]) begin
                            component_visited[neighbor_node] = 8'd1;
                            queue[queue_tail] = neighbor_node;
                            queue_tail = queue_tail + 3'd1;
                            queue_empty = 1'b0;
                        end
                    end
                end
            end
        end
    end

endmodule