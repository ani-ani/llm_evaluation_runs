module MaxProtectedRooms (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [4:0] edges [0:31],
    input [4:0] valid_edges,
    output reg [3:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_INPUT = 4'd1;
    localparam [3:0] BUILD_ADJ = 4'd2;
    localparam [3:0] SETUP_EDGE = 4'd3;
    localparam [3:0] BFS_INIT = 4'd4;
    localparam [3:0] BFS_LOOP = 4'd5;
    localparam [3:0] COUNT_REACH = 4'd6;
    localparam [3:0] UPDATE_MAX = 4'd7;
    localparam [3:0] NEXT_EDGE = 4'd8;
    localparam [3:0] OUTPUT_RESULT = 4'd9;
    localparam [3:0] ERROR_STATE = 4'd10;

    // Internal signals
    reg [3:0] state, next_state;
    reg [3:0] result_reg, next_result;
    reg done_reg, next_done;
    reg error_reg, next_error;
    
    // Edge processing
    reg [4:0] edge_idx, next_edge_idx;
    reg [4:0] u, v, next_u, next_v;
    reg edge_removed, next_edge_removed;
    
    // Adjacency matrix (17x17 bits)
    reg adj [0:16][0:16];
    reg [3:0] i, j;
    
    // BFS variables
    reg visited [0:16];
    reg queue [0:16];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] node_idx, neighbor;
    reg [3:0] count, next_count;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count, next_cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Intermediate for reachability check
    reg is_reachable;
    reg [3:0] room_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 4'd0;
            done_reg <= 1'b0;
            error_reg <= 1'b0;
            edge_idx <= 5'd0;
            u <= 5'd0;
            v <= 5'd0;
            edge_removed <= 1'b0;
            count <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 17; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
            end
            
            // Initialize visited array
            for (i = 0; i < 17; i = i + 1) begin
                visited[i] <= 1'b0;
                queue[i] <= 1'b0;
            end
            
        end else begin
            state <= next_state;
            result_reg <= next_result;
            done_reg <= next_done;
            error_reg <= next_error;
            edge_idx <= next_edge_idx;
            u <= next_u;
            v <= next_v;
            edge_removed <= next_edge_removed;
            count <= next_count;
            cycle_count <= next_cycle_count;
        end
    end
    
    always @(*) begin
        // Default assignments
        next_state = state;
        next_result = result_reg;
        next_done = 1'b0;
        next_error = error_reg;
        next_edge_idx = edge_idx;
        next_u = u;
        next_v = v;
        next_edge_removed = edge_removed;
        next_count = count;
        next_cycle_count = cycle_count;
        
        is_reachable = 1'b0;
        
        case (state)
            IDLE: begin
                next_cycle_count = 8'd0;
                next_error = 1'b0;
                next_result = 4'd0;
                next_done = 1'b0;
                if (start) begin
                    next_state = CHECK_INPUT;
                end
            end
            
            CHECK_INPUT: begin
                if (N == 4'd0 || N > 4'd15 || valid_edges > 5'd31) begin
                    next_error = 1'b1;
                    next_state = ERROR_STATE;
                end else begin
                    next_error = 1'b0;
                    next_state = BUILD_ADJ;
                end
            end
            
            BUILD_ADJ: begin
                // Build adjacency matrix from edges
                for (i = 0; i < 17; i = i + 1) begin
                    for (j = 0; j < 17; j = j + 1) begin
                        adj[i][j] = 1'b0;
                    end
                end
                
                // Note: In synthesis, loop variables are constant
                // We'll build adjacency using sequential logic instead
                next_state = SETUP_EDGE;
                next_edge_idx = 5'd0;
                next_result = 4'd0;
            end
            
            SETUP_EDGE: begin
                if (edge_idx < valid_edges) begin
                    // Convert outside (-1) to internal 16
                    if (edges[edge_idx][9:5] == 5'h1F) begin
                        next_u = 5'd16;
                    end else begin
                        next_u = edges[edge_idx][9:5];
                    end
                    
                    if (edges[edge_idx][4:0] == 5'h1F) begin
                        next_v = 5'd16;
                    end else begin
                        next_v = edges[edge_idx][4:0];
                    end
                    
                    // Build adjacency in sequential manner
                    if (next_u <= 16 && next_v <= 16 && next_u != next_v) begin
                        adj[next_u][next_v] = 1'b1;
                        adj[next_v][next_u] = 1'b1;
                    end
                    
                    next_edge_idx = edge_idx + 5'd1;
                    next_state = SETUP_EDGE;
                end else begin
                    next_edge_idx = 5'd0;
                    next_state = SETUP_EDGE;
                end
                
                // Move to next stage after edges are processed
                if (edge_idx == 5'd31) begin
                    next_state = SETUP_EDGE;
                end
                
                if (edge_idx >= valid_edges && edge_idx != 5'd31) begin
                    next_state = SETUP_EDGE;
                end
                
                if (edge_idx >= 5'd31) begin
                    next_edge_idx = 5'd0;
                    next_state = NEXT_EDGE;
                end
            end
            
            NEXT_EDGE: begin
                if (edge_idx < valid_edges) begin
                    // Remove current edge
                    if (edges[edge_idx][9:5] == 5'h1F) begin
                        next_u = 5'd16;
                    end else begin
                        next_u = edges[edge_idx][9:5];
                    end
                    
                    if (edges[edge_idx][4:0] == 5'h1F) begin
                        next_v = 5'd16;
                    end else begin
                        next_v = edges[edge_idx][4:0];
                    end
                    
                    next_edge_removed = 1'b1;
                    next_state = BFS_INIT;
                end else begin
                    next_state = OUTPUT_RESULT;
                end
            end
            
            BFS_INIT: begin
                // Reset visited array
                for (i = 0; i < 17; i = i + 1) begin
                    visited[i] = 1'b0;
                    queue[i] = 1'b0;
                end
                
                // Initialize BFS from outside node 16
                visited[16] = 1'b1;
                queue[16] = 1'b1;
                next_u = 16;  // head
                next_v = 16;  // tail
                next_count = 4'd0;
                
                next_state = BFS_LOOP;
            end
            
            BFS_LOOP: begin
                // Find next node in queue
                if (next_u != next_v) begin
                    // Process node
                    for (node_idx = 0; node_idx < 17; node_idx = node_idx + 1) begin
                        if (node_idx == next_u) begin
                            // Check all neighbors
                            for (neighbor = 0; neighbor < 17; neighbor = neighbor + 1) begin
                                // Skip removed edge
                                if (edge_removed && 
                                    ((node_idx == u && neighbor == v) || 
                                     (node_idx == v && neighbor == u))) begin
                                    // Skip this connection
                                end else begin
                                    if (adj[node_idx][neighbor] && !visited[neighbor]) begin
                                        visited[neighbor] = 1'b1;
                                        queue[next_v] = 1'b1;
                                        next_v = next_v + 4'd1;
                                        if (next_v > 16) next_v = 4'd0;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Move to next node in queue
                    next_u = next_u + 4'd1;
                    if (next_u > 16) next_u = 4'd0;
                    
                end else begin
                    // BFS complete
                    next_state = COUNT_REACH;
                end
            end
            
            COUNT_REACH: begin
                // Count reachable rooms (0 to N-1)
                next_count = 4'd0;
                for (room_idx = 0; room_idx < 16; room_idx = room_idx + 1) begin
                    if (room_idx < N && visited[room_idx]) begin
                        next_count = next_count + 4'd1;
                    end
                end
                next_state = UPDATE_MAX;
            end
            
            UPDATE_MAX: begin
                if (next_count > result_reg) begin
                    next_result = next_count;
                end
                next_edge_removed = 1'b0;
                next_edge_idx = edge_idx + 5'd1;
                next_state = NEXT_EDGE;
            end
            
            OUTPUT_RESULT: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            ERROR_STATE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout check
        if (state != IDLE && state != OUTPUT_RESULT && state != ERROR_STATE) begin
            next_cycle_count = cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = ERROR_STATE;
                next_error = 1'b1;
            end
        end
    end
    
    // Assign outputs
    always @(posedge clk) begin
        result <= result_reg;
        done <= done_reg;
        error <= error_reg;
    end

endmodule