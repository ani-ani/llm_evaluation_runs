module beacon_visibility(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [15:0] beacon_x [0:15],
    input [15:0] beacon_y [0:15],
    input [15:0] mountain_x [0:15],
    input [15:0] mountain_y [0:15],
    input [15:0] mountain_r [0:15],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BUILD_GRAPH = 3'd2;
    localparam [2:0] BFS = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Graph adjacency matrix (16x16)
    reg [15:0] adj_matrix [0:15];
    reg [3:0] i, j, k;
    reg [3:0] current_beacon;
    reg [15:0] visited [0:15];
    reg [3:0] component_count;

    // Fixed-point arithmetic signals
    reg signed [31:0] dx, dy, dr, a, b, c, discriminant;
    reg signed [31:0] t0, t1, t, closest_x, closest_y;
    reg signed [31:0] dist_sq, radius_sq;
    reg signed [31:0] temp0, temp1, temp2, temp3;

    // Line segment intersection check
    reg line_blocked;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            current_beacon <= 4'd0;
            component_count <= 4'd0;
            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] <= 16'd0;
            end
            // Initialize visited array
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize adjacency matrix
                    for (i = 0; i < 16; i = i + 1) begin
                        adj_matrix[i] <= 16'd0;
                    end
                    // Initialize visited array
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 16'd0;
                    end
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    current_beacon <= 4'd0;
                    component_count <= 4'd0;
                    next_state <= BUILD_GRAPH;
                end

                BUILD_GRAPH: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Build adjacency matrix
                    if (i < n) begin
                        if (j < n) begin
                            if (i != j) begin
                                // Check if beacons i and j are visible
                                line_blocked <= 1'b0;
                                for (k = 0; k < m; k = k + 1) begin
                                    // Fixed-point arithmetic for line-circle intersection
                                    // Convert to Q16.16 format
                                    dx <= ({16'd0, beacon_x[j]} - {16'd0, beacon_x[i]}) << 16;
                                    dy <= ({16'd0, beacon_y[j]} - {16'd0, beacon_y[i]}) << 16;
                                    dr <= ({16'd0, mountain_r[k]});
                                    
                                    // Vector from beacon_i to mountain center
                                    a <= ({16'd0, mountain_x[k]} - {16'd0, beacon_x[i]}) << 16;
                                    b <= ({16'd0, mountain_y[k]} - {16'd0, beacon_y[i]}) << 16;
                                    
                                    // Projection of AC onto AB
                                    temp0 <= a * dx + b * dy;
                                    if (temp0 <= 32'd0) begin
                                        // Closest point is beacon_i
                                        temp1 <= a * a + b * b;
                                        if (temp1 < (dr * dr)) begin
                                            line_blocked <= 1'b1;
                                        end
                                    end else begin
                                        c <= (dx * dx + dy * dy);
                                        if (temp0 >= c) begin
                                            // Closest point is beacon_j
                                            temp1 <= (a - dx) * (a - dx) + (b - dy) * (b - dy);
                                            if (temp1 < (dr * dr)) begin
                                                line_blocked <= 1'b1;
                                            end
                                        end else begin
                                            // Closest point is on the segment
                                            t <= (temp0 << 16) / c;
                                            closest_x <= {16'd0, beacon_x[i]} + (t * dx) >> 16;
                                            closest_y <= {16'd0, beacon_y[i]} + (t * dy) >> 16;
                                            
                                            temp1 <= (closest_x - {16'd0, mountain_x[k]}) * (closest_x - {16'd0, mountain_x[k]}) +
                                                     (closest_y - {16'd0, mountain_y[k]}) * (closest_y - {16'd0, mountain_y[k]});
                                            if (temp1 < (dr * dr)) begin
                                                line_blocked <= 1'b1;
                                            end
                                        end
                                    end
                                end
                                if (!line_blocked) begin
                                    adj_matrix[i][j] <= 1'b1;
                                    adj_matrix[j][i] <= 1'b1;
                                end
                            end
                            j <= j + 1'b1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        current_beacon <= 4'd0;
                        component_count <= 4'd0;
                        next_state <= BFS;
                    end
                end

                BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // BFS to count connected components
                    if (current_beacon < n) begin
                        if (!visited[current_beacon]) begin
                            // Start BFS from this beacon
                            component_count <= component_count + 1'b1;
                            visited[current_beacon] <= 1'b1;
                            // BFS queue (simplified for 16 nodes)
                            for (i = 0; i < n; i = i + 1) begin
                                if (adj_matrix[current_beacon][i] && !visited[i]) begin
                                    visited[i] <= 1'b1;
                                end
                            end
                        end
                        current_beacon <= current_beacon + 1'b1;
                    end else begin
                        result <= component_count;
                        next_state <= FINISH;
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

endmodule