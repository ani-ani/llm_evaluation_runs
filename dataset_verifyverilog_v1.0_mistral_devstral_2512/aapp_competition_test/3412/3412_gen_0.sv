module shortest_time (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] v_walk,
    input wire [15:0] v_bike,
    input wire [15:0] x1, y1, x2, y2,
    input wire [15:0] xG, yG,
    input wire [15:0] xD, yD,
    input wire [1:0] n,
    input wire [15:0] station_x_0, station_y_0,
    input wire [15:0] station_x_1, station_y_1,
    input wire [15:0] station_x_2, station_y_2,
    input wire [15:0] station_x_3, station_y_3,
    output wire [31:0] result,
    output wire done
);

    // State machine declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE_DISTANCES = 3'd2;
    localparam [2:0] DIJKSTRA = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Node coordinates (Q16.16 format)
    reg signed [31:0] node_x [0:9];
    reg signed [31:0] node_y [0:9];

    // Distance matrix (Q16.16 format)
    reg signed [31:0] dist [0:9][0:9];

    // Dijkstra variables
    reg signed [31:0] min_dist [0:9];
    reg [3:0] visited [0:9];
    reg [3:0] current_node;
    reg [3:0] i, j, k;

    // Output registers
    reg [31:0] result_reg;
    reg done_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            done_reg <= 1'b0;
            result_reg <= 32'd0;
            
            // Initialize all registers
            for (i = 0; i < 10; i = i + 1) begin
                node_x[i] <= 32'd0;
                node_y[i] <= 32'd0;
                for (j = 0; j < 10; j = j + 1) begin
                    dist[i][j] <= 32'd0;
                end
                min_dist[i] <= 32'd0;
                visited[i] <= 4'd0;
            end
            current_node <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE_DISTANCES;
            end
            
            COMPUTE_DISTANCES: begin
                next_state = DIJKSTRA;
            end
            
            DIJKSTRA: begin
                if (visited[1]) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load node coordinates
    always @(posedge clk) begin
        if (state == LOAD) begin
            // Node 0: Start point (G)
            node_x[0] <= {16'd0, xG};
            node_y[0] <= {16'd0, yG};
            
            // Node 1: Destination (D)
            node_x[1] <= {16'd0, xD};
            node_y[1] <= {16'd0, yD};
            
            // Nodes 2-5: Bike stations
            node_x[2] <= {16'd0, station_x_0};
            node_y[2] <= {16'd0, station_y_0};
            node_x[3] <= {16'd0, station_x_1};
            node_y[3] <= {16'd0, station_y_1};
            node_x[4] <= {16'd0, station_x_2};
            node_y[4] <= {16'd0, station_y_2};
            node_x[5] <= {16'd0, station_x_3};
            node_y[5] <= {16'd0, station_y_3};
            
            // Nodes 6-9: Corners (x1,y1), (x1,y2), (x2,y1), (x2,y2)
            node_x[6] <= {16'd0, x1};
            node_y[6] <= {16'd0, y1};
            node_x[7] <= {16'd0, x1};
            node_y[7] <= {16'd0, y2};
            node_x[8] <= {16'd0, x2};
            node_y[8] <= {16'd0, y1};
            node_x[9] <= {16'd0, x2};
            node_y[9] <= {16'd0, y2};
        end
    end

    // Compute distances between all node pairs
    always @(posedge clk) begin
        if (state == COMPUTE_DISTANCES) begin
            // Compute walking distances for all pairs
            for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 10; j = j + 1) begin
                    if (i != j) begin
                        // Calculate Euclidean distance
                        reg signed [31:0] dx = node_x[i] - node_x[j];
                        reg signed [31:0] dy = node_y[i] - node_y[j];
                        reg signed [31:0] dx_sq = dx * dx;
                        reg signed [31:0] dy_sq = dy * dy;
                        reg signed [31:0] dist_sq = dx_sq + dy_sq;
                        
                        // Square root approximation (non-restoring algorithm)
                        reg signed [31:0] root = 32'd0;
                        reg signed [31:0] remainder = 32'd0;
                        reg [4:0] bit;
                        
                        for (bit = 15; bit >= 0; bit = bit - 1) begin
                            remainder = {remainder[30:0], 1'b0};
                            root = {root[30:0], 1'b0};
                            if (remainder >= dist_sq) begin
                                remainder = remainder - dist_sq;
                                root[0] = 1'b1;
                            end
                            dist_sq = {dist_sq[29:0], 2'b00};
                        end
                        
                        // Divide by walking speed (Q16.16)
                        dist[i][j] = (root << 16) / {16'd0, v_walk};
                    end
                end
            end
            
            // Override bike station distances with biking speed
            for (i = 2; i < 6; i = i + 1) begin
                for (j = 2; j < 6; j = j + 1) begin
                    if (i != j) begin
                        reg signed [31:0] dx = node_x[i] - node_x[j];
                        reg signed [31:0] dy = node_y[i] - node_y[j];
                        reg signed [31:0] dx_sq = dx * dx;
                        reg signed [31:0] dy_sq = dy * dy;
                        reg signed [31:0] dist_sq = dx_sq + dy_sq;
                        
                        reg signed [31:0] root = 32'd0;
                        reg signed [31:0] remainder = 32'd0;
                        reg [4:0] bit;
                        
                        for (bit = 15; bit >= 0; bit = bit - 1) begin
                            remainder = {remainder[30:0], 1'b0};
                            root = {root[30:0], 1'b0};
                            if (remainder >= dist_sq) begin
                                remainder = remainder - dist_sq;
                                root[0] = 1'b1;
                            end
                            dist_sq = {dist_sq[29:0], 2'b00};
                        end
                        
                        dist[i][j] = (root << 16) / {16'd0, v_bike};
                    end
                end
            end
        end
    end

    // Dijkstra's algorithm
    always @(posedge clk) begin
        if (state == DIJKSTRA) begin
            // Initialize
            if (cycle_count == 16'd0) begin
                for (i = 0; i < 10; i = i + 1) begin
                    min_dist[i] = 32'd2147483647; // Max value
                    visited[i] = 4'd0;
                end
                min_dist[0] = 32'd0;
                current_node = 4'd0;
            end else begin
                // Find unvisited node with minimum distance
                reg [3:0] min_node = 4'd0;
                reg signed [31:0] min_val = 32'd2147483647;
                
                for (i = 0; i < 10; i = i + 1) begin
                    if (!visited[i] && min_dist[i] < min_val) begin
                        min_val = min_dist[i];
                        min_node = i;
                    end
                end
                
                current_node = min_node;
                visited[current_node] = 4'd1;
                
                // Update distances
                for (i = 0; i < 10; i = i + 1) begin
                    if (!visited[i]) begin
                        reg signed [31:0] new_dist = min_dist[current_node] + dist[current_node][i];
                        if (new_dist < min_dist[i]) begin
                            min_dist[i] = new_dist;
                        end
                    end
                end
            end
        end
    end

    // Output result
    always @(posedge clk) begin
        if (state == FINISH) begin
            result_reg = min_dist[1];
            done_reg = 1'b1;
        end else if (state == IDLE) begin
            done_reg = 1'b0;
        end
    end

    // Timeout check
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            state <= FINISH;
            result_reg <= 32'd0;
            done_reg <= 1'b1;
        end
    end

    // Output assignments
    assign result = result_reg;
    assign done = done_reg;

endmodule