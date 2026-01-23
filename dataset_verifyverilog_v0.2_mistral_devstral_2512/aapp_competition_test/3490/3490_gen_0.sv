module witch_collision (
    input clk,
    input rst_n,
    input start,
    input [31:0] x0, y0, r0,
    input [31:0] x1, y1, r1,
    input [31:0] x2, y2, r2,
    input [31:0] x3, y3, r3,
    output reg crash,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PREPARE_TIPS,
        CHECK_COLLISIONS,
        DONE
    } state_t;

    state_t state;
    reg [31:0] tip_x0, tip_y0;
    reg [31:0] tip_x1, tip_y1;
    reg [31:0] tip_x2, tip_y2;
    reg [31:0] tip_x3, tip_y3;
    reg [4:0] pair_counter;
    reg [47:0] cross1, cross2, cross3, cross4;

    // Fixed-point constants
    localparam [31:0] ONE = 32'h00010000; // 1.0 in Q16.16
    localparam [31:0] PI = 32'h0003243F; // 3.1415926535 in Q16.16
    localparam [31:0] PI_OVER_2 = 32'h0001921F; // 1.5707963268 in Q16.16

    // Cosine and sine approximation using piecewise linear approximation
    function [31:0] cos_approx(input [31:0] angle);
        reg [31:0] abs_angle;
        reg [31:0] result;
        reg [31:0] x;
        reg [31:0] x_squared;
        reg [31:0] x_cubed;
        reg [31:0] x_fifth;
        reg [31:0] x_seventh;
        reg [31:0] x_ninth;
        reg [31:0] x_eleventh;
        reg [31:0] x_thirteenth;

        // Reduce angle to [0, PI/2]
        abs_angle = angle[31] ? -angle : angle;
        if (abs_angle > PI_OVER_2)
            abs_angle = PI - abs_angle;

        // Taylor series approximation for cos(x) in [0, PI/2]
        x = abs_angle;
        x_squared = $signed({1{1'b0}, x[31:16]} * {1{1'b0}, x[31:16]}) >> 16;
        x_cubed = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x[31:16]}) >> 16;
        x_fifth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_cubed[31:16]}) >> 16;
        x_seventh = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_fifth[31:16]}) >> 16;
        x_ninth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_seventh[31:16]}) >> 16;
        x_eleventh = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_ninth[31:16]}) >> 16;
        x_thirteenth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_eleventh[31:16]}) >> 16;

        result = ONE - (x_squared >> 1) + (x_fifth >> 5) - (x_ninth >> 9) + (x_thirteenth >> 13);
        cos_approx = result;
    endfunction

    function [31:0] sin_approx(input [31:0] angle);
        reg [31:0] abs_angle;
        reg [31:0] result;
        reg [31:0] x;
        reg [31:0] x_squared;
        reg [31:0] x_cubed;
        reg [31:0] x_fifth;
        reg [31:0] x_seventh;
        reg [31:0] x_ninth;
        reg [31:0] x_eleventh;
        reg [31:0] x_thirteenth;

        // Reduce angle to [0, PI/2]
        abs_angle = angle[31] ? -angle : angle;
        if (abs_angle > PI_OVER_2)
            abs_angle = PI - abs_angle;

        // Taylor series approximation for sin(x) in [0, PI/2]
        x = abs_angle;
        x_squared = $signed({1{1'b0}, x[31:16]} * {1{1'b0}, x[31:16]}) >> 16;
        x_cubed = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x[31:16]}) >> 16;
        x_fifth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_cubed[31:16]}) >> 16;
        x_seventh = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_fifth[31:16]}) >> 16;
        x_ninth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_seventh[31:16]}) >> 16;
        x_eleventh = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_ninth[31:16]}) >> 16;
        x_thirteenth = $signed({1{1'b0}, x_squared[31:16]} * {1{1'b0}, x_eleventh[31:16]}) >> 16;

        result = x - (x_cubed >> 2) + (x_fifth >> 6) - (x_seventh >> 10) + (x_ninth >> 14) - (x_eleventh >> 18) + (x_thirteenth >> 22);
        sin_approx = result;
    endfunction

    // Orientation function (cross product)
    function [47:0] orientation(input [31:0] ax, ay, bx, by, cx, cy);
        orientation = ($signed({1{1'b0}, bx[31:16]} - {1{1'b0}, ax[31:16]}) * 
                      ($signed({1{1'b0}, cy[31:16]} - {1{1'b0}, ay[31:16]}))) - 
                     ($signed({1{1'b0}, by[31:16]} - {1{1'b0}, ay[31:16]}) * 
                      ($signed({1{1'b0}, cx[31:16]} - {1{1'b0}, ax[31:16]})));
    endfunction

    // Check if two line segments intersect
    function reg check_intersection(input [31:0] p1x, p1y, q1x, q1y, p2x, p2y, q2x, q2y);
        reg [47:0] o1, o2, o3, o4;
        o1 = orientation(p1x, p1y, q1x, q1y, p2x, p2y);
        o2 = orientation(p1x, p1y, q1x, q1y, q2x, q2y);
        o3 = orientation(p2x, p2y, q2x, q2y, p1x, p1y);
        o4 = orientation(p2x, p2y, q2x, q2y, q1x, q1y);
        check_intersection = (o1[47] ? 1'b1 : 1'b0) ^ (o2[47] ? 1'b1 : 1'b0) ? 1'b0 : 
                            ((o3[47] ? 1'b1 : 1'b0) ^ (o4[47] ? 1'b1 : 1'b0) ? 1'b0 : 1'b1);
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            crash <= 0;
            done <= 0;
            pair_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREPARE_TIPS;
                        crash <= 0;
                        done <= 0;
                    end
                end
                PREPARE_TIPS: begin
                    // Calculate all broom tips
                    tip_x0 <= x0 + cos_approx(r0);
                    tip_y0 <= y0 + sin_approx(r0);
                    tip_x1 <= x1 + cos_approx(r1);
                    tip_y1 <= y1 + sin_approx(r1);
                    tip_x2 <= x2 + cos_approx(r2);
                    tip_y2 <= y2 + sin_approx(r2);
                    tip_x3 <= x3 + cos_approx(r3);
                    tip_y3 <= y3 + sin_approx(r3);
                    state <= CHECK_COLLISIONS;
                    pair_counter <= 0;
                end
                CHECK_COLLISIONS: begin
                    case (pair_counter)
                        5'd0: begin // Check pair (0,1)
                            crash <= check_intersection(x0, y0, tip_x0, tip_y0, x1, y1, tip_x1, tip_y1);
                            pair_counter <= pair_counter + 1;
                        end
                        5'd1: begin // Check pair (0,2)
                            crash <= crash | check_intersection(x0, y0, tip_x0, tip_y0, x2, y2, tip_x2, tip_y2);
                            pair_counter <= pair_counter + 1;
                        end
                        5'd2: begin // Check pair (0,3)
                            crash <= crash | check_intersection(x0, y0, tip_x0, tip_y0, x3, y3, tip_x3, tip_y3);
                            pair_counter <= pair_counter + 1;
                        end
                        5'd3: begin // Check pair (1,2)
                            crash <= crash | check_intersection(x1, y1, tip_x1, tip_y1, x2, y2, tip_x2, tip_y2);
                            pair_counter <= pair_counter + 1;
                        end
                        5'd4: begin // Check pair (1,3)
                            crash <= crash | check_intersection(x1, y1, tip_x1, tip_y1, x3, y3, tip_x3, tip_y3);
                            pair_counter <= pair_counter + 1;
                        end
                        5'd5: begin // Check pair (2,3)
                            crash <= crash | check_intersection(x2, y2, tip_x2, tip_y2, x3, y3, tip_x3, tip_y3);
                            state <= DONE;
                        end
                    endcase
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule