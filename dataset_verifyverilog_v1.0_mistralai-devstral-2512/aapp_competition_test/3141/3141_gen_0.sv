module min_drill_diameter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [12:0] N,
    input wire signed [31:0] points_x [0:4999],
    input wire signed [31:0] points_y [0:4999],
    input wire signed [31:0] points_z [0:4999],
    output reg signed [31:0] diameter,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_POINTS = 3'd1;
    localparam [2:0] COMPUTE_X  = 3'd2;
    localparam [2:0] COMPUTE_Y  = 3'd3;
    localparam [2:0] COMPUTE_Z  = 3'd4;
    localparam [2:0] FIND_MIN   = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Axis-specific results
    reg signed [31:0] diameter_x;
    reg signed [31:0] diameter_y;
    reg signed [31:0] diameter_z;

    // Current axis computation variables
    reg [1:0] current_axis;
    reg signed [31:0] current_radius;
    reg signed [31:0] current_center_x;
    reg signed [31:0] current_center_y;

    // Point iteration
    reg [12:0] point_idx;
    reg [12:0] pair_idx;

    // MEC computation variables
    reg signed [31:0] min_radius;
    reg signed [31:0] best_center_x;
    reg signed [31:0] best_center_y;

    // Fixed-point constants
    localparam signed [31:0] ONE = 32'sd1;
    localparam signed [31:0] TWO = 32'sd2;
    localparam signed [31:0] ZERO = 32'sd0;

    // Fixed-point square root approximation (10 iterations)
    function automatic signed [31:0] sqrt_fixed(input signed [31:0] x);
        reg signed [31:0] val;
        reg signed [31:0] last;
        reg [4:0] i;
        
        if (x <= ZERO) begin
            sqrt_fixed = ZERO;
        end else begin
            val = x;
            last = ZERO;
            for (i = 0; i < 10; i = i + 1) begin
                last = val;
                val = (val + x / val) >> 1;
            end
            sqrt_fixed = last;
        end
    endfunction

    // Fixed-point multiplication with scaling
    function automatic signed [31:0] mul_fixed(input signed [31:0] a, input signed [31:0] b);
        reg signed [63:0] temp;
        temp = $signed(a) * $signed(b);
        mul_fixed = temp[47:16]; // Q16.16 * Q16.16 = Q32.32, take upper 32 bits
    endfunction

    // Distance squared between two points
    function automatic signed [31:0] dist_sq(input signed [31:0] x1, input signed [31:0] y1,
                                              input signed [31:0] x2, input signed [31:0] y2);
        reg signed [31:0] dx = x1 - x2;
        reg signed [31:0] dy = y1 - y2;
        dist_sq = mul_fixed(dx, dx) + mul_fixed(dy, dy);
    endfunction

    // Check if all points are within radius of center
    function automatic reg check_all_points(input signed [31:0] center_x, input signed [31:0] center_y,
                                           input signed [31:0] radius_sq, input [1:0] axis);
        reg [12:0] i;
        reg signed [31:0] dx, dy, dist;
        
        check_all_points = 1'b1;
        for (i = 0; i < N; i = i + 1) begin
            case (axis)
                2'd0: begin // X-axis (y,z projection)
                    dx = points_y[i] - center_x;
                    dy = points_z[i] - center_y;
                end
                2'd1: begin // Y-axis (x,z projection)
                    dx = points_x[i] - center_x;
                    dy = points_z[i] - center_y;
                end
                2'd2: begin // Z-axis (x,y projection)
                    dx = points_x[i] - center_x;
                    dy = points_y[i] - center_y;
                end
            endcase
            dist = mul_fixed(dx, dx) + mul_fixed(dy, dy);
            if (dist > radius_sq) begin
                check_all_points = 1'b0;
            end
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            diameter <= ZERO;
            cycle_count <= 16'd0;
            point_idx <= 13'd0;
            pair_idx <= 13'd0;
            current_axis <= 2'd0;
            diameter_x <= ZERO;
            diameter_y <= ZERO;
            diameter_z <= ZERO;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_POINTS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_POINTS: begin
                    // In a real implementation, this would load points from memory
                    // For this specification, we assume points are already available
                    next_state <= COMPUTE_X;
                    current_axis <= 2'd0;
                    point_idx <= 13'd0;
                    pair_idx <= 13'd0;
                    min_radius <= 32'sd3276800000; // Large initial value (1000.0 in Q16.16)
                end

                COMPUTE_X: begin
                    // Project points onto Y-Z plane (drop X coordinate)
                    // Compute MEC for Y-Z points
                    if (pair_idx < N) begin
                        if (point_idx < N) begin
                            // Try circle defined by points[pair_idx] and points[point_idx]
                            current_center_x = (points_y[pair_idx] + points_y[point_idx]) >> 1;
                            current_center_y = (points_z[pair_idx] + points_z[point_idx]) >> 1;
                            current_radius = sqrt_fixed(dist_sq(points_y[pair_idx], points_z[pair_idx],
                                                             points_y[point_idx], points_z[point_idx]));
                            
                            // Check if this circle encloses all points
                            if (check_all_points(current_center_x, current_center_y,
                                               mul_fixed(current_radius, current_radius), 2'd0)) begin
                                if (current_radius < min_radius) begin
                                    min_radius = current_radius;
                                    best_center_x = current_center_x;
                                    best_center_y = current_center_y;
                                end
                            end
                            
                            point_idx <= point_idx + 13'd1;
                        end else begin
                            point_idx <= 13'd0;
                            pair_idx <= pair_idx + 13'd1;
                        end
                    end else begin
                        // Store result for X-axis
                        diameter_x <= mul_fixed(min_radius, TWO);
                        next_state <= COMPUTE_Y;
                        current_axis <= 2'd1;
                        point_idx <= 13'd0;
                        pair_idx <= 13'd0;
                        min_radius <= 32'sd3276800000;
                    end
                end

                COMPUTE_Y: begin
                    // Project points onto X-Z plane (drop Y coordinate)
                    // Compute MEC for X-Z points
                    if (pair_idx < N) begin
                        if (point_idx < N) begin
                            // Try circle defined by points[pair_idx] and points[point_idx]
                            current_center_x = (points_x[pair_idx] + points_x[point_idx]) >> 1;
                            current_center_y = (points_z[pair_idx] + points_z[point_idx]) >> 1;
                            current_radius = sqrt_fixed(dist_sq(points_x[pair_idx], points_z[pair_idx],
                                                             points_x[point_idx], points_z[point_idx]));
                            
                            // Check if this circle encloses all points
                            if (check_all_points(current_center_x, current_center_y,
                                               mul_fixed(current_radius, current_radius), 2'd1)) begin
                                if (current_radius < min_radius) begin
                                    min_radius = current_radius;
                                    best_center_x = current_center_x;
                                    best_center_y = current_center_y;
                                end
                            end
                            
                            point_idx <= point_idx + 13'd1;
                        end else begin
                            point_idx <= 13'd0;
                            pair_idx <= pair_idx + 13'd1;
                        end
                    end else begin
                        // Store result for Y-axis
                        diameter_y <= mul_fixed(min_radius, TWO);
                        next_state <= COMPUTE_Z;
                        current_axis <= 2'd2;
                        point_idx <= 13'd0;
                        pair_idx <= 13'd0;
                        min_radius <= 32'sd3276800000;
                    end
                end

                COMPUTE_Z: begin
                    // Project points onto X-Y plane (drop Z coordinate)
                    // Compute MEC for X-Y points
                    if (pair_idx < N) begin
                        if (point_idx < N) begin
                            // Try circle defined by points[pair_idx] and points[point_idx]
                            current_center_x = (points_x[pair_idx] + points_x[point_idx]) >> 1;
                            current_center_y = (points_y[pair_idx] + points_y[point_idx]) >> 1;
                            current_radius = sqrt_fixed(dist_sq(points_x[pair_idx], points_y[pair_idx],
                                                             points_x[point_idx], points_y[point_idx]));
                            
                            // Check if this circle encloses all points
                            if (check_all_points(current_center_x, current_center_y,
                                               mul_fixed(current_radius, current_radius), 2'd2)) begin
                                if (current_radius < min_radius) begin
                                    min_radius = current_radius;
                                    best_center_x = current_center_x;
                                    best_center_y = current_center_y;
                                end
                            end
                            
                            point_idx <= point_idx + 13'd1;
                        end else begin
                            point_idx <= 13'd0;
                            pair_idx <= pair_idx + 13'd1;
                        end
                    end else begin
                        // Store result for Z-axis
                        diameter_z <= mul_fixed(min_radius, TWO);
                        next_state <= FIND_MIN;
                    end
                end

                FIND_MIN: begin
                    // Find minimum diameter among the three axes
                    diameter <= diameter_x;
                    if (diameter_y < diameter) begin
                        diameter <= diameter_y;
                    end
                    if (diameter_z < diameter) begin
                        diameter <= diameter_z;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule