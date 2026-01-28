module max_min_flow(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [3:0] edges_u [0:31],
    input wire [3:0] edges_v [0:31],
    input wire [7:0] edges_c [0:31],
    input wire [7:0] edges_w [0:31],
    input wire [4:0] num_edges,
    input wire [3:0] s,
    input wire [3:0] t,
    output reg [15:0] max_flow,
    output reg [31:0] min_cost,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS_PATH = 3'd2;
    localparam [2:0] AUGMENT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;

    // Residual graph matrices
    reg [7:0] residual_cap [0:15][0:15];
    reg [7:0] residual_cost [0:15][0:15];

    // BFS variables
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] parent [0:15];
    reg [7:0] min_cost_path [0:15];

    // Augmenting path variables
    reg [3:0] current_node;
    reg [7:0] path_flow;
    reg [7:0] path_cost;

    // Iteration control
    reg [7:0] iteration_count;
    localparam [7:0] MAX_ITERATIONS = 8'd256;

    // Temporary variables
    reg [3:0] i, j, k;
    reg [7:0] temp_cap, temp_cost;
    reg found_path;

    // Initialize residual graph
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            max_flow <= 16'd0;
            min_cost <= 32'd0;
            done <= 1'b0;
            iteration_count <= 8'd0;

            // Initialize matrices
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    residual_cap[i][j] <= 8'd0;
                    residual_cost[i][j] <= 8'd0;
                end
            end

            // Initialize BFS variables
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
                min_cost_path[i] <= 8'd0;
            end

            found_path <= 1'b0;
            path_flow <= 8'd0;
            path_cost <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Build residual graph from input edges
                    for (i = 0; i < num_edges; i = i + 1) begin
                        residual_cap[edges_u[i]][edges_v[i]] <= edges_c[i];
                        residual_cost[edges_u[i]][edges_v[i]] <= edges_w[i];
                    end
                    next_state <= BFS_PATH;
                end

                BFS_PATH: begin
                    // BFS to find minimum cost path
                    // Initialize BFS
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= 4'd16; // Invalid
                        min_cost_path[i] <= 8'd255; // Max cost
                    end

                    // Start from source
                    queue[queue_tail] <= s;
                    queue_tail <= queue_tail + 4'd1;
                    parent[s] <= 4'd16; // Mark as visited
                    min_cost_path[s] <= 8'd0;

                    // BFS loop
                    while (queue_head != queue_tail && queue_head < 4'd16) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;

                        // Check all neighbors
                        for (j = 0; j < num_nodes; j = j + 1) begin
                            if (residual_cap[current_node][j] > 8'd0) begin
                                // Calculate new cost
                                temp_cost <= min_cost_path[current_node] + residual_cost[current_node][j];

                                // Update if better path found
                                if (min_cost_path[j] > temp_cost) begin
                                    min_cost_path[j] <= temp_cost;
                                    parent[j] <= current_node;

                                    // Add to queue
                                    queue[queue_tail] <= j;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end

                    // Check if path to sink exists
                    if (parent[t] != 4'd16) begin
                        found_path <= 1'b1;
                        next_state <= AUGMENT;
                    end else begin
                        found_path <= 1'b0;
                        next_state <= FINISH;
                    end
                end

                AUGMENT: begin
                    // Find minimum residual capacity along path
                    path_flow <= 8'd255;
                    path_cost <= 8'd0;
                    current_node <= t;

                    while (current_node != s) begin
                        j <= parent[current_node];
                        temp_cap <= residual_cap[j][current_node];
                        if (temp_cap < path_flow) begin
                            path_flow <= temp_cap;
                        end
                        path_cost <= path_cost + residual_cost[j][current_node];
                        current_node <= j;
                    end

                    // Update residual capacities
                    current_node <= t;
                    while (current_node != s) begin
                        j <= parent[current_node];
                        // Forward edge
                        residual_cap[j][current_node] <= residual_cap[j][current_node] - path_flow;
                        // Backward edge
                        residual_cap[current_node][j] <= residual_cap[current_node][j] + path_flow;
                        current_node <= j;
                    end

                    // Update total flow and cost
                    max_flow <= max_flow + path_flow;
                    min_cost <= min_cost + (path_flow * path_cost);

                    // Increment iteration count
                    iteration_count <= iteration_count + 8'd1;

                    // Check if we should continue
                    if (iteration_count >= MAX_ITERATIONS || !found_path) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= BFS_PATH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Clear done signal after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule