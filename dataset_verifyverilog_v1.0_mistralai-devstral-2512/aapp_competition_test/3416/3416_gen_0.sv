module AirportSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] m,
    input wire [3:0] edge_a,
    input wire [3:0] edge_b,
    input wire edge_valid,
    input wire edge_done,
    output reg [4:0] min_flights,
    output reg [4:0] airport_count,
    output reg [15:0] airport_list,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_EDGES = 3'd1;
    localparam [2:0] COMPUTE_DEGREES = 3'd2;
    localparam [2:0] FIND_COMPONENTS = 3'd3;
    localparam [2:0] COMPUTE_RESULTS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Edge storage
    reg [3:0] edge_index;
    reg [3:0] edge_a_reg [0:31];
    reg [3:0] edge_b_reg [0:31];

    // Adjacency matrix (16x16)
    reg [15:0] adj_matrix [0:15];

    // Degree counters
    reg [3:0] indegree [0:15];
    reg [3:0] outdegree [0:15];

    // Component tracking
    reg [3:0] component_id [0:15];
    reg [3:0] current_component;
    reg [3:0] node_index;
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;

    // Temporary registers
    reg [3:0] i, j, k;
    reg [3:0] temp_node;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            edge_index <= 4'd0;
            min_flights <= 5'd0;
            airport_count <= 5'd0;
            airport_list <= 16'd0;
            done <= 1'b0;

            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] <= 16'd0;
            end

            // Initialize degree counters
            for (i = 0; i < 16; i = i + 1) begin
                indegree[i] <= 4'd0;
                outdegree[i] <= 4'd0;
            end

            // Initialize component tracking
            for (i = 0; i < 16; i = i + 1) begin
                component_id[i] <= 4'd0;
            end
            current_component <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;

        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= STORE_EDGES;
                        edge_index <= 4'd0;
                    end
                end

                STORE_EDGES: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (edge_valid && edge_index < m) begin
                        edge_a_reg[edge_index] <= edge_a;
                        edge_b_reg[edge_index] <= edge_b;
                        edge_index <= edge_index + 4'd1;
                    end
                    if (edge_done) begin
                        state <= COMPUTE_DEGREES;
                    end
                end

                COMPUTE_DEGREES: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize degrees
                    for (i = 0; i < 16; i = i + 1) begin
                        indegree[i] <= 4'd0;
                        outdegree[i] <= 4'd0;
                    end

                    // Compute degrees from stored edges
                    for (i = 0; i < m; i = i + 1) begin
                        temp_node <= edge_a_reg[i];
                        outdegree[temp_node] <= outdegree[temp_node] + 4'd1;
                        temp_node <= edge_b_reg[i];
                        indegree[temp_node] <= indegree[temp_node] + 4'd1;
                        // Update adjacency matrix
                        temp_node <= edge_a_reg[i];
                        adj_matrix[temp_node][edge_b_reg[i]] <= 1'b1;
                    end
                    state <= FIND_COMPONENTS;
                end

                FIND_COMPONENTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize component IDs
                    for (i = 0; i < 16; i = i + 1) begin
                        component_id[i] <= 4'd0;
                    end
                    current_component <= 4'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;

                    // Find all connected components (undirected)
                    for (i = 0; i < n; i = i + 1) begin
                        if (component_id[i] == 4'd0) begin
                            current_component <= current_component + 4'd1;
                            component_id[i] <= current_component;
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 4'd1;

                            while (queue_head < queue_tail) begin
                                temp_node <= queue[queue_head];
                                queue_head <= queue_head + 4'd1;

                                // Check all nodes for undirected connection
                                for (j = 0; j < n; j = j + 1) begin
                                    if (i != j && component_id[j] == 4'd0) begin
                                        // Check if connected in either direction
                                        if (adj_matrix[temp_node][j] || adj_matrix[j][temp_node]) begin
                                            component_id[j] <= current_component;
                                            queue[queue_tail] <= j;
                                            queue_tail <= queue_tail + 4'd1;
                                        end
                                    end
                                end
                            end
                            queue_head <= 4'd0;
                            queue_tail <= 4'd0;
                        end
                    end
                    state <= COMPUTE_RESULTS;
                end

                COMPUTE_RESULTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Count number of components
                    reg [3:0] num_components;
                    reg [3:0] max_component;
                    num_components <= 4'd0;
                    max_component <= 4'd0;

                    for (i = 0; i < 16; i = i + 1) begin
                        if (component_id[i] > max_component) begin
                            max_component <= component_id[i];
                        end
                    end
                    num_components <= max_component;

                    // Compute min_flights = num_components - 1
                    min_flights <= num_components - 5'd1;

                    // Compute airport_list
                    airport_list <= 16'd0;
                    airport_count <= 5'd0;

                    if (min_flights == 5'd0) begin
                        // All nodes are included
                        for (i = 0; i < n; i = i + 1) begin
                            airport_list[i] <= 1'b1;
                        end
                        airport_count <= n;
                    end else begin
                        // Only nodes with degree > 0
                        for (i = 0; i < n; i = i + 1) begin
                            if (indegree[i] + outdegree[i] > 4'd0) begin
                                airport_list[i] <= 1'b1;
                                airport_count <= airport_count + 5'd1;
                            end
                        end
                    end
                    state <= FINISH;
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