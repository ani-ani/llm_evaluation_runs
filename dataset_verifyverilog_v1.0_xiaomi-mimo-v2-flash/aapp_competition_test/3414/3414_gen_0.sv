module TopGearTameRacingDriver (
    input clk,
    input rst_n,
    input start,
    input [15:0] node_x [0:15],
    input [15:0] node_y [0:15],
    input [4:0] edge_u [0:31],
    input [4:0] edge_v [0:31],
    input [4:0] num_nodes,
    input [5:0] num_edges,
    output reg [47:0] result,
    output reg done
);

    // Internal parameters
    localparam [3:0] MAX_DEG = 4'd4;
    localparam [5:0] MAX_EDGES = 6'd32;
    localparam [5:0] MAX_NODES = 6'd16;
    localparam [15:0] PI_Q16_16 = 16'h3243; // pi in Q16.16
    localparam [15:0] PI_2_Q16_16 = 16'h1921; // pi/2 in Q16.16
    localparam [5:0] MAX_CYCLES = 6'd50;

    // FSM States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] BUILD_ADJ = 4'd1;
    localparam [3:0] INIT_SEARCH = 4'd2;
    localparam [3:0] FIND_NEXT = 4'd3;
    localparam [3:0] CALC_ANGLE = 4'd4;
    localparam [3:0] UPDATE_SUM = 4'd5;
    localparam [3:0] UPDATE_NODE = 4'd6;
    localparam [3:0] CHECK_COMPLETE = 4'd7;
    localparam [3:0] BACKTRACK = 4'd8;
    localparam [3:0] NEXT_COMBINATION = 4'd9;
    localparam [3:0] UPDATE_BEST = 4'd10;
    localparam [3:0] FINISH = 4'd11;

    reg [3:0] state, next_state;
    reg [5:0] cycle_count;

    // Memory structures for graph (using registers for small size)
    reg [4:0] adj_nodes [0:15][0:3]; // Adjacency list for each node
    reg [3:0] adj_count [0:15]; // Number of neighbors per node
    reg [4:0] current_edge_idx [0:15][0:3]; // Edge index for each adjacency
    
    // Search state
    reg [4:0] search_path [0:31]; // Node indices in current path
    reg [4:0] path_len;
    reg [4:0] curr_node;
    reg [4:0] prev_node;
    reg [47:0] curr_sum; // Q32.16
    reg [47:0] best_sum; // Q32.16
    reg [4:0] visited_edges [0:31]; // Mark used edges
    reg [5:0] combo_index; // Track combination state
    
    // Temporary registers for calculation
    reg signed [15:0] v1_x, v1_y, v2_x, v2_y;
    reg [47:0] cross_prod; // 32-bit * 16-bit = 48-bit
    reg [47:0] dot_prod;
    reg signed [31:0] mag1, mag2;
    reg [15:0] angle_angle; // Q16.16
    
    // Helper signals
    reg [4:0] i, j, k;
    reg [4:0] temp_node;
    reg [4:0] temp_edge;
    reg found_valid;
    
    // LUT for atan2 approximation (simplified)
    // Returns angle in Q16.16 for Q16.0 inputs
    function automatic [15:0] atan2_approx;
        input signed [15:0] y;
        input signed [15:0] x;
        reg [15:0] abs_y;
        reg [15:0] abs_x;
        reg [15:0] r;
        reg [15:0] r_sq;
        reg [15:0] angle;
        begin
            abs_y = (y[15] ? -y : y);
            abs_x = (x[15] ? -x : x);
            
            // Handle quadrants
            if (x >= 0 && abs_y >= 0) begin
                // 0 to 90 degrees
                if (abs_x >= abs_y) begin
                    angle = 16'd0;
                end else begin
                    // y/x > 1, use approximation
                    // simple 45 deg offset
                    angle = PI_2_Q16_16 - (abs_y - abs_x); 
                end
            end else if (x < 0 && abs_y >= 0) begin
                // 90 to 180 degrees
                angle = PI_Q16_16;
            end else if (x < 0) begin
                // 180 to 270 degrees
                angle = PI_Q16_16;
            end else begin
                // 270 to 360 degrees
                angle = 16'd0;
            end
            
            // Apply sign to angle based on y
            if (y[15] && !x[15]) begin
                angle = PI_Q16_16 - angle;
            end else if (!y[15] && x[15]) begin
                // handled above
            end
            
            // Very coarse approximation for demo purposes
            // In real hardware, this would be a lookup table
            atan2_approx = angle;
        end
    endfunction

    // Controller FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 48'd0;
            best_sum <= 48'hFFFFFFFFFFFF; // Max value
            curr_sum <= 48'd0;
            path_len <= 5'd0;
            curr_node <= 5'd0;
            prev_node <= 5'd0;
            combo_index <= 6'd0;
            cycle_count <= 6'd0;
            for (i = 0; i < 16; i = i + 1) begin
                adj_count[i] <= 4'd0;
                for (j = 0; j < 4; j = j + 1) begin
                    adj_nodes[i][j] <= 5'd0;
                    current_edge_idx[i][j] <= 5'd0;
                end
            end
            for (i = 0; i < 32; i = i + 1) begin
                search_path[i] <= 5'd0;
                visited_edges[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    best_sum <= 48'hFFFFFFFFFFFF;
                    cycle_count <= 6'd0;
                end
                
                INIT_SEARCH: begin
                    path_len <= 5'd0;
                    search_path[0] <= 5'd0; // Start at node 0
                    curr_node <= 5'd0;
                    prev_node <= 5'd0;
                    curr_sum <= 48'd0;
                    combo_index <= 6'd0;
                    for (i = 0; i < 32; i = i + 1) begin
                        visited_edges[i] <= 1'b0;
                    end
                end
                
                CALC_ANGLE: begin
                    // Vector 1: prev -> curr
                    v1_x <= node_x[curr_node] - node_x[prev_node];
                    v1_y <= node_y[curr_node] - node_y[prev_node];
                    // Vector 2: curr -> next (will be loaded later)
                    // Actually we calculate inside state logic
                end
                
                UPDATE_SUM: begin
                    // Accumulate angle (simplified)
                    // In real implementation, angle_angle comes from atan2 logic
                    if (path_len > 1) begin
                        curr_sum <= curr_sum + {32'd0, angle_angle};
                    end
                end
                
                UPDATE_NODE: begin
                    search_path[path_len] <= curr_node;
                    path_len <= path_len + 5'd1;
                end
                
                UPDATE_BEST: begin
                    if (curr_sum < best_sum) begin
                        best_sum <= curr_sum;
                    end
                end
                
                FINISH: begin
                    result <= best_sum;
                    done <= 1'b1;
                end
            endcase
            
            cycle_count <= cycle_count + 6'd1;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_ADJ;
            end
            
            BUILD_ADJ: begin
                // Build adjacency lists from edges
                // Since edges are small, we can do this in cycles
                if (cycle_count == num_edges) begin
                    next_state = INIT_SEARCH;
                end else begin
                    next_state = BUILD_ADJ; // Stay here to process all edges
                end
            end
            
            INIT_SEARCH: begin
                next_state = FIND_NEXT;
            end
            
            FIND_NEXT: begin
                // Look for next unvisited edge from current node
                found_valid = 1'b0;
                temp_node = 5'd0;
                temp_edge = 5'd0;
                
                for (k = 0; k < adj_count[curr_node]; k = k + 1) begin
                    if (!found_valid && !visited_edges[current_edge_idx[curr_node][k]]) begin
                        found_valid = 1'b1;
                        temp_edge = current_edge_idx[curr_node][k];
                        // Determine next node
                        if (edge_u[temp_edge] == curr_node) begin
                            temp_node = edge_v[temp_edge];
                        end else begin
                            temp_node = edge_u[temp_edge];
                        end
                    end
                end
                
                if (found_valid) begin
                    if (path_len >= 2) begin
                        next_state = CALC_ANGLE;
                    end else begin
                        next_state = UPDATE_NODE;
                    end
                end else begin
                    next_state = CHECK_COMPLETE;
                end
            end
            
            CALC_ANGLE: begin
                next_state = UPDATE_SUM;
            end
            
            UPDATE_SUM: begin
                next_state = UPDATE_NODE;
            end
            
            UPDATE_NODE: begin
                visited_edges[temp_edge] = 1'b1;
                prev_node = curr_node;
                curr_node = temp_node;
                next_state = FIND_NEXT;
            end
            
            CHECK_COMPLETE: begin
                if (path_len == num_edges) begin
                    next_state = UPDATE_BEST;
                end else begin
                    next_state = BACKTRACK;
                end
            end
            
            UPDATE_BEST: begin
                next_state = BACKTRACK;
            end
            
            BACKTRACK: begin
                if (path_len == 0) begin
                    next_state = FINISH;
                end else begin
                    // Simple backtracking: try next combination
                    // Note: Full combinatorial exploration is complex
                    // This is a simplified DFS
                    if (combo_index < 2) begin
                        combo_index = combo_index + 1;
                        next_state = INIT_SEARCH;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Build Adjacency Logic (combinational for edge processing)
    always @(posedge clk) begin
        if (state == BUILD_ADJ && cycle_count < num_edges) begin
            // Add edge to adjacency lists
            // Note: This is a simplified version
            // Real implementation needs to track which node has which neighbor
            // And handle degree-4 pairing state
            
            // For node U
            if (adj_count[edge_u[cycle_count]] < MAX_DEG) begin
                adj_nodes[edge_u[cycle_count]][adj_count[edge_u[cycle_count]]] <= edge_v[cycle_count];
                current_edge_idx[edge_u[cycle_count]][adj_count[edge_u[cycle_count]]] <= cycle_count;
                adj_count[edge_u[cycle_count]] <= adj_count[edge_u[cycle_count]] + 4'd1;
            end
            
            // For node V
            if (adj_count[edge_v[cycle_count]] < MAX_DEG) begin
                adj_nodes[edge_v[cycle_count]][adj_count[edge_v[cycle_count]]] <= edge_u[cycle_count];
                current_edge_idx[edge_v[cycle_count]][adj_count[edge_v[cycle_count]]] <= cycle_count;
                adj_count[edge_v[cycle_count]] <= adj_count[edge_v[cycle_count]] + 4'd1;
            end
        end
    end

    // Angle Calculation Logic (simplified atan2)
    // This is a placeholder for fixed-point trigonometry
    always @(posedge clk) begin
        if (state == CALC_ANGLE) begin
            // Compute angle between v1 and v2
            // v1: prev -> curr
            // v2: curr -> next
            
            // Calculate dot product: v1 . v2
            // v1_x, v1_y already set in CALC_ANGLE state
            // Need v2 (next node is temp_node from FIND_NEXT)
            
            // This is a simplified approximation
            // Real implementation needs CORDIC or large LUTs
            
            // Default to 0 for now
            angle_angle <= 16'd0;
            
            // If we have previous node and current node
            if (path_len >= 1) begin
                // Very simple angle penalty (just distance for now)
                // angle_angle <= (path_len * 100); // Placeholder
            end
        end
    end

endmodule