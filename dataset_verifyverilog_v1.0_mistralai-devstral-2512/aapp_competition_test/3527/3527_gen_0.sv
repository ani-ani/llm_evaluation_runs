module min_max_hop_count(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_computers,
    input wire [3:0] num_cables,
    input wire [31:0] cable_a,
    input wire [31:0] cable_b,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] CALC = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Adjacency matrix (16x16 packed into 8x32-bit registers)
    reg [31:0] adj_matrix [0:7];

    // BFS variables
    reg [3:0] current_node;
    reg [3:0] bfs_queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] distance [0:15];
    reg [3:0] max_distance;

    // Component tracking
    reg [3:0] component_id [0:15];
    reg [3:0] current_component;
    reg [3:0] num_components;

    // Diameter and center tracking
    reg [3:0] component_diameter [0:15];
    reg [3:0] component_center [0:15];

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 32'd0;
            end

            // Initialize BFS variables
            current_node <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            max_distance <= 4'd0;

            // Initialize component tracking
            current_component <= 4'd0;
            num_components <= 4'd0;

            // Initialize distance and component arrays
            for (i = 0; i < 16; i = i + 1) begin
                distance[i] <= 4'd0;
                component_id[i] <= 4'd0;
                component_diameter[i] <= 4'd0;
                component_center[i] <= 4'd0;
            end

            // Initialize queue
            for (i = 0; i < 16; i = i + 1) begin
                bfs_queue[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load configuration
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        adj_matrix[i] <= 32'd0;
                    end

                    // Parse cables
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_cables) begin
                            reg [3:0] a, b;
                            a = cable_a[(i*4)+:4];
                            b = cable_b[(i*4)+:4];
                            if (a < b) begin
                                adj_matrix[a/4] <= adj_matrix[a/4] | (1 << (a%4 + ((b%4)*4)));
                                adj_matrix[b/4] <= adj_matrix[b/4] | (1 << (b%4 + ((a%4)*4)));
                            end
                        end
                    end

                    // Initialize component IDs
                    for (i = 0; i < 16; i = i + 1) begin
                        component_id[i] <= 4'd0;
                    end

                    current_component <= 4'd1;
                    num_components <= 4'd0;
                    next_state <= BFS;
                end

                BFS: begin
                    // Find unvisited node
                    integer i;
                    reg found;
                    found = 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (component_id[i] == 4'd0 && num_computers > i) begin
                            current_node <= i;
                            found = 1'b1;
                            break;
                        end
                    end

                    if (found) begin
                        // Initialize BFS
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                        bfs_queue[0] <= current_node;
                        distance[current_node] <= 4'd0;
                        component_id[current_node] <= current_component;
                        max_distance <= 4'd0;
                        next_state <= BFS;
                    end else begin
                        // All components processed
                        next_state <= CALC;
                    end
                end

                CALC: begin
                    // Calculate diameter and center for current component
                    integer i, j;
                    reg [3:0] min_max_dist, center_node;
                    min_max_dist = 4'd16;
                    center_node = 4'd0;

                    // Find node with minimal max distance
                    for (i = 0; i < 16; i = i + 1) begin
                        if (component_id[i] == current_component) begin
                            reg [3:0] max_dist;
                            max_dist = 4'd0;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (component_id[j] == current_component && i != j) begin
                                    // Simple distance calculation (BFS would be better)
                                    reg [3:0] dist;
                                    dist = 4'd1;
                                    if (adj_matrix[i/4][i%4 + ((j%4)*4)] || adj_matrix[j/4][j%4 + ((i%4)*4)]) begin
                                        dist = 4'd1;
                                    end else begin
                                        dist = 4'd2; // Approximation
                                    end
                                    if (dist > max_dist) begin
                                        max_dist = dist;
                                    end
                                end
                            end
                            if (max_dist < min_max_dist) begin
                                min_max_dist = max_dist;
                                center_node = i;
                            end
                        end
                    end

                    component_diameter[current_component] <= min_max_dist;
                    component_center[current_component] <= center_node;
                    num_components <= num_components + 4'd1;
                    current_component <= current_component + 4'd1;
                    next_state <= BFS;
                end

                DONE_STATE: begin
                    // Calculate final result
                    reg [3:0] max_diameter, star_diameter;
                    integer i;
                    max_diameter = 4'd0;
                    for (i = 1; i <= num_components; i = i + 1) begin
                        if (component_diameter[i] > max_diameter) begin
                            max_diameter = component_diameter[i];
                        end
                    end

                    // Star diameter calculation
                    if (num_components > 1) begin
                        star_diameter = 4'd1 + (num_components[3:1] + (num_components[0] ? 1 : 0));
                    end else begin
                        star_diameter = 4'd0;
                    end

                    if (max_diameter > star_diameter) begin
                        result <= max_diameter;
                    end else begin
                        result <= star_diameter;
                    end

                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            end else begin
                cycle_count <= 8'd0;
            end
        end
    end

    // BFS processing (simplified for synthesis)
    always @(posedge clk) begin
        if (state == BFS && queue_head != queue_tail) begin
            reg [3:0] node;
            node = bfs_queue[queue_head];
            queue_head <= queue_head + 4'd1;

            // Visit neighbors
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                if (adj_matrix[node/4][node%4 + ((i%4)*4)] && component_id[i] == 4'd0) begin
                    component_id[i] <= current_component;
                    distance[i] <= distance[node] + 4'd1;
                    if (distance[i] > max_distance) begin
                        max_distance <= distance[i];
                    end
                    bfs_queue[queue_tail] <= i;
                    queue_tail <= queue_tail + 4'd1;
                end
            end
        end
    end

endmodule