module GraphOrientation(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [5:0] M,
    input [3:0] edge_u [0:27],
    input [3:0] edge_v [0:27],
    output reg result,
    output reg done,
    output reg [3:0] out_u [0:27],
    output reg [3:0] out_v [0:27]
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] DFS = 3'd2;
    localparam [2:0] ORIENT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Adjacency matrix (8x8)
    reg [7:0] adj [0:7];
    integer i, j;

    // DFS variables
    reg [3:0] current_node;
    reg [3:0] parent_node;
    reg [3:0] next_node;
    reg [15:0] discovery_time [0:7];
    reg [15:0] low [0:7];
    reg [15:0] time_counter;
    reg [4:0] stack_ptr;
    reg [3:0] stack_u [0:15];
    reg [3:0] stack_v [0:15];
    reg [3:0] visited [0:7];
    reg bridge_found;

    // BFS/DFS for spanning tree
    reg [3:0] tree_parent [0:7];
    reg [3:0] tree_edges [0:27];
    reg [5:0] tree_edge_count;

    // Orientation
    reg [3:0] temp_out_u [0:27];
    reg [3:0] temp_out_v [0:27];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                adj[i] <= 8'd0;
            end
            
            // Initialize DFS variables
            current_node <= 4'd0;
            parent_node <= 4'd0;
            next_node <= 4'd0;
            time_counter <= 16'd0;
            stack_ptr <= 5'd0;
            bridge_found <= 1'b0;
            
            for (i = 0; i < 8; i = i + 1) begin
                discovery_time[i] <= 16'd0;
                low[i] <= 16'd0;
                visited[i] <= 4'd0;
                tree_parent[i] <= 4'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                stack_u[i] <= 4'd0;
                stack_v[i] <= 4'd0;
            end
            
            tree_edge_count <= 6'd0;
            
            for (i = 0; i < 28; i = i + 1) begin
                out_u[i] <= 4'd0;
                out_v[i] <= 4'd0;
                temp_out_u[i] <= 4'd0;
                temp_out_v[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Build adjacency matrix
                    for (i = 0; i < 8; i = i + 1) begin
                        adj[i] <= 8'd0;
                    end
                    
                    for (i = 0; i < M; i = i + 1) begin
                        adj[edge_u[i] - 4'd1][edge_v[i] - 4'd1] <= 1'b1;
                        adj[edge_v[i] - 4'd1][edge_u[i] - 4'd1] <= 1'b1;
                    end
                    
                    // Initialize DFS variables
                    time_counter <= 16'd0;
                    stack_ptr <= 5'd0;
                    bridge_found <= 1'b0;
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        discovery_time[i] <= 16'd0;
                        low[i] <= 16'd0;
                        visited[i] <= 4'd0;
                        tree_parent[i] <= 4'd0;
                    end
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        stack_u[i] <= 4'd0;
                        stack_v[i] <= 4'd0;
                    end
                    
                    tree_edge_count <= 6'd0;
                    
                    for (i = 0; i < 28; i = i + 1) begin
                        temp_out_u[i] <= 4'd0;
                        temp_out_v[i] <= 4'd0;
                    end
                    
                    next_state <= DFS;
                end
                
                DFS: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Start DFS from node 0 (index 0 = node 1)
                    if (stack_ptr == 5'd0) begin
                        current_node <= 4'd0;
                        parent_node <= 4'd0;
                        next_node <= 4'd0;
                        
                        if (visited[current_node] == 4'd0) begin
                            visited[current_node] <= 4'd1;
                            discovery_time[current_node] <= time_counter;
                            low[current_node] <= time_counter;
                            time_counter <= time_counter + 16'd1;
                        end
                    end
                    
                    // Find next unvisited neighbor
                    reg found;
                    found = 1'b0;
                    for (i = next_node; i < 8; i = i + 1) begin
                        if (adj[current_node][i] && visited[i] == 4'd0) begin
                            found = 1'b1;
                            next_node <= i + 4'd1;
                            break;
                        end
                    end
                    
                    if (found) begin
                        // Push edge to stack
                        stack_u[stack_ptr] <= current_node + 4'd1;
                        stack_v[stack_ptr] <= next_node - 4'd1 + 4'd1;
                        stack_ptr <= stack_ptr + 5'd1;
                        
                        // Update parent
                        tree_parent[next_node - 4'd1] <= current_node + 4'd1;
                        
                        // Recurse
                        parent_node <= current_node;
                        current_node <= next_node - 4'd1;
                        next_node <= 4'd0;
                        
                        visited[current_node] <= 4'd1;
                        discovery_time[current_node] <= time_counter;
                        low[current_node] <= time_counter;
                        time_counter <= time_counter + 16'd1;
                    end else begin
                        // Backtrack
                        if (stack_ptr > 5'd0) begin
                            stack_ptr <= stack_ptr - 5'd1;
                            current_node <= stack_v[stack_ptr] - 4'd1;
                            parent_node <= stack_u[stack_ptr] - 4'd1;
                            next_node <= stack_v[stack_ptr] + 4'd1;
                            
                            // Update low value
                            if (low[stack_v[stack_ptr] - 4'd1] < low[current_node]) begin
                                low[current_node] <= low[stack_v[stack_ptr] - 4'd1];
                            end
                            
                            // Check for bridge
                            if (low[stack_v[stack_ptr] - 4'd1] > discovery_time[current_node]) begin
                                bridge_found <= 1'b1;
                            end
                        end else begin
                            // DFS complete
                            if (bridge_found) begin
                                result <= 1'b0;
                            end else begin
                                result <= 1'b1;
                            end
                            next_state <= ORIENT;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                ORIENT: begin
                    // Build spanning tree edges
                    tree_edge_count <= 6'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (tree_parent[i] != 4'd0) begin
                            tree_edges[tree_edge_count] <= i + 4'd1;
                            tree_edge_count <= tree_edge_count + 6'd1;
                        end
                    end
                    
                    // Orient edges
                    for (i = 0; i < M; i = i + 1) begin
                        reg is_tree_edge;
                        is_tree_edge = 1'b0;
                        
                        for (j = 0; j < tree_edge_count; j = j + 1) begin
                            if ((edge_u[i] == tree_parent[edge_v[i] - 4'd1] && edge_v[i] == tree_edges[j]) ||
                                (edge_v[i] == tree_parent[edge_u[i] - 4'd1] && edge_u[i] == tree_edges[j])) begin
                                is_tree_edge = 1'b1;
                                break;
                            end
                        end
                        
                        if (is_tree_edge) begin
                            // Tree edge: orient away from root
                            if (edge_u[i] == tree_parent[edge_v[i] - 4'd1]) begin
                                temp_out_u[i] <= edge_u[i];
                                temp_out_v[i] <= edge_v[i];
                            end else begin
                                temp_out_u[i] <= edge_v[i];
                                temp_out_v[i] <= edge_u[i];
                            end
                        end else begin
                            // Non-tree edge: orient from lower to higher
                            if (edge_u[i] < edge_v[i]) begin
                                temp_out_u[i] <= edge_u[i];
                                temp_out_v[i] <= edge_v[i];
                            end else begin
                                temp_out_u[i] <= edge_v[i];
                                temp_out_v[i] <= edge_u[i];
                            end
                        end
                    end
                    
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    
                    // Copy temp outputs to real outputs
                    for (i = 0; i < 28; i = i + 1) begin
                        out_u[i] <= temp_out_u[i];
                        out_v[i] <= temp_out_v[i];
                    end
                    
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule