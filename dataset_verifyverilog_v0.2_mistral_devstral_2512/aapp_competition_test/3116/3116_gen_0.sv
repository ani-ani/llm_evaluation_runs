module min_cylinder_volume (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_points,
    input [63:0] points [0:7],
    output reg [63:0] min_volume,
    output reg done
);

    // Constants
    localparam PI_Q16 = 64'h3243F; // 3.14159 in Q16.16
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam SEARCH_LOOP = 4'd2;
    localparam TRIPLET_LOOP = 4'd3;
    localparam CALC_NORMAL = 4'd4;
    localparam CALC_PROJECTIONS = 4'd5;
    localparam CALC_RADIUS = 4'd6;
    localparam CALC_VOLUME = 4'd7;
    localparam UPDATE_MIN = 4'd8;
    localparam DONE = 4'd9;

    // State machine
    reg [3:0] state = IDLE;

    // Loop counters
    reg [2:0] i = 0, j = 0, k = 0;
    reg [2:0] point_idx = 0;

    // Intermediate registers
    reg [63:0] normal_x, normal_y, normal_z;
    reg [63:0] proj_min, proj_max;
    reg [63:0] radius_sq, current_volume;
    reg [63:0] temp_x, temp_y, temp_z;
    reg [63:0] temp_proj;

    // Fixed-point arithmetic helpers
    function [63:0] fp_mult;
        input [63:0] a, b;
        begin
            fp_mult = $signed(a) * $signed(b) >>> 16; // Q16.16 * Q16.16 = Q32.32, shift to Q16.16
        end
    endfunction

    function [63:0] fp_div;
        input [63:0] a, b;
        reg [63:0] result;
        reg [63:0] remainder;
        integer i;
        begin
            if (b == 0) begin
                result = 0;
            end else begin
                remainder = a;
                result = 0;
                for (i = 0; i < 32; i = i + 1) begin
                    remainder = remainder << 1;
                    if (remainder[63]) begin
                        remainder = remainder - b;
                        result[i] = 1;
                    end
                end
            end
            fp_div = result;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_volume <= 64'h7FFFFFFF; // Initialize to max value
            i <= 0;
            j <= 0;
            k <= 0;
            point_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end

                INIT: begin
                    min_volume <= 64'h7FFFFFFF;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    point_idx <= 0;
                    state <= SEARCH_LOOP;
                end

                SEARCH_LOOP: begin
                    if (i < num_points - 2) begin
                        j <= i + 1;
                        state <= TRIPLET_LOOP;
                    end else begin
                        state <= DONE;
                    end
                end

                TRIPLET_LOOP: begin
                    if (j < num_points - 1) begin
                        k <= j + 1;
                        state <= CALC_NORMAL;
                    end else begin
                        i <= i + 1;
                        state <= SEARCH_LOOP;
                    end
                end

                CALC_NORMAL: begin
                    // Calculate vectors P2-P1 and P3-P1
                    temp_x = points[j][63:48] - points[i][63:48];
                    temp_y = points[j][47:32] - points[i][47:32];
                    temp_z = points[j][31:16] - points[i][31:16];

                    // Cross product (P2-P1) × (P3-P1)
                    normal_x = fp_mult(points[k][47:32] - points[i][47:32], temp_z) - fp_mult(points[k][31:16] - points[i][31:16], temp_y);
                    normal_y = fp_mult(points[k][31:16] - points[i][31:16], temp_x) - fp_mult(points[k][63:48] - points[i][63:48], temp_z);
                    normal_z = fp_mult(points[k][63:48] - points[i][63:48], temp_y) - fp_mult(points[k][47:32] - points[i][47:32], temp_x);

                    state <= CALC_PROJECTIONS;
                    point_idx <= 0;
                    proj_min <= 64'h7FFFFFFF;
                    proj_max <= 64'h80000000;
                end

                CALC_PROJECTIONS: begin
                    if (point_idx < num_points) begin
                        // Project point onto normal vector
                        temp_proj = fp_mult(points[point_idx][63:48], normal_x) + 
                                   fp_mult(points[point_idx][47:32], normal_y) + 
                                   fp_mult(points[point_idx][31:16], normal_z);

                        if (temp_proj < proj_min) proj_min <= temp_proj;
                        if (temp_proj > proj_max) proj_max <= temp_proj;

                        point_idx <= point_idx + 1;
                    end else begin
                        state <= CALC_RADIUS;
                        point_idx <= 0;
                        radius_sq <= 0;
                    end
                end

                CALC_RADIUS: begin
                    if (point_idx < num_points) begin
                        // Calculate distance from point to line (projection center)
                        temp_x = points[point_idx][63:48] - points[i][63:48];
                        temp_y = points[point_idx][47:32] - points[i][47:32];
                        temp_z = points[point_idx][31:16] - points[i][31:16];

                        // Distance squared = |point - line|^2
                        temp_proj = fp_mult(temp_x, temp_x) + 
                                   fp_mult(temp_y, temp_y) + 
                                   fp_mult(temp_z, temp_z) - 
                                   fp_div(fp_mult(temp_x, normal_x) + 
                                          fp_mult(temp_y, normal_y) + 
                                          fp_mult(temp_z, normal_z), 
                                          fp_mult(normal_x, normal_x) + 
                                          fp_mult(normal_y, normal_y) + 
                                          fp_mult(normal_z, normal_z));

                        if (temp_proj > radius_sq) radius_sq <= temp_proj;

                        point_idx <= point_idx + 1;
                    end else begin
                        state <= CALC_VOLUME;
                    end
                end

                CALC_VOLUME: begin
                    // Volume = π * r^2 * h
                    current_volume <= fp_mult(PI_Q16, radius_sq);
                    current_volume <= fp_mult(current_volume, proj_max - proj_min);
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    if (current_volume < min_volume) begin
                        min_volume <= current_volume;
                    end
                    j <= j + 1;
                    state <= TRIPLET_LOOP;
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule