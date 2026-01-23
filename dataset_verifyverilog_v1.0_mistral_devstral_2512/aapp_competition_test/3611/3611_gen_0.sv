module ShortestPathNodes(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_FORWARD = 3'd1;
    localparam [2:0] RELAX_FORWARD = 3'd2;
    localparam [2:0] INIT_BACKWARD = 3'd3;
    localparam [2:0] RELAX_BACKWARD = 3'd4;
    localparam [2:0] CHECK_NODES = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Constants
    localparam [31:0] INF = 32'hFFFF_FFFF;
    localparam [4:0] MAX_ITER = 5'd7;

    // State and control registers
    reg [2:0] state;
    reg [4:0] iter_count;
    reg [4:0] edge_index;
    reg [4:0] node_index;

    // Forward Bellman-Ford registers
    reg [31:0] dist_s [0:7];
    reg [31:0] num_paths_s [0:7];

    // Backward Bellman-Ford registers
    reg [31:0] dist_t [0:7];
    reg [31:0] num_paths_t [0:7];

    // Temporary registers for computation
    reg [31:0] temp_dist;
    reg [31:0] temp_paths;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter_count <= 5'd0;
            edge_index <= 5'd0;
            node_index <= 5'd0;
            done <= 1'b0;
            mask <= 8'd0;

            // Initialize forward arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                dist_s[i] <= INF;
                num_paths_s[i] <= 32'd0;
            end

            // Initialize backward arrays
            for (i = 0; i < 8; i = i + 1) begin
                dist_t[i] <= INF;
                num_paths_t[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_FORWARD;
                    end
                end

                INIT_FORWARD: begin
                    // Initialize source node
                    dist_s[s] <= 32'd0;
                    num_paths_s[s] <= 32'd1;
                    iter_count <= 5'd0;
                    state <= RELAX_FORWARD;
                end

                RELAX_FORWARD: begin
                    // Process one edge per cycle
                    if (edge_index < num_edges) begin
                        // Relax edge
                        temp_dist = dist_s[u[edge_index]] + w[edge_index];
                        if (temp_dist < dist_s[v[edge_index]]) begin
                            dist_s[v[edge_index]] <= temp_dist;
                            num_paths_s[v[edge_index]] <= num_paths_s[u[edge_index]];
                        end else if (temp_dist == dist_s[v[edge_index]]) begin
                            num_paths_s[v[edge_index]] <= num_paths_s[v[edge_index]] + num_paths_s[u[edge_index]];
                        end
                        edge_index <= edge_index + 5'd1;
                    end else begin
                        edge_index <= 5'd0;
                        if (iter_count < MAX_ITER) begin
                            iter_count <= iter_count + 5'd1;
                        end else begin
                            state <= INIT_BACKWARD;
                        end
                    end
                end

                INIT_BACKWARD: begin
                    // Initialize target node for backward pass
                    dist_t[t] <= 32'd0;
                    num_paths_t[t] <= 32'd1;
                    iter_count <= 5'd0;
                    state <= RELAX_BACKWARD;
                end

                RELAX_BACKWARD: begin
                    // Process one edge per cycle (reversed)
                    if (edge_index < num_edges) begin
                        // Relax edge in reverse direction
                        temp_dist = dist_t[v[edge_index]] + w[edge_index];
                        if (temp_dist < dist_t[u[edge_index]]) begin
                            dist_t[u[edge_index]] <= temp_dist;
                            num_paths_t[u[edge_index]] <= num_paths_t[v[edge_index]];
                        end else if (temp_dist == dist_t[u[edge_index]]) begin
                            num_paths_t[u[edge_index]] <= num_paths_t[u[edge_index]] + num_paths_t[v[edge_index]];
                        end
                        edge_index <= edge_index + 5'd1;
                    end else begin
                        edge_index <= 5'd0;
                        if (iter_count < MAX_ITER) begin
                            iter_count <= iter_count + 5'd1;
                        end else begin
                            state <= CHECK_NODES;
                            node_index <= 5'd0;
                        end
                    end
                end

                CHECK_NODES: begin
                    // Check if current node is on all shortest paths
                    if (node_index < 8) begin
                        if (dist_s[node_index] != INF && 
                            dist_t[node_index] != INF &&
                            dist_s[node_index] + dist_t[node_index] == dist_s[t] &&
                            num_paths_s[node_index] * num_paths_t[node_index] == num_paths_s[t]) begin
                            mask[node_index] <= 1'b1;
                        end else begin
                            mask[node_index] <= 1'b0;
                        end
                        node_index <= node_index + 5'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule