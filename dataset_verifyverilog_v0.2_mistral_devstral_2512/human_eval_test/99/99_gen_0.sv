module closest_integer(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] str_data,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        PARSE_SIGN,
        PARSE_INT,
        PARSE_FRAC,
        CALCULATE,
        ROUND,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [15:0] integer_part;
    reg [15:0] fractional_part;
    reg sign;
    reg [2:0] char_index;
    reg [15:0] temp_result;
    reg [15:0] remainder;
    reg [15:0] q16_value;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            integer_part <= 16'd0;
            fractional_part <= 16'd0;
            sign <= 1'b0;
            char_index <= 3'd0;
            result <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_SIGN;
            end
            PARSE_SIGN: begin
                next_state = PARSE_INT;
            end
            PARSE_INT: begin
                if (char_index == 3'd7 || str_data[char_index] == 8'd46) begin
                    next_state = PARSE_FRAC;
                end else if (str_data[char_index] == 8'd0) begin
                    next_state = CALCULATE;
                end
            end
            PARSE_FRAC: begin
                if (char_index == 3'd7 || str_data[char_index] == 8'd0) begin
                    next_state = CALCULATE;
                end
            end
            CALCULATE: begin
                next_state = ROUND;
            end
            ROUND: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Parsing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer_part <= 16'd0;
            fractional_part <= 16'd0;
            sign <= 1'b0;
            char_index <= 3'd0;
        end else begin
            case (state)
                PARSE_SIGN: begin
                    if (str_data[0] == 8'd45) begin
                        sign <= 1'b1;
                        char_index <= 3'd1;
                    end else begin
                        sign <= 1'b0;
                        char_index <= 3'd0;
                    end
                end
                PARSE_INT: begin
                    if (str_data[char_index] != 8'd46 && str_data[char_index] != 8'd0) begin
                        integer_part <= integer_part * 10 + (str_data[char_index] - 8'd48);
                        char_index <= char_index + 1;
                    end
                end
                PARSE_FRAC: begin
                    if (str_data[char_index] != 8'd0) begin
                        fractional_part <= fractional_part * 10 + (str_data[char_index] - 8'd48);
                        char_index <= char_index + 1;
                    end
                end
            endcase
        end
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q16_value <= 16'd0;
            temp_result <= 16'd0;
            remainder <= 16'd0;
        end else begin
            case (state)
                CALCULATE: begin
                    // Convert to Q16.16
                    q16_value <= integer_part * 65536 + (fractional_part * 65536) / 100;
                end
                ROUND: begin
                    // Extract fractional part
                    remainder <= q16_value[15:0];
                    temp_result <= q16_value[31:16];
                    
                    // Rounding logic
                    if (remainder >= 32768) begin
                        if (sign) begin
                            temp_result <= temp_result - 1;
                        end else begin
                            temp_result <= temp_result + 1;
                        end
                    end
                    
                    // Apply sign
                    if (sign) begin
                        result <= -temp_result;
                    end else begin
                        result <= temp_result;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule