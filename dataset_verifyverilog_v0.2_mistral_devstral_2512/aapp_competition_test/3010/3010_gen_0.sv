module line_intersection_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] x0, y0, x1, y1,
    input [1:0] segment_index,
    input load_enable,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // Internal registers for storing 4 segments
    reg [15:0] seg_x0 [0:3], seg_y0 [0:3], seg_x1 [0:3], seg_y1 [0:3];
    reg [1:0] load_state;
    reg [2:0] process_state;
    reg [2:0] pair_index;
    reg [15:0] current_x0, current_y0, current_x1, current_y1;
    reg [15:0] next_x0, next_y0, next_x1, next_y1;
    reg [31:0] intersection_x, intersection_y;
    reg [31:0] found_intersections [0:5];
    reg [2:0] found_count;
    reg [15:0] dx1, dy1, dx2, dy2;
    reg [31:0] determinant;
    reg [31:0] t_numerator, t_denominator;
    reg [31:0] u_numerator, u_denominator;
    reg [31:0] t, u;
    reg [31:0] cross_product;
    reg [31:0] min_proj1, max_proj1, min_proj2, max_proj2;
    reg [31:0] proj1, proj2;
    reg [31:0] temp_x, temp_y;
    reg [31:0] diff_x, diff_y;
    reg [31:0] abs_diff_x, abs_diff_y;
    reg [31:0] threshold;
    reg is_parallel, is_collinear, is_overlap, is_single_point;
    reg [2:0] i, j;
    reg [31:0] seg1_x0, seg1_y0, seg1_x1, seg1_y1;
    reg [31:0] seg2_x0, seg2_y0, seg2_x1, seg2_y1;

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_SEGMENTS = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] CHECK_PARALLEL = 3'd3;
    localparam [2:0] CHECK_OVERLAP = 3'd4;
    localparam [2:0] CALC_INTERSECTION = 3'd5;
    localparam [2:0] VERIFY_BOUNDS = 3'd6;
    localparam [2:0] UPDATE_RESULT = 3'd7;
    localparam [2:0] DONE = 3'd8;

    // Fixed-point arithmetic functions
    function [31:0] fp_mult;
        input [15:0] a, b;
        begin
            fp_mult = ($signed(a) * $signed(b)) >> 8;
        end
    endfunction

    function [31:0] fp_div;
        input [31:0] num, den;
        reg [31:0] quotient;
        reg [31:0] remainder;
        reg [31:0] abs_num, abs_den;
        reg sign;
        integer k;
        begin
            if (den == 0) begin
                fp_div = 0;
            end else begin
                abs_num = num >= 0 ? num : -num;
                abs_den = den >= 0 ? den : -den;
                sign = (num < 0) ^ (den < 0);
                quotient = 0;
                remainder = 0;
                for (k = 31; k >= 0; k = k - 1) begin
                    remainder = remainder << 1;
                    remainder[0] = abs_num[31 - k];
                    if (remainder >= abs_den) begin
                        remainder = remainder - abs_den;
                        quotient[k] = 1;
                    end
                end
                fp_div = sign ? -quotient : quotient;
            end
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            load_state <= 0;
            process_state <= IDLE;
            pair_index <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
            found_count <= 0;
            for (i = 0; i < 4; i = i + 1) begin
                seg_x0[i] <= 0;
                seg_y0[i] <= 0;
                seg_x1[i] <= 0;
                seg_y1[i] <= 0;
            end
            for (i = 0; i < 6; i = i + 1) begin
                found_intersections[i] <= 0;
            end
        end else begin
            case (process_state)
                IDLE: begin
                    if (start) begin
                        process_state <= LOAD_SEGMENTS;
                        load_state <= 0;
                        done <= 0;
                        error <= 0;
                        result <= 0;
                        found_count <= 0;
                    end
                end
                LOAD_SEGMENTS: begin
                    if (load_enable) begin
                        seg_x0[segment_index] <= x0;
                        seg_y0[segment_index] <= y0;
                        seg_x1[segment_index] <= x1;
                        seg_y1[segment_index] <= y1;
                        if (segment_index == 3) begin
                            process_state <= PROCESS;
                            pair_index <= 0;
                        end
                    end
                end
                PROCESS: begin
                    if (pair_index < 6) begin
                        // Determine current pair (i,j)
                        case (pair_index)
                            0: begin i = 0; j = 1; end
                            1: begin i = 0; j = 2; end
                            2: begin i = 0; j = 3; end
                            3: begin i = 1; j = 2; end
                            4: begin i = 1; j = 3; end
                            5: begin i = 2; j = 3; end
                        endcase
                        current_x0 = seg_x0[i];
                        current_y0 = seg_y0[i];
                        current_x1 = seg_x1[i];
                        current_y1 = seg_y1[i];
                        next_x0 = seg_x0[j];
                        next_y0 = seg_y0[j];
                        next_x1 = seg_x1[j];
                        next_y1 = seg_y1[j];
                        process_state <= CHECK_PARALLEL;
                    end else begin
                        process_state <= DONE;
                        done <= 1;
                    end
                end
                CHECK_PARALLEL: begin
                    // Calculate dx and dy for both segments
                    dx1 = current_x1 - current_x0;
                    dy1 = current_y1 - current_y0;
                    dx2 = next_x1 - next_x0;
                    dy2 = next_y1 - next_y0;
                    // Calculate determinant (dx1*dy2 - dx2*dy1)
                    determinant = fp_mult(dx1, dy2) - fp_mult(dx2, dy1);
                    is_parallel = (determinant == 0);
                    if (is_parallel) begin
                        process_state <= CHECK_OVERLAP;
                    end else begin
                        process_state <= CALC_INTERSECTION;
                    end
                end
                CHECK_OVERLAP: begin
                    // Check if segments are collinear
                    cross_product = fp_mult((next_x0 - current_x0), dy1) - fp_mult((next_y0 - current_y0), dx1);
                    is_collinear = (cross_product == 0);
                    if (is_collinear) begin
                        // Calculate projections
                        seg1_x0 = $signed(current_x0) << 16;
                        seg1_y0 = $signed(current_y0) << 16;
                        seg1_x1 = $signed(current_x1) << 16;
                        seg1_y1 = $signed(current_y1) << 16;
                        seg2_x0 = $signed(next_x0) << 16;
                        seg2_y0 = $signed(next_y0) << 16;
                        seg2_x1 = $signed(next_x1) << 16;
                        seg2_y1 = $signed(next_y1) << 16;
                        // Projection onto segment 1
                        min_proj1 = fp_mult(seg1_x0, dx1) + fp_mult(seg1_y0, dy1);
                        max_proj1 = fp_mult(seg1_x1, dx1) + fp_mult(seg1_y1, dy1);
                        proj1 = fp_mult(seg2_x0, dx1) + fp_mult(seg2_y0, dy1);
                        proj2 = fp_mult(seg2_x1, dx1) + fp_mult(seg2_y1, dy1);
                        // Check overlap
                        is_overlap = (proj1 <= max_proj1 && proj2 >= min_proj1) || (proj2 <= max_proj1 && proj1 >= min_proj1);
                        if (is_overlap) begin
                            // Check if single point
                            is_single_point = (proj1 == proj2) || (proj1 == min_proj1) || (proj1 == max_proj1) || (proj2 == min_proj1) || (proj2 == max_proj1);
                            if (is_single_point) begin
                                // Calculate intersection point
                                intersection_x = seg2_x0;
                                intersection_y = seg2_y0;
                                process_state <= UPDATE_RESULT;
                            end else begin
                                error <= 1;
                                process_state <= PROCESS;
                                pair_index <= pair_index + 1;
                            end
                        end else begin
                            process_state <= PROCESS;
                            pair_index <= pair_index + 1;
                        end
                    end else begin
                        process_state <= PROCESS;
                        pair_index <= pair_index + 1;
                    end
                end
                CALC_INTERSECTION: begin
                    // Calculate intersection using parametric equations
                    t_numerator = fp_mult((next_x0 - current_x0), dy2) - fp_mult((next_y0 - current_y0), dx2);
                    t_denominator = determinant;
                    t = fp_div(t_numerator, t_denominator);
                    u_numerator = fp_mult((next_x0 - current_x0), dy1) - fp_mult((next_y0 - current_y0), dx1);
                    u_denominator = determinant;
                    u = fp_div(u_numerator, u_denominator);
                    process_state <= VERIFY_BOUNDS;
                end
                VERIFY_BOUNDS: begin
                    // Check if intersection lies within both segments
                    if (t >= 0 && t <= (1 << 16) && u >= 0 && u <= (1 << 16)) begin
                        // Calculate intersection point
                        intersection_x = $signed(current_x0) << 16 + fp_mult(t, dx1);
                        intersection_y = $signed(current_y0) << 16 + fp_mult(t, dy1);
                        process_state <= UPDATE_RESULT;
                    end else begin
                        process_state <= PROCESS;
                        pair_index <= pair_index + 1;
                    end
                end
                UPDATE_RESULT: begin
                    // Check if intersection point is unique
                    reg [31:0] new_point;
                    reg is_unique;
                    integer k;
                    new_point = {intersection_x[15:0], intersection_y[15:0]};
                    is_unique = 1;
                    for (k = 0; k < found_count; k = k + 1) begin
                        diff_x = $signed(new_point[31:16]) - $signed(found_intersections[k][31:16]);
                        diff_y = $signed(new_point[15:0]) - $signed(found_intersections[k][15:0]);
                        abs_diff_x = diff_x >= 0 ? diff_x : -diff_x;
                        abs_diff_y = diff_y >= 0 ? diff_y : -diff_y;
                        threshold = 1 << 8; // Threshold for Q8.8 comparison
                        if (abs_diff_x < threshold && abs_diff_y < threshold) begin
                            is_unique = 0;
                        end
                    end
                    if (is_unique) begin
                        found_intersections[found_count] = new_point;
                        found_count <= found_count + 1;
                        result <= result + 1;
                    end
                    process_state <= PROCESS;
                    pair_index <= pair_index + 1;
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    process_state <= IDLE;
                end
            endcase
        end
    end

endmodule