module river_crossing(
    input clk,
    input rst_n,
    input start,
    input [15:0] edges_valid,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BFS_INIT = 3'd1;
    localparam [2:0] BFS_RUN = 3'd2;
    localparam [2:0] UPDATE_EDGES = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [3:0] person_count;  // 0-3 for 4 people
    reg [3:0] left_behind;
    reg [15:0] total_time;
    
    // BFS state
    reg [3:0] current_node;
    reg [3:0] target_node;
    reg [3:0] queue [0:15];  // Max 15 hops
    reg [3:0] queue_ptr;
    reg [3:0] queue_size;
    reg [3:0] distance [0:9];  // Distance to each node
    reg [3:0] parent [0:9];    // Parent node in BFS tree
    reg [3:0] path_length;
    reg path_found;
    
    // Internal edge valid tracking
    reg [15:0] internal_edges_valid;
    
    // Cycle counter for timeout
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd4000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            person_count <= 4'd0;
            left_behind <= 4'd0;
            total_time <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;
            
            // Initialize BFS state
            current_node <= 4'd0;
            target_node <= 4'd0;
            queue_ptr <= 4'd0;
            queue_size <= 4'd0;
            path_length <= 4'd0;
            path_found <= 1'b0;
            
            // Initialize internal edges
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                internal_edges_valid[i] <= edges_valid[i];
            end
            
            // Initialize distances
            for (i = 0; i < 10; i = i + 1) begin
                distance[i] <= 4'd16;  // Max distance
                parent[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    if (start) begin
                        state <= BFS_INIT;
                        person_count <= 4'd0;
                        left_behind <= 4'd0;
                        total_time <= 16'd0;
                        
                        // Reset internal edges
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            internal_edges_valid[i] <= edges_valid[i];
                        end
                    end
                end
                
                BFS_INIT: begin
                    // Initialize BFS for current person
                    queue_size <= 4'd0;
                    queue_ptr <= 4'd0;
                    
                    // Reset distances
                    integer i;
                    for (i = 0; i < 10; i = i + 1) begin
                        distance[i] <= 4'd16;
                        parent[i] <= 4'd0;
                    end
                    
                    // Start from left bank (node 8)
                    distance[8] <= 4'd0;
                    queue[queue_size] <= 8;
                    queue_size <= queue_size + 4'd1;
                    
                    target_node <= 9;  // Right bank
                    path_found <= 1'b0;
                    path_length <= 4'd0;
                    
                    state <= BFS_RUN;
                end
                
                BFS_RUN: begin
                    if (queue_size > queue_ptr) begin
                        current_node <= queue[queue_ptr];
                        queue_ptr <= queue_ptr + 4'd1;
                        
                        // Check if we reached target
                        if (current_node == target_node) begin
                            path_found <= 1'b1;
                            state <= UPDATE_EDGES;
                        end else begin
                            // Explore neighbors
                            integer i;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (internal_edges_valid[i]) begin
                                    reg [3:0] u, v;
                                    u = edge_u[i];
                                    v = edge_v[i];
                                    
                                    if (u == current_node) begin
                                        if (distance[v] == 4'd16) begin
                                            distance[v] <= distance[current_node] + 4'd1;
                                            parent[v] <= current_node;
                                            queue[queue_size] <= v;
                                            queue_size <= queue_size + 4'd1;
                                        end
                                    end else if (v == current_node) begin
                                        if (distance[u] == 4'd16) begin
                                            distance[u] <= distance[current_node] + 4'd1;
                                            parent[u] <= current_node;
                                            queue[queue_size] <= u;
                                            queue_size <= queue_size + 4'd1;
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        // Queue empty, no path found
                        path_found <= 1'b0;
                        state <= UPDATE_EDGES;
                    end
                    
                    cycle_count <= cycle_count + 13'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                UPDATE_EDGES: begin
                    if (path_found) begin
                        // Trace back path and mark edges as used
                        reg [3:0] node;
                        node <= target_node;
                        
                        while (node != 8) begin
                            reg [3:0] p;
                            p = parent[node];
                            
                            // Find the edge between p and node
                            integer i;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (internal_edges_valid[i]) begin
                                    reg [3:0] u, v;
                                    u = edge_u[i];
                                    v = edge_v[i];
                                    
                                    if ((u == p && v == node) || (u == node && v == p)) begin
                                        internal_edges_valid[i] <= 1'b0;
                                    end
                                end
                            end
                            
                            node <= p;
                        end
                        
                        // Add path length to total time
                        total_time <= total_time + distance[target_node];
                    end else begin
                        // No path found, increment left_behind
                        left_behind <= left_behind + 4'd1;
                    end
                    
                    // Move to next person or finish
                    person_count <= person_count + 4'd1;
                    if (person_count == 4'd4) begin
                        state <= FINISH;
                    end else begin
                        state <= BFS_INIT;
                    end
                end
                
                FINISH: begin
                    if (left_behind == 4'd0) begin
                        result <= total_time;
                    end else begin
                        result <= {1'b1, 4'd0, left_behind};
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule