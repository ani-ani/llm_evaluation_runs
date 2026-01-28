module fuel_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [9:0] m,
    input wire [9:0] a_i_0,
    input wire [9:0] a_i_1,
    input wire [9:0] a_i_2,
    input wire [9:0] a_i_3,
    input wire [9:0] a_i_4,
    input wire [9:0] a_i_5,
    input wire [9:0] a_i_6,
    input wire [9:0] a_i_7,
    input wire [9:0] b_i_0,
    input wire [9:0] b_i_1,
    input wire [9:0] b_i_2,
    input wire [9:0] b_i_3,
    input wire [9:0] b_i_4,
    input wire [9:0] b_i_5,
    input wire [9:0] b_i_6,
    input wire [9:0] b_i_7,
    output reg [63:0] fuel,
    output reg done,
    output reg impossible
);

    localparam [3:0] MAX_PLANETS = 4'd8;
    localparam [9:0] MAX_DATA = 10'd1000;
    localparam [5:0] DATA_WIDTH = 6'd10;
    localparam [5:0] FIXED_POINT_WIDTH = 6'd64;
    localparam [5:0] INT_BITS = 6'd32;
    localparam [5:0] FRAC_BITS = 6'd32;

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK = 4'd1;
    localparam [3:0] COMPUTE_A = 4'd2;
    localparam [3:0] COMPUTE_B = 4'd3;
    localparam [3:0] MULTIPLY = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;
    reg [63:0] product;
    reg [63:0] temp_result;
    reg [9:0] current_a, current_b;
    reg [4:0] planet_index;
    reg [4:0] cycle_count;
    reg [5:0] div_cycle;
    reg [63:0] dividend, divisor;
    reg [63:0] quotient;
    reg [63:0] remainder;
    reg [63:0] multiplier;
    reg [63:0] m_fixed;
    reg [63:0] one_fixed;
    reg [63:0] a_minus_one, b_minus_one;
    reg [63:0] a_div, b_div;
    reg [63:0] a_div_result, b_div_result;
    reg [63:0] a_product, b_product;
    reg [63:0] final_product;
    reg [63:0] final_fuel;
    reg [63:0] temp_mult;
    reg [63:0] temp_div;
    reg [63:0] temp_quotient;
    reg [63:0] temp_remainder;
    reg [63:0] temp_divisor;
    reg [63:0] temp_dividend;
    reg [63:0] temp_multiplier;
    reg [63:0] temp_a_div, temp_b_div;
    reg [63:0] temp_a_product, temp_b_product;
    reg [63:0] temp_final_product;
    reg [63:0] temp_final_fuel;
    reg [63:0] temp_product;
    reg [63:0] temp_temp_result;
    reg [9:0] temp_current_a, temp_current_b;
    reg [4:0] temp_planet_index;
    reg [4:0] temp_cycle_count;
    reg [5:0] temp_div_cycle;
    reg [63:0] temp_dividend, temp_divisor;
    reg [63:0] temp_quotient;
    reg [63:0] temp_remainder;
    reg [63:0] temp_multiplier;
    reg [63:0] temp_m_fixed;
    reg [63:0] temp_one_fixed;
    reg [63:0] temp_a_minus_one, temp_b_minus_one;
    reg [63:0] temp_a_div, temp_b_div;
    reg [63:0] temp_a_div_result, temp_b_div_result;
    reg [63:0] temp_a_product, temp_b_product;
    reg [63:0] temp_final_product;
    reg [63:0] temp_final_fuel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            product <= 64'd0;
            temp_result <= 64'd0;
            current_a <= 10'd0;
            current_b <= 10'd0;
            planet_index <= 5'd0;
            cycle_count <= 5'd0;
            div_cycle <= 6'd0;
            dividend <= 64'd0;
            divisor <= 64'd0;
            quotient <= 64'd0;
            remainder <= 64'd0;
            multiplier <= 64'd0;
            m_fixed <= 64'd0;
            one_fixed <= 64'd0;
            a_minus_one <= 64'd0;
            b_minus_one <= 64'd0;
            a_div <= 64'd0;
            b_div <= 64'd0;
            a_div_result <= 64'd0;
            b_div_result <= 64'd0;
            a_product <= 64'd0;
            b_product <= 64'd0;
            final_product <= 64'd0;
            final_fuel <= 64'd0;
            temp_mult <= 64'd0;
            temp_div <= 64'd0;
            temp_quotient <= 64'd0;
            temp_remainder <= 64'd0;
            temp_divisor <= 64'd0;
            temp_dividend <= 64'd0;
            temp_multiplier <= 64'd0;
            temp_a_div <= 64'd0;
            temp_b_div <= 64'd0;
            temp_a_product <= 64'd0;
            temp_b_product <= 64'd0;
            temp_final_product <= 64'd0;
            temp_final_fuel <= 64'd0;
            temp_product <= 64'd0;
            temp_temp_result <= 64'd0;
            temp_current_a <= 10'd0;
            temp_current_b <= 10'd0;
            temp_planet_index <= 5'd0;
            temp_cycle_count <= 5'd0;
            temp_div_cycle <= 6'd0;
            temp_dividend <= 64'd0;
            temp_divisor <= 64'd0;
            temp_quotient <= 64'd0;
            temp_remainder <= 64'd0;
            temp_multiplier <= 64'd0;
            temp_m_fixed <= 64'd0;
            temp_one_fixed <= 64'd0;
            temp_a_minus_one <= 64'd0;
            temp_b_minus_one <= 64'd0;
            temp_a_div <= 64'd0;
            temp_b_div <= 64'd0;
            temp_a_div_result <= 64'd0;
            temp_b_div_result <= 64'd0;
            temp_a_product <= 64'd0;
            temp_b_product <= 64'd0;
            temp_final_product <= 64'd0;
            temp_final_fuel <= 64'd0;
            fuel <= 64'd0;
            done <= 1'b0;
            impossible <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                CHECK: begin
                    if (n == 4'd0) begin
                        next_state <= IDLE;
                    end else begin
                        if (a_i_0 <= 10'd1 || b_i_0 <= 10'd1 ||
                            a_i_1 <= 10'd1 || b_i_1 <= 10'd1 ||
                            a_i_2 <= 10'd1 || b_i_2 <= 10'd1 ||
                            a_i_3 <= 10'd1 || b_i_3 <= 10'd1 ||
                            a_i_4 <= 10'd1 || b_i_4 <= 10'd1 ||
                            a_i_5 <= 10'd1 || b_i_5 <= 10'd1 ||
                            a_i_6 <= 10'd1 || b_i_6 <= 10'd1 ||
                            a_i_7 <= 10'd1 || b_i_7 <= 10'd1) begin
                            impossible <= 1'b1;
                            next_state <= DONE_STATE;
                        end else begin
                            impossible <= 1'b0;
                            next_state <= COMPUTE_A;
                        end
                    end
                end
                COMPUTE_A: begin
                    if (planet_index < n) begin
                        case (planet_index)
                            5'd0: current_a <= a_i_0;
                            5'd1: current_a <= a_i_1;
                            5'd2: current_a <= a_i_2;
                            5'd3: current_a <= a_i_3;
                            5'd4: current_a <= a_i_4;
                            5'd5: current_a <= a_i_5;
                            5'd6: current_a <= a_i_6;
                            5'd7: current_a <= a_i_7;
                            default: current_a <= 10'd0;
                        endcase
                        a_minus_one <= {54'd0, current_a} - 64'd1;
                        dividend <= {54'd0, current_a};
                        divisor <= a_minus_one;
                        quotient <= 64'd0;
                        remainder <= 64'd0;
                        div_cycle <= 6'd0;
                        next_state <= COMPUTE_A;
                    end else begin
                        next_state <= COMPUTE_B;
                    end
                end
                COMPUTE_B: begin
                    if (planet_index < n) begin
                        case (planet_index)
                            5'd0: current_b <= b_i_0;
                            5'd1: current_b <= b_i_1;
                            5'd2: current_b <= b_i_2;
                            5'd3: current_b <= b_i_3;
                            5'd4: current_b <= b_i_4;
                            5'd5: current_b <= b_i_5;
                            5'd6: current_b <= b_i_6;
                            5'd7: current_b <= b_i_7;
                            default: current_b <= 10'd0;
                        endcase
                        b_minus_one <= {54'd0, current_b} - 64'd1;
                        dividend <= {54'd0, current_b};
                        divisor <= b_minus_one;
                        quotient <= 64'd0;
                        remainder <= 64'd0;
                        div_cycle <= 6'd0;
                        next_state <= COMPUTE_B;
                    end else begin
                        next_state <= MULTIPLY;
                    end
                end
                MULTIPLY: begin
                    if (planet_index < n) begin
                        case (planet_index)
                            5'd0: begin
                                a_div_result <= a_div;
                                b_div_result <= b_div;
                            end
                            5'd1: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd2: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd3: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd4: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd5: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd6: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            5'd7: begin
                                a_div_result <= a_div_result * a_div;
                                b_div_result <= b_div_result * b_div;
                            end
                            default: begin
                                a_div_result <= 64'd0;
                                b_div_result <= 64'd0;
                            end
                        endcase
                        planet_index <= planet_index + 5'd1;
                        next_state <= MULTIPLY;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                default: next_state <= IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        if (state == COMPUTE_A || state == COMPUTE_B) begin
            if (div_cycle < 6'd64) begin
                if (remainder[63] == 1'b0) begin
                    remainder <= remainder << 1;
                    remainder[0] <= dividend[63];
                    dividend <= dividend << 1;
                end else begin
                    remainder <= (remainder << 1) - divisor;
                    remainder[0] <= dividend[63];
                    dividend <= dividend << 1;
                    quotient[0] <= 1'b1;
                end
                quotient <= quotient << 1;
                div_cycle <= div_cycle + 6'd1;
            end else begin
                if (state == COMPUTE_A) begin
                    a_div <= quotient;
                    planet_index <= planet_index + 5'd1;
                end else begin
                    b_div <= quotient;
                    planet_index <= planet_index + 5'd1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (state == MULTIPLY) begin
            if (planet_index < n) begin
                case (planet_index)
                    5'd0: begin
                        a_product <= a_div;
                        b_product <= b_div;
                    end
                    5'd1: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd2: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd3: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd4: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd5: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd6: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    5'd7: begin
                        a_product <= a_product * a_div;
                        b_product <= b_product * b_div;
                    end
                    default: begin
                        a_product <= 64'd0;
                        b_product <= 64'd0;
                    end
                endcase
            end else begin
                final_product <= a_product * b_product;
                m_fixed <= {54'd0, m};
                final_fuel <= final_product - m_fixed;
                fuel <= final_fuel;
            end
        end
    end

endmodule