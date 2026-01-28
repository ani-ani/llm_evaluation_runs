module CircleRayIntersection(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [15:0] x_arr [0:9],
    input wire signed [15:0] y_arr [0:9],
    input wire [15:0] r_arr [0:9],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_INTERVALS = 3'd1;
    localparam [2:0] SORT_POINTS = 3'd2;
    localparam [2:0] SWEEP = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Intermediate storage for intervals
    reg [15:0] interval_start [0:9];
    reg [15:0] interval_end [0:9];
    reg [3:0] valid_intervals;

    // Points for sorting (angle, type: 1=start, 0=end)
    reg [15:0] points [0:19];
    reg [0:0] point_types [0:19];
    reg [4:0] num_points;

    // Sorting variables
    reg [4:0] i, j;
    reg [15:0] temp_angle;
    reg [0:0] temp_type;

    // Sweep variables
    reg [3:0] current_count;
    reg [3:0] max_count;

    // Fixed-point constants
    localparam [15:0] PI = 16'd50929; // Q8.8 representation of π (≈3.14159)
    localparam [15:0] TWO_PI = 16'd101858; // Q8.8 representation of 2π

    // Compute distance squared (Q8.8 * Q8.8 = Q16.16)
    function [31:0] compute_distance_squared;
        input [15:0] x, y;
        reg [31:0] distance_sq;
        begin
            distance_sq = ($signed(x) * $signed(x)) + ($signed(y) * $signed(y));
        end
    endfunction

    // Approximate sqrt for Q16.16 input (returns Q8.8)
    function [15:0] fixed_sqrt;
        input [31:0] val;
        reg [15:0] result;
        reg [31:0] temp;
        reg [4:0] k;
        begin
            if (val == 0) begin
                result = 16'd0;
            end else begin
                temp = val;
                for (k = 0; k < 5; k = k + 1) begin
                    temp = (temp + (val / temp)) >> 1;
                end
                result = temp[23:8]; // Take upper 16 bits as Q8.8
            end
        end
    endfunction

    // Approximate atan2 for Q8.8 inputs (returns Q8.8 angle)
    function [15:0] fixed_atan2;
        input [15:0] y, x;
        reg [15:0] angle;
        reg [15:0] abs_y, abs_x;
        reg [15:0] r, r_3, r_5;
        reg [15:0] angle_temp;
        reg [0:0] sign_y, sign_x;
        reg [1:0] quadrant;
        begin
            // Handle special cases
            if (x == 16'd0 && y == 16'd0) begin
                angle = 16'd0;
            end else if (x == 16'd0) begin
                angle = (y > 16'd0) ? PI : (y < 16'd0) ? TWO_PI - PI : 16'd0;
            end else if (y == 16'd0) begin
                angle = (x > 16'd0) ? 16'd0 : PI;
            end else begin
                // Determine quadrant
                sign_y = y[15];
                sign_x = x[15];
                abs_y = sign_y ? -y : y;
                abs_x = sign_x ? -x : x;

                // Compute ratio
                if (abs_x > abs_y) begin
                    r = (abs_y << 8) / abs_x; // Q8.8 / Q8.8 = Q8.8
                    r_3 = (r * r * r) >> 16; // Q8.8 * Q8.8 = Q16.16, take upper 16
                    r_5 = (r_3 * r * r) >> 16;
                    angle_temp = r - (r_3 >> 2) + (r_5 >> 4); // Approximation
                    quadrant = sign_x ? (sign_y ? 3'd3 : 3'd2) : (sign_y ? 3'd0 : 3'd1);
                end else begin
                    r = (abs_x << 8) / abs_y; // Q8.8 / Q8.8 = Q8.8
                    r_3 = (r * r * r) >> 16;
                    r_5 = (r_3 * r * r) >> 16;
                    angle_temp = (PI >> 1) - (r - (r_3 >> 2) + (r_5 >> 4));
                    quadrant = sign_y ? (sign_x ? 3'd2 : 3'd1) : (sign_x ? 3'd3 : 3'd0);
                end

                // Adjust for quadrant
                case (quadrant)
                    3'd0: angle = angle_temp;
                    3'd1: angle = PI - angle_temp;
                    3'd2: angle = PI + angle_temp;
                    3'd3: angle = TWO_PI - angle_temp;
                endcase
            end
        end
    endfunction

    // Approximate asin for Q8.8 input (returns Q8.8 angle)
    function [15:0] fixed_asin;
        input [15:0] val;
        reg [15:0] angle;
        reg [15:0] x, x_sq, x_cu;
        begin
            if (val > 16'd256) begin // Q8.8 representation of 1.0
                angle = PI >> 1; // π/2
            end else if (val < -16'd256) begin
                angle = - (PI >> 1);
            end else begin
                x = val;
                x_sq = (x * x) >> 8; // Q8.8 * Q8.8 = Q16.16, take upper 16
                x_cu = (x_sq * x) >> 8;
                // Approximation: asin(x) ≈ x + (x^3)/6 + (3*x^5)/40
                angle = x + (x_cu >> 2) + ((3 * x_cu * x_sq) >> 7);
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            valid_intervals <= 4'd0;
            num_points <= 5'd0;
            current_count <= 4'd0;
            max_count <= 4'd0;
            i <= 5'd0;
            j <= 5'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_INTERVALS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_INTERVALS: begin
                    if (i < n) begin
                        // Compute distance
                        reg [31:0] dist_sq = compute_distance_squared(x_arr[i], y_arr[i]);
                        reg [15:0] dist = fixed_sqrt(dist_sq);

                        // Check if circle contains origin
                        if (dist > r_arr[i]) begin
                            // Compute angle to center
                            reg [15:0] alpha = fixed_atan2(y_arr[i], x_arr[i]);

                            // Compute angular half-width
                            reg [15:0] delta = fixed_asin((r_arr[i] << 8) / dist);

                            // Compute interval
                            reg [15:0] start_angle = alpha - delta;
                            reg [15:0] end_angle = alpha + delta;

                            // Handle negative angles (wrap around)
                            if (start_angle < 0) begin
                                start_angle = start_angle + TWO_PI;
                            end
                            if (end_angle < 0) begin
                                end_angle = end_angle + TWO_PI;
                            end

                            // Store interval
                            interval_start[i] = start_angle;
                            interval_end[i] = end_angle;
                            valid_intervals = i + 1;
                        end else begin
                            // Invalid circle (contains origin)
                            interval_start[i] = 16'd0;
                            interval_end[i] = 16'd0;
                        end

                        i = i + 1;
                        next_state <= COMPUTE_INTERVALS;
                    end else begin
                        // Collect all points
                        reg [4:0] point_idx;
                        for (point_idx = 0; point_idx < valid_intervals; point_idx = point_idx + 1) begin
                            points[point_idx * 2] = interval_start[point_idx];
                            point_types[point_idx * 2] = 1'b1;
                            points[point_idx * 2 + 1] = interval_end[point_idx];
                            point_types[point_idx * 2 + 1] = 1'b0;
                        end
                        num_points = valid_intervals * 2;
                        i = 5'd0;
                        j = 5'd0;
                        next_state <= SORT_POINTS;
                    end
                end

                SORT_POINTS: begin
                    // Bubble sort
                    if (i < num_points - 1) begin
                        if (j < num_points - i - 1) begin
                            if (points[j] > points[j + 1]) begin
                                // Swap
                                temp_angle = points[j];
                                points[j] = points[j + 1];
                                points[j + 1] = temp_angle;
                                temp_type = point_types[j];
                                point_types[j] = point_types[j + 1];
                                point_types[j + 1] = temp_type;
                            end
                            j = j + 1;
                        end else begin
                            i = i + 1;
                            j = 5'd0;
                        end
                        next_state <= SORT_POINTS;
                    end else begin
                        // Sorting complete
                        current_count = 4'd0;
                        max_count = 4'd0;
                        i = 5'd0;
                        next_state <= SWEEP;
                    end
                end

                SWEEP: begin
                    if (i < num_points) begin
                        if (point_types[i]) begin
                            current_count = current_count + 1;
                        end else begin
                            current_count = current_count - 1;
                        end

                        if (current_count > max_count) begin
                            max_count = current_count;
                        end

                        i = i + 1;
                        next_state <= SWEEP;
                    end else begin
                        // Handle wrap-around
                        reg [3:0] wrap_count = 4'd0;
                        reg [4:0] k;
                        for (k = 0; k < num_points; k = k + 1) begin
                            if (points[k] > 16'd65535 - (TWO_PI >> 8)) begin
                                if (point_types[k]) begin
                                    wrap_count = wrap_count + 1;
                                end else begin
                                    wrap_count = wrap_count - 1;
                                end
                            end
                        end

                        if (wrap_count > max_count) begin
                            max_count = wrap_count;
                        end

                        result = max_count;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule