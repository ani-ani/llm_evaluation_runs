module RoomProtector(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] BFS = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Adjacency matrix (17x17 nodes: 0-15 rooms, 16=outside)
    reg [16:0] adj_matrix [0:16];
    
    // BFS variables
    reg [4:0] current_node;
    reg [4:0] queue [0:16];
    reg [3:0] queue_head, queue_tail;
    reg [16:0] visited;
    reg [3:0] reachable_count;
    
    // Processing variables
    reg [4:0] current_edge;
    reg [3:0] max_protected;
    reg [4:0] edge_u, edge_v;
    
    // Error checking
    reg invalid_input;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            current_edge <= 5'd0;
            max_protected <= 4'd0;
            edge_u <= 5'd0;
            edge_v <= 5'd0;
            current_node <= 5'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            reachable_count <= 4'd0;
            invalid_input <= 1'b0;
            
            // Clear adjacency matrix
            integer i, j;
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 17; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                end
            end
            
            // Clear visited and queue
            for (i = 0; i < 17; i = i + 1) begin
                visited[i] <= 1'b0;
                queue[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    // Check for invalid input
                    if (N == 4'd0) begin
                        invalid_input <= 1'b1;
                        error <= 1'b1;
                        state <= IDLE;
                    end else if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Build adjacency matrix
                    integer i;
                    for (i = 0; i < valid_edges; i = i + 1) begin
                        // Convert -1 to 16 (outside)
                        if (edges[i][4:0] == 5'd31) begin
                            edge_u = 5'd16;
                        end else begin
                            edge_u = edges[i][4:0];
                        end
                        
                        if (edges[i][9:5] == 5'd31) begin
                            edge_v = 5'd16;
                        end else begin
                            edge_v = edges[i][9:5];
                        end
                        
                        // Set both directions
                        adj_matrix[edge_u][edge_v] <= 1'b1;
                        adj_matrix[edge_v][edge_u] <= 1'b1;
                    end
                    
                    // Initialize processing
                    current_edge <= 5'd0;
                    max_protected <= 4'd0;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all edges
                    if (current_edge >= valid_edges) begin
                        state <= FINISH;
                    end else begin
                        // Remove current edge
                        if (edges[current_edge][4:0] == 5'd31) begin
                            edge_u = 5'd16;
                        end else begin
                            edge_u = edges[current_edge][4:0];
                        end
                        
                        if (edges[current_edge][9:5] == 5'd31) begin
                            edge_v = 5'd16;
                        end else begin
                            edge_v = edges[current_edge][9:5];
                        end
                        
                        // Temporarily remove edge
                        adj_matrix[edge_u][edge_v] <= 1'b0;
                        adj_matrix[edge_v][edge_u] <= 1'b0;
                        
                        // Initialize BFS
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        reachable_count <= 4'd0;
                        
                        integer i;
                        for (i = 0; i < 17; i = i + 1) begin
                            visited[i] <= 1'b0;
                        end
                        
                        // Start BFS from outside (node 16)
                        queue[queue_tail] <= 5'd16;
                        queue_tail <= queue_tail + 4'd1;
                        visited[16] <= 1'b1;
                        
                        state <= BFS;
                    end
                end
                
                BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process queue
                    if (queue_head < queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        
                        // Count reachable rooms (0-15)
                        if (current_node < 5'd16) begin
                            reachable_count <= reachable_count + 4'd1;
                        end
                        
                        // Visit neighbors
                        integer i;
                        for (i = 0; i < 17; i = i + 1) begin
                            if (adj_matrix[current_node][i] && !visited[i]) begin
                                visited[i] <= 1'b1;
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                            end
                        end
                    end else begin
                        // BFS complete, update max_protected
                        // Protected rooms = total rooms - reachable rooms
                        if ((N - reachable_count) > max_protected) begin
                            max_protected <= N - reachable_count;
                        end
                        
                        // Restore edge
                        if (edges[current_edge][4:0] == 5'd31) begin
                            edge_u = 5'd16;
                        end else begin
                            edge_u = edges[current_edge][4:0];
                        end
                        
                        if (edges[current_edge][9:5] == 5'd31) begin
                            edge_v = 5'd16;
                        end else begin
                            edge_v = edges[current_edge][9:5];
                        end
                        
                        adj_matrix[edge_u][edge_v] <= 1'b1;
                        adj_matrix[edge_v][edge_u] <= 1'b1;
                        
                        // Move to next edge
                        current_edge <= current_edge + 5'd1;
                        state <= PROCESS;
                    end
                end
                
                FINISH: begin
                    result <= max_protected;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                error <= 1'b1;
            end
        end
    end
endmodule