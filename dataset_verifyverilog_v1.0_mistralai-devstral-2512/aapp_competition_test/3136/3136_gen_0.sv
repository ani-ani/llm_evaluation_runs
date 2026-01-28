module shipping_router(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [5:0] m,
    input wire [3:0] t,
    input wire [3:0] warehouse_a,
    input wire [3:0] warehouse_b,
    input wire [3:0] employee_loc [0:15],
    input wire [3:0] client_loc [0:15],
    input wire [3:0] edge_u [0:63],
    input wire [3:0] edge_v [0:63],
    input wire [31:0] edge_d [0:63],
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [31:0] INF = 32'hFFFFFFFF;
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [5:0] MAX_EDGES = 6'd64;
    localparam [3:0] MAX_DELIVERIES = 4'd16;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_EDGES = 4'd1;
    localparam [3:0] APSP = 4'd2;
    localparam [3:0] COMPUTE_COSTS = 4'd3;
    localparam [3:0] MATCH = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // State registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20000;

    // Distance matrix
    reg [31:0] dist_matrix [0:15][0:15];
    reg [5:0] edge_index;

    // Cost matrix
    reg [31:0] cost_matrix [0:15][0:15];
    reg [3:0] delivery_index;
    reg [3:0] employee_index;

    // DP state
    reg [31:0] dp_buffer [0:16];
    reg [3:0] dp_delivery;
    reg [3:0] dp_employee;

    // Temporary registers
    reg [3:0] i, j, k;
    reg [31:0] temp_dist;
    reg [31:0] min_cost;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            edge_index <= 6'd0;
            delivery_index <= 4'd0;
            employee_index <= 4'd0;
            dp_delivery <= 4'd0;
            dp_employee <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_dist <= 32'd0;
            min_cost <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;

            // Initialize distance matrix
            integer x, y;
            for (x = 0; x < 16; x = x + 1) begin
                for (y = 0; y < 16; y = y + 1) begin
                    dist_matrix[x][y] <= INF;
                end
            end

            // Initialize cost matrix
            for (x = 0; x < 16; x = x + 1) begin
                for (y = 0; y < 16; y = y + 1) begin
                    cost_matrix[x][y] <= 32'd0;
                end
            end

            // Initialize DP buffer
            for (x = 0; x < 16; x = x + 1) begin
                dp_buffer[x] <= 32'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_EDGES;
                        busy <= 1'b1;
                        cycle_count <= 8'd0;
                        edge_index <= 6'd0;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_index < m) begin
                        dist_matrix[edge_u[edge_index]][edge_v[edge_index]] <= edge_d[edge_index];
                        dist_matrix[edge_v[edge_index]][edge_u[edge_index]] <= edge_d[edge_index];
                        edge_index <= edge_index + 6'd1;
                    end else begin
                        // Set self-distances to 0
                        integer x;
                        for (x = 0; x < 16; x = x + 1) begin
                            dist_matrix[x][x] <= 32'd0;
                        end
                        next_state <= APSP;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                end

                APSP: begin
                    // Floyd-Warshall algorithm
                    if (k < n) begin
                        if (i < n) begin
                            if (j < n) begin
                                // dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                                if (dist_matrix[i][k] != INF && dist_matrix[k][j] != INF) begin
                                    temp_dist <= dist_matrix[i][k] + dist_matrix[k][j];
                                    if (temp_dist < dist_matrix[i][j]) begin
                                        dist_matrix[i][j] <= temp_dist;
                                    end
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= 4'd0;
                            j <= 4'd0;
                            k <= k + 4'd1;
                        end
                    end else begin
                        next_state <= COMPUTE_COSTS;
                        delivery_index <= 4'd0;
                        employee_index <= 4'd0;
                    end
                end

                COMPUTE_COSTS: begin
                    if (delivery_index < t) begin
                        if (employee_index < n) begin
                            // Cost1: dist(employee, warehouse_a) + dist(warehouse_a, client)
                            if (dist_matrix[employee_loc[employee_index]][warehouse_a] != INF && 
                                dist_matrix[warehouse_a][client_loc[delivery_index]] != INF) begin
                                min_cost <= dist_matrix[employee_loc[employee_index]][warehouse_a] + 
                                           dist_matrix[warehouse_a][client_loc[delivery_index]];
                            end else begin
                                min_cost <= INF;
                            end

                            // Cost2: dist(employee, warehouse_b) + dist(warehouse_b, client)
                            if (dist_matrix[employee_loc[employee_index]][warehouse_b] != INF && 
                                dist_matrix[warehouse_b][client_loc[delivery_index]] != INF) begin
                                temp_dist <= dist_matrix[employee_loc[employee_index]][warehouse_b] + 
                                            dist_matrix[warehouse_b][client_loc[delivery_index]];
                                if (temp_dist < min_cost) begin
                                    min_cost <= temp_dist;
                                end
                            end

                            cost_matrix[employee_index][delivery_index] <= min_cost;
                            employee_index <= employee_index + 4'd1;
                        end else begin
                            employee_index <= 4'd0;
                            delivery_index <= delivery_index + 4'd1;
                        end
                    end else begin
                        next_state <= MATCH;
                        dp_delivery <= 4'd0;
                        dp_employee <= 4'd0;

                        // Initialize DP buffer
                        integer x;
                        for (x = 0; x < 16; x = x + 1) begin
                            dp_buffer[x] <= 32'd0;
                        end
                    end
                end

                MATCH: begin
                    // Greedy matching algorithm
                    if (dp_delivery < t) begin
                        // Find minimum cost for this delivery
                        min_cost <= INF;
                        integer x;
                        for (x = 0; x < n; x = x + 1) begin
                            if (cost_matrix[x][dp_delivery] < min_cost) begin
                                min_cost <= cost_matrix[x][dp_delivery];
                                dp_employee <= x;
                            end
                        end

                        // Add to result
                        result <= result + min_cost;
                        dp_delivery <= dp_delivery + 4'd1;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule