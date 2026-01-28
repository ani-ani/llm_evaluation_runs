module PipeCleaner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] w,
    input wire [9:0] p,
    input wire signed [16:0] well_x [0:1023],
    input wire signed [16:0] well_y [0:1023],
    input wire [9:0] pipe_start [0:1023],
    input wire signed [16:0] pipe_end_x [0:1023],
    input wire signed [16:0] pipe_end_y [0:1023],
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] INTERSECT = 4'd2;
    localparam [3:0] GRAPH_BUILD = 4'd3;
    localparam [3:0] BIPARTITE = 4'd4;
    localparam [3:0] OUTPUT = 4'd5;

    reg [3:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd100000;

    // Intersection detection variables
    reg [9:0] i_reg, j_reg;
    reg [9:0] i_next, j_next;
    reg [9:0] i_max, j_max;
    reg [9:0] pipe_i_start, pipe_j_start;
    reg signed [16:0] pipe_i_x1, pipe_i_y1, pipe_i_x2, pipe_i_y2;
    reg signed [16:0] pipe_j_x1, pipe_j_y1, pipe_j_x2, pipe_j_y2;
    reg signed [32:0] cross1, cross2, cross3, cross4;
    reg signed [32:0] denom;
    reg signed [16:0] intersect_x, intersect_y;
    reg is_intersect;
    reg is_well_intersect;

    // Graph construction
    reg [9:0] node_i, node_j;
    reg [9:0] adj_matrix [0:1023];
    reg [9:0] adj_list_ptr [0:1023];
    reg [9:0] adj_list [0:1023*1023];
    reg [9:0] adj_list_size [0:1023];

    // Bipartite check
    reg [9:0] color [0:1023];
    reg [9:0] queue [0:1023];
    reg [9:0] queue_head, queue_tail;
    reg [9:0] current_node;
    reg [9:0] neighbor;
    reg [9:0] neighbor_ptr;
    reg [9:0] neighbor_count;
    reg [9:0] component_start;
    reg is_bipartite;

    // Control signals
    reg setup_done;
    reg intersect_done;
    reg graph_done;
    reg bipartite_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            result <= 1'b0;
            done <= 1'b0;
            setup_done <= 1'b0;
            intersect_done <= 1'b0;
            graph_done <= 1'b0;
            bipartite_done <= 1'b0;
            i_reg <= 10'd0;
            j_reg <= 10'd0;
            i_next <= 10'd0;
            j_next <= 10'd0;
            i_max <= 10'd0;
            j_max <= 10'd0;
            queue_head <= 10'd0;
            queue_tail <= 10'd0;
            component_start <= 10'd0;
            is_bipartite <= 1'b1;

            // Initialize color array
            integer k;
            for (k = 0; k < 1024; k = k + 1) begin
                color[k] <= 10'd0;
                adj_list_size[k] <= 10'd0;
                adj_list_ptr[k] <= 10'd0;
            end
        end else begin
            cycle_count <= cycle_count + 16'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= OUTPUT;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                        cycle_count <= 16'd0;
                    end
                end

                SETUP: begin
                    // Initialize adjacency matrix and lists
                    integer k;
                    for (k = 0; k < 1024; k = k + 1) begin
                        adj_matrix[k] <= 10'd0;
                        adj_list_size[k] <= 10'd0;
                        adj_list_ptr[k] <= 10'd0;
                    end

                    // Set up intersection detection counters
                    i_reg <= 10'd0;
                    j_reg <= 10'd0;
                    i_next <= 10'd0;
                    j_next <= 10'd1;
                    i_max <= p - 10'd1;
                    j_max <= p - 10'd1;

                    setup_done <= 1'b1;
                    state <= INTERSECT;
                end

                INTERSECT: begin
                    // Load pipe data
                    pipe_i_start <= pipe_start[i_reg];
                    pipe_j_start <= pipe_start[j_reg];
                    pipe_i_x1 <= well_x[pipe_i_start - 10'd1];
                    pipe_i_y1 <= well_y[pipe_i_start - 10'd1];
                    pipe_i_x2 <= pipe_end_x[i_reg];
                    pipe_i_y2 <= pipe_end_y[i_reg];
                    pipe_j_x1 <= well_x[pipe_j_start - 10'd1];
                    pipe_j_y1 <= well_y[pipe_j_start - 10'd1];
                    pipe_j_x2 <= pipe_end_x[j_reg];
                    pipe_j_y2 <= pipe_end_y[j_reg];

                    // Check if pipes intersect
                    is_intersect <= 1'b0;
                    is_well_intersect <= 1'b0;

                    // Calculate cross products for orientation
                    cross1 <= (pipe_i_x2 - pipe_i_x1) * (pipe_j_y1 - pipe_i_y1) - 
                             (pipe_i_y2 - pipe_i_y1) * (pipe_j_x1 - pipe_i_x1);
                    cross2 <= (pipe_i_x2 - pipe_i_x1) * (pipe_j_y2 - pipe_i_y1) - 
                             (pipe_i_y2 - pipe_i_y1) * (pipe_j_x2 - pipe_i_x1);
                    cross3 <= (pipe_j_x2 - pipe_j_x1) * (pipe_i_y1 - pipe_j_y1) - 
                             (pipe_j_y2 - pipe_j_y1) * (pipe_i_x1 - pipe_j_x1);
                    cross4 <= (pipe_j_x2 - pipe_j_x1) * (pipe_i_y2 - pipe_j_y1) - 
                             (pipe_j_y2 - pipe_j_y1) * (pipe_i_x2 - pipe_j_x1);

                    // Check if segments straddle each other
                    if (((cross1 ^ cross2) & 32'h80000000) && ((cross3 ^ cross4) & 32'h80000000)) begin
                        // Calculate intersection point
                        denom <= (pipe_i_x1 - pipe_i_x2) * (pipe_j_y1 - pipe_j_y2) - 
                                (pipe_i_y1 - pipe_i_y2) * (pipe_j_x1 - pipe_j_x2);
                        if (denom != 32'd0) begin
                            intersect_x <= ((pipe_i_x1 * pipe_i_y2 - pipe_i_y1 * pipe_i_x2) * (pipe_j_x1 - pipe_j_x2) - 
                                          (pipe_i_x1 - pipe_i_x2) * (pipe_j_x1 * pipe_j_y2 - pipe_j_y1 * pipe_j_x2)) / denom;
                            intersect_y <= ((pipe_i_x1 * pipe_i_y2 - pipe_i_y1 * pipe_i_x2) * (pipe_j_y1 - pipe_j_y2) - 
                                          (pipe_i_y1 - pipe_i_y2) * (pipe_j_x1 * pipe_j_y2 - pipe_j_y1 * pipe_j_x2)) / denom;

                            // Check if intersection is at a well
                            integer k;
                            is_well_intersect <= 1'b0;
                            for (k = 0; k < w; k = k + 1) begin
                                if ((intersect_x == well_x[k]) && (intersect_y == well_y[k])) begin
                                    is_well_intersect <= 1'b1;
                                end
                            end

                            if (!is_well_intersect) begin
                                is_intersect <= 1'b1;
                            end
                        end
                    end

                    // Update adjacency matrix
                    if (is_intersect) begin
                        adj_matrix[i_reg] <= adj_matrix[i_reg] | (1 << j_reg);
                        adj_matrix[j_reg] <= adj_matrix[j_reg] | (1 << i_reg);
                    end

                    // Update counters
                    if (j_reg == j_max) begin
                        i_reg <= i_reg + 10'd1;
                        j_reg <= i_reg + 10'd1;
                        i_next <= i_reg + 10'd1;
                        j_next <= i_next + 10'd1;
                    end else begin
                        j_reg <= j_reg + 10'd1;
                        j_next <= j_reg + 10'd1;
                    end

                    if (i_reg >= i_max) begin
                        intersect_done <= 1'b1;
                        state <= GRAPH_BUILD;
                    end
                end

                GRAPH_BUILD: begin
                    // Build adjacency lists from matrix
                    integer k, m;
                    for (k = 0; k < p; k = k + 1) begin
                        adj_list_size[k] <= 10'd0;
                        for (m = 0; m < p; m = m + 1) begin
                            if (adj_matrix[k][m]) begin
                                adj_list[k * 1024 + adj_list_size[k]] <= m;
                                adj_list_size[k] <= adj_list_size[k] + 10'd1;
                            end
                        end
                    end

                    graph_done <= 1'b1;
                    state <= BIPARTITE;
                    component_start <= 10'd0;
                    is_bipartite <= 1'b1;
                end

                BIPARTITE: begin
                    // Initialize queue for BFS
                    if (color[component_start] == 10'd0) begin
                        queue_head <= 10'd0;
                        queue_tail <= 10'd1;
                        queue[0] <= component_start;
                        color[component_start] <= 10'd1;
                    end

                    // Process queue
                    if (queue_head != queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 10'd1;

                        // Check all neighbors
                        neighbor_count <= adj_list_size[current_node];
                        neighbor_ptr <= 10'd0;

                        if (neighbor_count > 10'd0) begin
                            neighbor <= adj_list[current_node * 1024 + neighbor_ptr];
                            neighbor_ptr <= neighbor_ptr + 10'd1;

                            if (color[neighbor] == 10'd0) begin
                                color[neighbor] <= ~color[current_node] & 10'd1;
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 10'd1;
                            end else if (color[neighbor] == color[current_node]) begin
                                is_bipartite <= 1'b0;
                            end
                        end

                        // Move to next component if queue is empty
                        if (queue_head == queue_tail) begin
                            component_start <= component_start + 10'd1;
                            if (component_start >= p) begin
                                bipartite_done <= 1'b1;
                                state <= OUTPUT;
                            end
                        end
                    end else begin
                        component_start <= component_start + 10'd1;
                        if (component_start >= p) begin
                            bipartite_done <= 1'b1;
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    result <= is_bipartite;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule