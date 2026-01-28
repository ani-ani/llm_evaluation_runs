module graph_shortest_path (
    input clk,
    input rst_n,
    input start,
    input [2:0] s,
    input [2:0] t,
    input [4:0] num_edges,
    input [2:0] u [0:15],
    input [2:0] v [0:15],
    input [15:0] w [0:15],
    output reg [7:0] mask,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] INIT_FORWARD    = 4'd1;
    localparam [3:0] RELAX_FORWARD   = 4'd2;
    localparam [3:0] CHECK_ITER_FWD  = 4'd3;
    localparam [3:0] INIT_BACKWARD   = 4'd4;
    localparam [3:0] RELAX_BACKWARD  = 4'd5;
    localparam [3:0] CHECK_ITER_BWD  = 4'd6;
    localparam [3:0] CHECK_NODES     = 4'd7;
    localparam [3:0] DONE            = 4'd8;

    // Internal signals and registers
    reg [3:0] state, next_state;
    reg [2:0] iter_counter, next_iter_counter;
    reg [4:0] edge_counter, next_edge_counter;
    reg [2:0] node_counter, next_node_counter;
    reg [2:0] curr_s, curr_t;
    
    // Distance and path count arrays (unpacked)
    reg [31:0] dist_s [0:7];
    reg [31:0] num_paths_s [0:7];
    reg [31:0] dist_t [0:7];
    reg [31:0] num_paths_t [0:7];
    
    // Intermediate values for relaxation
    reg [31:0] new_dist;
    reg [31:0] new_paths;
    
    // Flags
    reg [7:0] temp_mask;
    
    // Constants
    localparam [31:0] INF = 32'hFFFF_FFFF;
    localparam [31:0] MAX_ITER = 3'd7;
    
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:           next_state = start ? INIT_FORWARD : IDLE;
            INIT_FORWARD:   next_state = RELAX_FORWARD;
            RELAX_FORWARD:  next_state = (edge_counter >= num_edges) ? CHECK_ITER_FWD : RELAX_FORWARD;
            CHECK_ITER_FWD: next_state = (iter_counter >= MAX_ITER) ? INIT_BACKWARD : INIT_FORWARD;
            INIT_BACKWARD:  next_state = RELAX_BACKWARD;
            RELAX_BACKWARD: next_state = (edge_counter >= num_edges) ? CHECK_ITER_BWD : RELAX_BACKWARD;
            CHECK_ITER_BWD: next_state = (iter_counter >= MAX_ITER) ? CHECK_NODES : INIT_BACKWARD;
            CHECK_NODES:    next_state = (node_counter >= 8'd7) ? DONE : CHECK_NODES;
            DONE:           next_state = IDLE;
            default:        next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter_counter <= 3'd0;
            edge_counter <= 5'd0;
            node_counter <= 3'd0;
            curr_s <= 3'd0;
            curr_t <= 3'd0;
            mask <= 8'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                dist_s[i] <= 32'd0;
                num_paths_s[i] <= 32'd0;
                dist_t[i] <= 32'd0;
                num_paths_t[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            iter_counter <= next_iter_counter;
            edge_counter <= next_edge_counter;
            node_counter <= next_node_counter;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        curr_s <= s;
                        curr_t <= t;
                    end
                end
                
                INIT_FORWARD: begin
                    // Initialize distances and path counts for forward Bellman-Ford
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == curr_s) begin
                            dist_s[i] <= 32'd0;
                            num_paths_s[i] <= 32'd1;
                        end else begin
                            dist_s[i] <= INF;
                            num_paths_s[i] <= 32'd0;
                        end
                    end
                    edge_counter <= 5'd0;
                end
                
                RELAX_FORWARD: begin
                    if (edge_counter < num_edges) begin
                        // Relax edge u[edge_counter] -> v[edge_counter] with weight w[edge_counter]
                        if (dist_s[u[edge_counter]] != INF) begin
                            new_dist <= dist_s[u[edge_counter]] + {16'd0, w[edge_counter]};
                            new_paths <= num_paths_s[u[edge_counter]];
                        end else begin
                            new_dist <= INF;
                            new_paths <= 32'd0;
                        end
                        edge_counter <= edge_counter + 5'd1;
                    end
                end
                
                // Update after delay of 1 cycle for edge processing
                // We need to combine this with RELAX_FORWARD logic
                // Actually, let's handle the update directly in RELAX_FORWARD
                // But we need to access edge data first. Let's restructure slightly.
                // To avoid combinational loops, we update based on current edge in next cycle
                // Let's move the comparison to RELAX_FORWARD itself
                
                INIT_BACKWARD: begin
                    // Initialize distances and path counts for backward Bellman-Ford
                    // Start from target t
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == curr_t) begin
                            dist_t[i] <= 32'd0;
                            num_paths_t[i] <= 32'd1;
                        end else begin
                            dist_t[i] <= INF;
                            num_paths_t[i] <= 32'd0;
                        end
                    end
                    edge_counter <= 5'd0;
                end
                
                RELAX_BACKWARD: begin
                    if (edge_counter < num_edges) begin
                        // In reverse graph, edge u -> v becomes v -> u
                        // We check dist_t[v] + weight vs dist_t[u]
                        if (dist_t[v[edge_counter]] != INF) begin
                            new_dist <= dist_t[v[edge_counter]] + {16'd0, w[edge_counter]};
                            new_paths <= num_paths_t[v[edge_counter]];
                        end else begin
                            new_dist <= INF;
                            new_paths <= 32'd0;
                        end
                        edge_counter <= edge_counter + 5'd1;
                    end
                end
                
                CHECK_NODES: begin
                    if (node_counter < 8'd8) begin
                        // Check if node lies on all shortest paths
                        if (dist_s[node_counter] != INF && dist_t[node_counter] != INF) begin
                            if ((dist_s[node_counter] + dist_t[node_counter] == dist_s[curr_t]) && 
                                (num_paths_s[node_counter] * num_paths_t[node_counter] == num_paths_s[curr_t])) begin
                                temp_mask[node_counter] <= 1'b1;
                            end else begin
                                temp_mask[node_counter] <= 1'b0;
                            end
                        end else begin
                            temp_mask[node_counter] <= 1'b0;
                        end
                        node_counter <= node_counter + 3'd1;
                    end
                end
                
                DONE: begin
                    mask <= temp_mask;
                    done <= 1'b1;
                end
            endcase
            
            // Handle immediate updates within RELAX states (combinational logic wrapped in sequential)
            // This part handles the actual relaxation update
            if (state == RELAX_FORWARD && edge_counter > 5'd0) begin
                // Update based on the edge processed in previous cycle
                // The edge index is edge_counter - 1
                if (new_dist < dist_s[u[edge_counter - 1]]) begin
                    dist_s[u[edge_counter - 1]] <= new_dist;
                    num_paths_s[u[edge_counter - 1]] <= new_paths;
                end else if (new_dist == dist_s[u[edge_counter - 1]]) begin
                    num_paths_s[u[edge_counter - 1]] <= num_paths_s[u[edge_counter - 1]] + new_paths;
                end
            end
            
            if (state == RELAX_BACKWARD && edge_counter > 5'd0) begin
                // Update based on the edge processed in previous cycle
                // Edge index is edge_counter - 1
                // Reverse graph: check update to u from v
                if (new_dist < dist_t[u[edge_counter - 1]]) begin
                    dist_t[u[edge_counter - 1]] <= new_dist;
                    num_paths_t[u[edge_counter - 1]] <= new_paths;
                end else if (new_dist == dist_t[u[edge_counter - 1]]) begin
                    num_paths_t[u[edge_counter - 1]] <= num_paths_t[u[edge_counter - 1]] + new_paths;
                end
            end
        end
    end
    
    // Counter updates
    always @(*) begin
        next_iter_counter = iter_counter;
        next_edge_counter = edge_counter;
        next_node_counter = node_counter;
        
        case (state)
            INIT_FORWARD: begin
                next_iter_counter = 3'd0;
            end
            CHECK_ITER_FWD: begin
                next_iter_counter = iter_counter + 3'd1;
            end
            INIT_BACKWARD: begin
                next_iter_counter = 3'd0;
            end
            CHECK_ITER_BWD: begin
                next_iter_counter = iter_counter + 3'd1;
            end
            CHECK_NODES: begin
                if (node_counter < 8'd8) begin
                    next_node_counter = node_counter + 3'd1;
                end
            end
            default: begin
                next_iter_counter = iter_counter;
                next_edge_counter = edge_counter;
                next_node_counter = node_counter;
            end
        endcase
    end

endmodule