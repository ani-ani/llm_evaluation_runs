module TreeDiameterOptimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] adj_matrix [0:7],
    input [3:0] n_nodes,
    output reg [4:0] result_distance,
    output reg [3:0] edge_close_u,
    output reg [3:0] edge_close_v,
    output reg [3:0] edge_open_u,
    output reg [3:0] edge_open_v,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_DIST = 3'd1;
    localparam [2:0] FIND_DIAMETER = 3'd2;
    localparam [2:0] TRACE_PATH = 3'd3;
    localparam [2:0] FIND_COMPONENTS = 3'd4;
    localparam [2:0] FIND_NEW_EDGE = 3'd5;
    localparam [2:0] COMPUTE_NEW_DIAMETER = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Distance matrix (8x8, 5-bit values)
    reg [4:0] dist [0:7];
    integer i, j, k;

    // Diameter tracking
    reg [4:0] max_dist;
    reg [3:0] u_max, v_max;

    // Path tracing
    reg [3:0] path [0:7];
    reg [3:0] path_len;

    // Edge to remove
    reg [3:0] remove_u, remove_v;

    // Component tracking
    reg [3:0] component [0:7];
    reg [3:0] comp_count;

    // New edge candidates
    reg [3:0] new_u, new_v;
    reg [4:0] min_dist;

    // New diameter computation
    reg [4:0] new_diameter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_distance <= 5'd0;
            edge_close_u <= 4'd0;
            edge_close_v <= 4'd0;
            edge_open_u <= 4'd0;
            edge_open_v <= 4'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;

            // Initialize distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= 5'd0;
                end
            end

            max_dist <= 5'd0;
            u_max <= 4'd0;
            v_max <= 4'd0;
            path_len <= 4'd0;
            remove_u <= 4'd0;
            remove_v <= 4'd0;
            comp_count <= 4'd0;
            new_u <= 4'd0;
            new_v <= 4'd0;
            min_dist <= 5'd0;
            new_diameter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= COMPUTE_DIST;
                    end
                end

                COMPUTE_DIST: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Initialize distance matrix
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i == j) begin
                                dist[i][j] <= 5'd0;
                            end else if (adj_matrix[i][j]) begin
                                dist[i][j] <= 5'd1;
                            end else begin
                                dist[i][j] <= 5'd16; // Infinity
                            end
                        end
                    end

                    // Floyd-Warshall algorithm
                    for (k = 0; k < 8; k = k + 1) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                            end
                        end
                    end

                    state <= FIND_DIAMETER;
                end

                FIND_DIAMETER: begin
                    cycle_count <= cycle_count + 10'd1;

                    max_dist <= 5'd0;
                    u_max <= 4'd0;
                    v_max <= 4'd0;

                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = i + 1; j < 8; j = j + 1) begin
                            if (dist[i][j] > max_dist) begin
                                max_dist <= dist[i][j];
                                u_max <= i;
                                v_max <= j;
                            end
                        end
                    end

                    state <= TRACE_PATH;
                end

                TRACE_PATH: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Trace path from u_max to v_max
                    path_len <= 4'd0;
                    path[0] <= u_max;

                    reg [3:0] current;
                    reg [3:0] next_node;
                    reg [4:0] min_dist_temp;

                    current <= u_max;
                    for (i = 1; i < 8; i = i + 1) begin
                        min_dist_temp <= 5'd16;
                        next_node <= 4'd0;

                        for (j = 0; j < 8; j = j + 1) begin
                            if (adj_matrix[current][j] && dist[j][v_max] < min_dist_temp) begin
                                min_dist_temp <= dist[j][v_max];
                                next_node <= j;
                            end
                        end

                        if (next_node == 4'd0 || min_dist_temp == 5'd16) begin
                            break;
                        end

                        path[i] <= next_node;
                        path_len <= path_len + 4'd1;
                        current <= next_node;

                        if (current == v_max) begin
                            break;
                        end
                    end

                    // Find the edge to remove (longest edge on path)
                    remove_u <= path[0];
                    remove_v <= path[1];

                    for (i = 1; i < path_len; i = i + 1) begin
                        if (dist[path[i]][path[i+1]] > dist[remove_u][remove_v]) begin
                            remove_u <= path[i];
                            remove_v <= path[i+1];
                        end
                    end

                    state <= FIND_COMPONENTS;
                end

                FIND_COMPONENTS: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Mark components after removing edge
                    reg [3:0] visited [0:7];
                    reg [3:0] stack [0:7];
                    reg [3:0] stack_ptr;
                    reg [3:0] current_comp;

                    // Initialize
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 4'd0;
                        component[i] <= 4'd0;
                    end

                    current_comp <= 4'd1;

                    // BFS/DFS to mark components
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!visited[i]) begin
                            stack_ptr <= 4'd0;
                            stack[stack_ptr] <= i;
                            visited[i] <= 4'd1;
                            component[i] <= current_comp;

                            while (stack_ptr >= 0) begin
                                reg [3:0] node;
                                node <= stack[stack_ptr];
                                stack_ptr <= stack_ptr - 4'd1;

                                for (j = 0; j < 8; j = j + 1) begin
                                    if (adj_matrix[node][j] && 
                                        !(node == remove_u && j == remove_v) &&
                                        !(node == remove_v && j == remove_u) &&
                                        !visited[j]) begin
                                        visited[j] <= 4'd1;
                                        component[j] <= current_comp;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        stack[stack_ptr] <= j;
                                    end
                                end
                            end

                            current_comp <= current_comp + 4'd1;
                        end
                    end

                    comp_count <= current_comp - 4'd1;
                    state <= FIND_NEW_EDGE;
                end

                FIND_NEW_EDGE: begin
                    cycle_count <= cycle_count + 10'd1;

                    min_dist <= 5'd16;
                    new_u <= 4'd0;
                    new_v <= 4'd0;

                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (component[i] != component[j] && 
                                dist[i][j] < min_dist) begin
                                min_dist <= dist[i][j];
                                new_u <= i;
                                new_v <= j;
                            end
                        end
                    end

                    state <= COMPUTE_NEW_DIAMETER;
                end

                COMPUTE_NEW_DIAMETER: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Compute new diameter
                    reg [4:0] max_dist_comp1;
                    reg [4:0] max_dist_comp2;

                    max_dist_comp1 <= 5'd0;
                    max_dist_comp2 <= 5'd0;

                    // Find max distance within each component
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = i + 1; j < 8; j = j + 1) begin
                            if (component[i] == component[j]) begin
                                if (dist[i][j] > max_dist_comp1 && component[i] == 4'd1) begin
                                    max_dist_comp1 <= dist[i][j];
                                end
                                if (dist[i][j] > max_dist_comp2 && component[i] == 4'd2) begin
                                    max_dist_comp2 <= dist[i][j];
                                end
                            end
                        end
                    end

                    // New diameter is max of (max_dist_comp1, max_dist_comp2, min_dist + 1)
                    new_diameter <= max_dist_comp1;
                    if (max_dist_comp2 > new_diameter) begin
                        new_diameter <= max_dist_comp2;
                    end
                    if (min_dist + 5'd1 > new_diameter) begin
                        new_diameter <= min_dist + 5'd1;
                    end

                    state <= FINISH;
                end

                FINISH: begin
                    result_distance <= new_diameter;
                    edge_close_u <= remove_u;
                    edge_close_v <= remove_v;
                    edge_open_u <= new_u;
                    edge_open_v <= new_v;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule