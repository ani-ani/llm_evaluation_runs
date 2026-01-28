module RailwayNetwork(
    input clk,
    input rst_n,
    input start,
    input valid_input,
    input [3:0] city_idx,
    input [7:0] city_name,
    input [3:0] edge_src,
    input [3:0] edge_dst,
    input [15:0] edge_cost,
    input [1:0] assignment_idx,
    input [3:0] assignment_src,
    input [3:0] assignment_dst,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_CITIES = 3'd1;
    localparam [2:0] INIT_ROUTES = 3'd2;
    localparam [2:0] INIT_ASSIGNMENTS = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // City name storage (first 16 cities)
    reg [7:0] city_names [0:15];
    reg [3:0] city_count;

    // Adjacency matrix (16x16)
    reg [15:0] adj_matrix [0:15];
    reg [3:0] route_count;

    // Assignment pairs
    reg [3:0] assignments_src [0:3];
    reg [3:0] assignments_dst [0:3];
    reg [1:0] assignment_count;

    // Floyd-Warshall variables
    reg [15:0] dist [0:15];
    reg [3:0] k, i, j;

    // DP variables for 4 pairs
    reg [15:0] min_cost;
    reg [3:0] pair1, pair2, pair3, pair4;
    reg [15:0] temp_cost;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 8'd0;
            city_count <= 4'd0;
            route_count <= 4'd0;
            assignment_count <= 2'd0;

            // Initialize adjacency matrix
            integer idx1, idx2;
            for (idx1 = 0; idx1 < 16; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < 16; idx2 = idx2 + 1) begin
                    if (idx1 == idx2)
                        adj_matrix[idx1][idx2] <= 16'd0;
                    else
                        adj_matrix[idx1][idx2] <= 16'd65535;
                end
            end

            // Initialize city names
            for (idx1 = 0; idx1 < 16; idx1 = idx1 + 1) begin
                city_names[idx1] <= 8'd0;
            end

            // Initialize assignments
            for (idx1 = 0; idx1 < 4; idx1 = idx1 + 1) begin
                assignments_src[idx1] <= 4'd0;
                assignments_dst[idx1] <= 4'd0;
            end

            // Initialize DP variables
            min_cost <= 16'd65535;
            pair1 <= 4'd0;
            pair2 <= 4'd0;
            pair3 <= 4'd0;
            pair4 <= 4'd0;
            temp_cost <= 16'd0;

            // Initialize Floyd-Warshall variables
            k <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;

            // Initialize distance arrays
            for (idx1 = 0; idx1 < 16; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < 16; idx2 = idx2 + 1) begin
                    dist[idx1][idx2] <= adj_matrix[idx1][idx2];
                end
            end

        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 8'd0;
                    if (start && valid_input) begin
                        next_state <= INIT_CITIES;
                        ready <= 1'b0;
                    end
                end

                INIT_CITIES: begin
                    if (valid_input && city_idx < 16) begin
                        city_names[city_idx] <= city_name;
                        city_count <= city_count + 4'd1;
                        if (city_count == 4'd15) begin
                            next_state <= INIT_ROUTES;
                        end
                    end
                end

                INIT_ROUTES: begin
                    if (valid_input && edge_src < 16 && edge_dst < 16) begin
                        adj_matrix[edge_src][edge_dst] <= edge_cost;
                        adj_matrix[edge_dst][edge_src] <= edge_cost;
                        route_count <= route_count + 4'd1;
                        if (route_count == 4'd15) begin
                            next_state <= INIT_ASSIGNMENTS;
                        end
                    end
                end

                INIT_ASSIGNMENTS: begin
                    if (valid_input && assignment_idx < 4) begin
                        assignments_src[assignment_idx] <= assignment_src;
                        assignments_dst[assignment_idx] <= assignment_dst;
                        assignment_count <= assignment_count + 2'd1;
                        if (assignment_count == 2'd3) begin
                            next_state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Floyd-Warshall algorithm
                    if (k < 16) begin
                        if (i < 16) begin
                            if (j < 16) begin
                                if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= 4'd0;
                            k <= k + 4'd1;
                        end
                    end else begin
                        // After Floyd-Warshall, compute minimum cost for 4 pairs
                        if (pair1 < 16) begin
                            if (pair2 < 16) begin
                                if (pair3 < 16) begin
                                    if (pair4 < 16) begin
                                        // Calculate total cost for this combination
                                        temp_cost <= dist[assignments_src[0]][pair1] +
                                                   dist[assignments_src[1]][pair2] +
                                                   dist[assignments_src[2]][pair3] +
                                                   dist[assignments_src[3]][pair4] +
                                                   dist[pair1][assignments_dst[0]] +
                                                   dist[pair2][assignments_dst[1]] +
                                                   dist[pair3][assignments_dst[2]] +
                                                   dist[pair4][assignments_dst[3]];

                                        // Update minimum cost
                                        if (temp_cost < min_cost) begin
                                            min_cost <= temp_cost;
                                        end

                                        pair4 <= pair4 + 4'd1;
                                    end else begin
                                        pair4 <= 4'd0;
                                        pair3 <= pair3 + 4'd1;
                                    end
                                end else begin
                                    pair3 <= 4'd0;
                                    pair2 <= pair2 + 4'd1;
                                end
                            end else begin
                                pair2 <= 4'd0;
                                pair1 <= pair1 + 4'd1;
                            end
                        end else begin
                            // All combinations evaluated
                            result <= min_cost;
                            next_state <= FINISH;
                        end
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end

    // Initialize distance arrays on reset
    integer idx1, idx2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx1 = 0; idx1 < 16; idx1 = idx1 + 1) begin
                for (idx2 = 0; idx2 < 16; idx2 = idx2 + 1) begin
                    dist[idx1][idx2] <= adj_matrix[idx1][idx2];
                end
            end
        end
    end

endmodule