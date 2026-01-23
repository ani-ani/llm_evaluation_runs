module laser_tag_wall (
    input clk,
    input rst_n,
    input start,
    input [31:0] x1, y1, x2, y2, x3, y3,
    output reg [31:0] y_wall,
    output reg done,
    output reg can_hit
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CALC_MIRROR,
        REFLECT_POINT,
        CALC_INTERSECTION,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers for intermediate calculations
    reg [31:0] A, B, C; // Mirror line coefficients
    reg [31:0] x_image, y_image; // Reflected image point
    reg [31:0] denominator; // For division
    reg [31:0] numerator; // For division
    reg [31:0] temp1, temp2, temp3;
    reg [31:0] count;

    // Division state machine
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [31:0] divisor;
    reg [31:0] dividend;
    reg [4:0] div_step;
    reg div_start;
    reg div_done;

    // State machine for main computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            can_hit <= 0;
            y_wall <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CALC_MIRROR;
            end
            CALC_MIRROR: begin
                next_state = REFLECT_POINT;
            end
            REFLECT_POINT: begin
                next_state = CALC_INTERSECTION;
            end
            CALC_INTERSECTION: begin
                if (div_done) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A <= 0;
            B <= 0;
            C <= 0;
            x_image <= 0;
            y_image <= 0;
            denominator <= 0;
            numerator <= 0;
            temp1 <= 0;
            temp2 <= 0;
            temp3 <= 0;
            count <= 0;
            quotient <= 0;
            remainder <= 0;
            divisor <= 0;
            dividend <= 0;
            div_step <= 0;
            div_start <= 0;
            div_done <= 0;
        end else begin
            case (current_state)
                CALC_MIRROR: begin
                    // Calculate mirror line coefficients
                    A <= y2 - y1;
                    B <= x1 - x2;
                    C <= $signed({x2, 32'h0}) * $signed({y1, 32'h0}) - $signed({x1, 32'h0}) * $signed({y2, 32'h0});
                end
                REFLECT_POINT: begin
                    // Reflect point (x3, y3) across mirror line
                    // temp1 = A*x3 + B*y3 + C
                    temp1 <= $signed({A, 32'h0}) * $signed({x3, 32'h0}) + $signed({B, 32'h0}) * $signed({y3, 32'h0}) + $signed({C, 32'h0});
                    // temp2 = A*A + B*B
                    temp2 <= $signed({A, 32'h0}) * $signed({A, 32'h0}) + $signed({B, 32'h0}) * $signed({B, 32'h0});
                    // x_image = x3 - 2*A*temp1 / temp2
                    // y_image = y3 - 2*B*temp1 / temp2
                    // Start division for x_image
                    dividend <= $signed({$signed({A, 32'h0}) * $signed({temp1, 32'h0}) << 1, 32'h0});
                    divisor <= temp2;
                    div_start <= 1;
                    div_step <= 0;
                    div_done <= 0;
                end
                CALC_INTERSECTION: begin
                    if (div_start) begin
                        // Division state machine
                        if (div_step == 0) begin
                            remainder <= dividend;
                            quotient <= 0;
                            div_step <= 1;
                        end else begin
                            if (div_step < 32) begin
                                remainder <= remainder << 1;
                                quotient <= quotient << 1;
                                if (remainder[32]) begin
                                    remainder <= remainder - divisor;
                                    quotient[0] <= 1;
                                end
                                div_step <= div_step + 1;
                            end else begin
                                div_done <= 1;
                                div_start <= 0;
                                // x_image = x3 - quotient
                                x_image <= x3 - quotient;
                                // Start division for y_image
                                dividend <= $signed({$signed({B, 32'h0}) * $signed({temp1, 32'h0}) << 1, 32'h0});
                                divisor <= temp2;
                                div_start <= 1;
                                div_step <= 0;
                                div_done <= 0;
                            end
                        end
                    end else if (div_done) begin
                        // y_image = y3 - quotient
                        y_image <= y3 - quotient;
                        // Calculate intersection with wall x=0
                        // Line from (x3, y3) to (x_image, y_image)
                        // Parametric equations: x = x3 + t*(x_image - x3), y = y3 + t*(y_image - y3)
                        // At x=0: 0 = x3 + t*(x_image - x3) => t = -x3 / (x_image - x3)
                        // y_wall = y3 + t*(y_image - y3)
                        // Check if x_image == x3 (parallel to wall)
                        if (x_image == x3) begin
                            can_hit <= 0;
                            y_wall <= 32'h7FFFFFFF; // Infinity
                        end else begin
                            // Start division for t
                            dividend <= -$signed({x3, 32'h0});
                            divisor <= x_image - x3;
                            div_start <= 1;
                            div_step <= 0;
                            div_done <= 0;
                        end
                    end else if (div_start) begin
                        // Division state machine for t
                        if (div_step == 0) begin
                            remainder <= dividend;
                            quotient <= 0;
                            div_step <= 1;
                        end else begin
                            if (div_step < 32) begin
                                remainder <= remainder << 1;
                                quotient <= quotient << 1;
                                if (remainder[32]) begin
                                    remainder <= remainder - divisor;
                                    quotient[0] <= 1;
                                end
                                div_step <= div_step + 1;
                            end else begin
                                div_done <= 1;
                                div_start <= 0;
                                // y_wall = y3 + quotient*(y_image - y3)
                                temp1 <= $signed({quotient, 32'h0}) * $signed({y_image - y3, 32'h0});
                                y_wall <= y3 + temp1;
                                can_hit <= 1;
                            end
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    done <= 0;
                    can_hit <= 0;
                    y_wall <= 0;
                end
            endcase
        end
    end

endmodule