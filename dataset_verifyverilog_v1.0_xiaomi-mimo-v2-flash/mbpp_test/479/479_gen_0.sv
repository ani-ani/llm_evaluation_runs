module find_first_digit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] number_in,
    output reg [3:0] first_digit,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] DIVIDE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] current_value;
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg [3:0] iteration_count;
    reg [3:0] temp_digit;
    reg [15:0] divisor;
    reg [15:0] dividend;
    reg [2:0] div_state;

    // Division state machine (for /10 using repeated subtraction)
    localparam [2:0] DIV_IDLE = 3'd0;
    localparam [2:0] DIV_SUB = 3'd1;
    localparam [2:0] DIV_COUNT = 3'd2;
    localparam [2:0] DIV_DONE = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 16'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            iteration_count <= 4'd0;
            first_digit <= 4'd0;
            done <= 1'b0;
            div_state <= DIV_IDLE;
            divisor <= 16'd0;
            dividend <= 16'd0;
            temp_digit <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD: begin
                    current_value <= number_in;
                    iteration_count <= 4'd0;
                    state <= DIVIDE;
                    div_state <= DIV_IDLE;
                end

                DIVIDE: begin
                    case (div_state)
                        DIV_IDLE: begin
                            divisor <= 16'd10;
                            dividend <= current_value;
                            quotient <= 16'd0;
                            remainder <= current_value;
                            if (current_value < 16'd10) begin
                                div_state <= DIV_DONE;
                            end else begin
                                div_state <= DIV_SUB;
                            end
                        end

                        DIV_SUB: begin
                            if (remainder >= divisor) begin
                                remainder <= remainder - divisor;
                                quotient <= quotient + 16'd1;
                            end else begin
                                div_state <= DIV_DONE;
                            end
                        end

                        DIV_DONE: begin
                            current_value <= quotient;
                            iteration_count <= iteration_count + 4'd1;
                            state <= CHECK;
                        end

                        default: div_state <= DIV_IDLE;
                    endcase
                end

                CHECK: begin
                    if (current_value < 16'd10) begin
                        temp_digit <= current_value[3:0];
                        state <= DONE;
                    end else if (iteration_count >= 4'd10) begin
                        // Safety timeout (should not happen for 16-bit)
                        temp_digit <= current_value[3:0];
                        state <= DONE;
                    end else begin
                        state <= DIVIDE;
                        div_state <= DIV_IDLE;
                    end
                end

                DONE: begin
                    first_digit <= temp_digit;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule