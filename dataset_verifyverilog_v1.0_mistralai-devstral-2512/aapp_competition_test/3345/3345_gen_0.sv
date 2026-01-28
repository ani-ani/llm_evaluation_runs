module min_euclidean_distance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len_a,
    input wire [3:0] len_b,
    input wire signed [15:0] a_x_0, a_x_1, a_x_2, a_x_3, a_x_4, a_x_5, a_x_6, a_x_7, a_x_8, a_x_9, a_x_10, a_x_11, a_x_12, a_x_13, a_x_14, a_x_15,
    input wire signed [15:0] a_y_0, a_y_1, a_y_2, a_y_3, a_y_4, a_y_5, a_y_6, a_y_7, a_y_8, a_y_9, a_y_10, a_y_11, a_y_12, a_y_13, a_y_14, a_y_15,
    input wire signed [15:0] b_x_0, b_x_1, b_x_2, b_x_3, b_x_4, b_x_5, b_x_6, b_x_7, b_x_8, b_x_9, b_x_10, b_x_11, b_x_12, b_x_13, b_x_14, b_x_15,
    input wire signed [15:0] b_y_0, b_y_1, b_y_2, b_y_3, b_y_4, b_y_5, b_y_6, b_y_7, b_y_8, b_y_9, b_y_10, b_y_11, b_y_12, b_y_13, b_y_14, b_y_15,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_SEGMENTS = 3'd2;
    localparam [2:0] COMPUTE_MIN_DIST = 3'd3;
    localparam [2:0] COMPUTE_SQRT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // Segment counters
    reg [3:0] seg_a_idx;
    reg [3:0] seg_b_idx;

    // Time window for current segment pair
    reg [15:0] t_start;
    reg [15:0] t_end;

    // Current segment data
    reg signed [15:0] a_x_start, a_y_start;
    reg signed [15:0] a_x_end, a_y_end;
    reg signed [15:0] b_x_start, b_y_start;
    reg signed [15:0] b_x_end, b_y_end;

    // Segment lengths (in time units)
    reg signed [15:0] seg_a_len;
    reg signed [15:0] seg_b_len;

    // Position deltas
    reg signed [15:0] a_dx, a_dy;
    reg signed [15:0] b_dx, b_dy;

    // Minimum distance squared (Q16.16)
    reg signed [31:0] min_dist_sq;

    // Current distance squared (Q16.16)
    reg signed [31:0] curr_dist_sq;

    // Time variable for distance computation
    reg [15:0] t;

    // Square root computation variables
    reg signed [31:0] sqrt_val;
    reg signed [31:0] sqrt_prev;
    reg [3:0] sqrt_iter;

    // Cycle counter for timeout
    reg [17:0] cycle_count;
    localparam [17:0] MAX_CYCLES = 18'd200000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            seg_a_idx <= 4'd0;
            seg_b_idx <= 4'd0;
            t_start <= 16'd0;
            t_end <= 16'd0;
            a_x_start <= 16'd0;
            a_y_start <= 16'd0;
            a_x_end <= 16'd0;
            a_y_end <= 16'd0;
            b_x_start <= 16'd0;
            b_y_start <= 16'd0;
            b_x_end <= 16'd0;
            b_y_end <= 16'd0;
            seg_a_len <= 16'd0;
            seg_b_len <= 16'd0;
            a_dx <= 16'd0;
            a_dy <= 16'd0;
            b_dx <= 16'd0;
            b_dy <= 16'd0;
            min_dist_sq <= 32'd0;
            curr_dist_sq <= 32'd0;
            t <= 16'd0;
            sqrt_val <= 32'd0;
            sqrt_prev <= 32'd0;
            sqrt_iter <= 4'd0;
            cycle_count <= 18'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 18'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 18'd0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize segment indices and min distance
                    seg_a_idx <= 4'd0;
                    seg_b_idx <= 4'd0;
                    min_dist_sq <= 32'd0;
                    next_state <= COMPUTE_SEGMENTS;
                end

                COMPUTE_SEGMENTS: begin
                    // Load current segment data
                    case (seg_a_idx)
                        4'd0: begin a_x_start = a_x_0; a_y_start = a_y_0; end
                        4'd1: begin a_x_start = a_x_1; a_y_start = a_y_1; end
                        4'd2: begin a_x_start = a_x_2; a_y_start = a_y_2; end
                        4'd3: begin a_x_start = a_x_3; a_y_start = a_y_3; end
                        4'd4: begin a_x_start = a_x_4; a_y_start = a_y_4; end
                        4'd5: begin a_x_start = a_x_5; a_y_start = a_y_5; end
                        4'd6: begin a_x_start = a_x_6; a_y_start = a_y_6; end
                        4'd7: begin a_x_start = a_x_7; a_y_start = a_y_7; end
                        4'd8: begin a_x_start = a_x_8; a_y_start = a_y_8; end
                        4'd9: begin a_x_start = a_x_9; a_y_start = a_y_9; end
                        4'd10: begin a_x_start = a_x_10; a_y_start = a_y_10; end
                        4'd11: begin a_x_start = a_x_11; a_y_start = a_y_11; end
                        4'd12: begin a_x_start = a_x_12; a_y_start = a_y_12; end
                        4'd13: begin a_x_start = a_x_13; a_y_start = a_y_13; end
                        4'd14: begin a_x_start = a_x_14; a_y_start = a_y_14; end
                        4'd15: begin a_x_start = a_x_15; a_y_start = a_y_15; end
                    endcase

                    case (seg_a_idx + 4'd1)
                        4'd1: begin a_x_end = a_x_1; a_y_end = a_y_1; end
                        4'd2: begin a_x_end = a_x_2; a_y_end = a_y_2; end
                        4'd3: begin a_x_end = a_x_3; a_y_end = a_y_3; end
                        4'd4: begin a_x_end = a_x_4; a_y_end = a_y_4; end
                        4'd5: begin a_x_end = a_x_5; a_y_end = a_y_5; end
                        4'd6: begin a_x_end = a_x_6; a_y_end = a_y_6; end
                        4'd7: begin a_x_end = a_x_7; a_y_end = a_y_7; end
                        4'd8: begin a_x_end = a_x_8; a_y_end = a_y_8; end
                        4'd9: begin a_x_end = a_x_9; a_y_end = a_y_9; end
                        4'd10: begin a_x_end = a_x_10; a_y_end = a_y_10; end
                        4'd11: begin a_x_end = a_x_11; a_y_end = a_y_11; end
                        4'd12: begin a_x_end = a_x_12; a_y_end = a_y_12; end
                        4'd13: begin a_x_end = a_x_13; a_y_end = a_y_13; end
                        4'd14: begin a_x_end = a_x_14; a_y_end = a_y_14; end
                        4'd15: begin a_x_end = a_x_15; a_y_end = a_y_15; end
                    endcase

                    case (seg_b_idx)
                        4'd0: begin b_x_start = b_x_0; b_y_start = b_y_0; end
                        4'd1: begin b_x_start = b_x_1; b_y_start = b_y_1; end
                        4'd2: begin b_x_start = b_x_2; b_y_start = b_y_2; end
                        4'd3: begin b_x_start = b_x_3; b_y_start = b_y_3; end
                        4'd4: begin b_x_start = b_x_4; b_y_start = b_y_4; end
                        4'd5: begin b_x_start = b_x_5; b_y_start = b_y_5; end
                        4'd6: begin b_x_start = b_x_6; b_y_start = b_y_6; end
                        4'd7: begin b_x_start = b_x_7; b_y_start = b_y_7; end
                        4'd8: begin b_x_start = b_x_8; b_y_start = b_y_8; end
                        4'd9: begin b_x_start = b_x_9; b_y_start = b_y_9; end
                        4'd10: begin b_x_start = b_x_10; b_y_start = b_y_10; end
                        4'd11: begin b_x_start = b_x_11; b_y_start = b_y_11; end
                        4'd12: begin b_x_start = b_x_12; b_y_start = b_y_12; end
                        4'd13: begin b_x_start = b_x_13; b_y_start = b_y_13; end
                        4'd14: begin b_x_start = b_x_14; b_y_start = b_y_14; end
                        4'd15: begin b_x_start = b_x_15; b_y_start = b_y_15; end
                    endcase

                    case (seg_b_idx + 4'd1)
                        4'd1: begin b_x_end = b_x_1; b_y_end = b_y_1; end
                        4'd2: begin b_x_end = b_x_2; b_y_end = b_y_2; end
                        4'd3: begin b_x_end = b_x_3; b_y_end = b_y_3; end
                        4'd4: begin b_x_end = b_x_4; b_y_end = b_y_4; end
                        4'd5: begin b_x_end = b_x_5; b_y_end = b_y_5; end
                        4'd6: begin b_x_end = b_x_6; b_y_end = b_y_6; end
                        4'd7: begin b_x_end = b_x_7; b_y_end = b_y_7; end
                        4'd8: begin b_x_end = b_x_8; b_y_end = b_y_8; end
                        4'd9: begin b_x_end = b_x_9; b_y_end = b_y_9; end
                        4'd10: begin b_x_end = b_x_10; b_y_end = b_y_10; end
                        4'd11: begin b_x_end = b_x_11; b_y_end = b_y_11; end
                        4'd12: begin b_x_end = b_x_12; b_y_end = b_y_12; end
                        4'd13: begin b_x_end = b_x_13; b_y_end = b_y_13; end
                        4'd14: begin b_x_end = b_x_14; b_y_end = b_y_14; end
                        4'd15: begin b_x_end = b_x_15; b_y_end = b_y_15; end
                    endcase

                    // Compute segment lengths (Euclidean distance in Q8.8 format)
                    a_dx = a_x_end - a_x_start;
                    a_dy = a_y_end - a_y_start;
                    seg_a_len = $signed({16'd0, a_dx}) * $signed({16'd0, a_dx}) + $signed({16'd0, a_dy}) * $signed({16'd0, a_dy});

                    b_dx = b_x_end - b_x_start;
                    b_dy = b_y_end - b_y_start;
                    seg_b_len = $signed({16'd0, b_dx}) * $signed({16'd0, b_dx}) + $signed({16'd0, b_dy}) * $signed({16'd0, b_dy});

                    // Compute time window for this segment pair
                    t_start = 16'd0;
                    t_end = seg_a_len < seg_b_len ? seg_a_len : seg_b_len;

                    // Initialize time variable
                    t <= 16'd0;

                    next_state <= COMPUTE_MIN_DIST;
                end

                COMPUTE_MIN_DIST: begin
                    // Compute positions at time t (Q8.8 format)
                    reg signed [15:0] a_x_t, a_y_t;
                    reg signed [15:0] b_x_t, b_y_t;

                    // Linear interpolation: pos = start + (end - start) * t / length
                    // To avoid division, we'll use fixed-point arithmetic
                    // Compute t/length as Q16.16 fraction
                    reg signed [31:0] t_frac_a, t_frac_b;

                    if (seg_a_len != 16'd0) begin
                        t_frac_a = $signed({16'd0, t}) << 16;
                        t_frac_a = t_frac_a / $signed(seg_a_len);
                    end else begin
                        t_frac_a = 16'd0;
                    end

                    if (seg_b_len != 16'd0) begin
                        t_frac_b = $signed({16'd0, t}) << 16;
                        t_frac_b = t_frac_b / $signed(seg_b_len);
                    end else begin
                        t_frac_b = 16'd0;
                    end

                    // Compute positions (Q8.8 format)
                    a_x_t = a_x_start + ({a_dx, 16'd0} * t_frac_a) >> 16;
                    a_y_t = a_y_start + ({a_dy, 16'd0} * t_frac_a) >> 16;
                    b_x_t = b_x_start + ({b_dx, 16'd0} * t_frac_b) >> 16;
                    b_y_t = b_y_start + ({b_dy, 16'd0} * t_frac_b) >> 16;

                    // Compute distance squared (Q16.16 format)
                    reg signed [31:0] dx, dy;
                    dx = $signed({a_x_t, 16'd0}) - $signed({b_x_t, 16'd0});
                    dy = $signed({a_y_t, 16'd0}) - $signed({b_y_t, 16'd0});
                    curr_dist_sq = (dx * dx) + (dy * dy);

                    // Update minimum distance squared
                    if (curr_dist_sq < min_dist_sq || min_dist_sq == 32'd0) begin
                        min_dist_sq = curr_dist_sq;
                    end

                    // Increment time
                    t = t + 16'd1;

                    // Check if we've reached the end of the time window
                    if (t >= t_end) begin
                        // Move to next segment pair
                        if (seg_a_idx < len_a - 4'd1 && seg_b_idx < len_b - 4'd1) begin
                            seg_a_idx = seg_a_idx + 4'd1;
                            seg_b_idx = seg_b_idx + 4'd1;
                            next_state <= COMPUTE_SEGMENTS;
                        end else begin
                            // All segments processed, compute square root
                            sqrt_val = min_dist_sq;
                            sqrt_iter = 4'd0;
                            next_state <= COMPUTE_SQRT;
                        end
                    end
                end

                COMPUTE_SQRT: begin
                    // Newton-Raphson iteration for square root
                    // x_{n+1} = (x_n + S/x_n) / 2
                    if (sqrt_iter < 4'd16) begin
                        if (sqrt_val == 32'd0) begin
                            sqrt_val = 32'd0;
                        end else begin
                            sqrt_prev = sqrt_val;
                            sqrt_val = (sqrt_val + (min_dist_sq / sqrt_val)) >> 1;
                        end
                        sqrt_iter = sqrt_iter + 4'd1;
                    end else begin
                        result = sqrt_val;
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

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule