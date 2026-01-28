module ElementWiseDivision (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] numerator [0:7],
    input wire [15:0] denominator [0:7],
    input wire [2:0] len,
    output reg [31:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] DIVIDE = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] index, next_index;
    reg [31:0] quotient, next_quotient;
    reg [31:0] remainder, next_remainder;
    reg [31:0] divisor_reg, next_divisor_reg;
    reg [31:0] result_reg [0:7];
    reg done_reg, next_done_reg;

    // Division counter (for 16 iterations for Q16.16)
    reg [4:0] div_cnt, next_div_cnt;

    // Temporary arrays for wire assignments
    reg [31:0] temp_numerator;
    reg [31:0] temp_denominator;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            divisor_reg <= 32'd0;
            done_reg <= 1'b0;
            div_cnt <= 5'd0;
            // Initialize result array
            result_reg[0] <= 32'd0;
            result_reg[1] <= 32'd0;
            result_reg[2] <= 32'd0;
            result_reg[3] <= 32'd0;
            result_reg[4] <= 32'd0;
            result_reg[5] <= 32'd0;
            result_reg[6] <= 32'd0;
            result_reg[7] <= 32'd0;
        end else begin
            state <= next_state;
            index <= next_index;
            quotient <= next_quotient;
            remainder <= next_remainder;
            divisor_reg <= next_divisor_reg;
            done_reg <= next_done_reg;
            div_cnt <= next_div_cnt;
            result_reg[0] <= result[0];
            result_reg[1] <= result[1];
            result_reg[2] <= result[2];
            result_reg[3] <= result[3];
            result_reg[4] <= result[4];
            result_reg[5] <= result[5];
            result_reg[6] <= result[6];
            result_reg[7] <= result[7];
        end
    end

    // Combinational logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_quotient = quotient;
        next_remainder = remainder;
        next_divisor_reg = divisor_reg;
        next_done_reg = done_reg;
        next_div_cnt = div_cnt;
        done = done_reg;

        // Result array default (keep current values)
        result[0] = result_reg[0];
        result[1] = result_reg[1];
        result[2] = result_reg[2];
        result[3] = result_reg[3];
        result[4] = result_reg[4];
        result[5] = result_reg[5];
        result[6] = result_reg[6];
        result[7] = result_reg[7];

        case (state)
            IDLE: begin
                next_done_reg = 1'b0;
                next_index = 3'd0;
                next_div_cnt = 5'd0;
                if (start) begin
                    if (len == 3'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = DIVIDE;
                    end
                end
            end

            DIVIDE: begin
                // Check for division by zero or invalid length
                if (index >= len || denominator[index] == 16'd0) begin
                    if (index >= len) begin
                        next_state = FINISH;
                    end else begin
                        // Division by zero: saturate to max
                        next_state = UPDATE;
                        next_quotient = 32'h7FFFFFFF;
                        next_div_cnt = 5'd16; // Mark as complete
                    end
                end else begin
                    if (div_cnt == 5'd0) begin
                        // Initialize division
                        next_divisor_reg = {16'd0, denominator[index]};
                        next_quotient = 32'd0;
                        next_remainder = {16'd0, numerator[index]};
                        next_div_cnt = 5'd1;
                    end else if (div_cnt <= 5'd16) begin
                        // Restore algorithm for Q16.16
                        if (remainder >= divisor_reg) begin
                            next_remainder = remainder - divisor_reg;
                            next_quotient = (quotient << 1) | 1'b1;
                        end else begin
                            next_quotient = quotient << 1;
                        end
                        next_remainder = remainder << 1;
                        next_div_cnt = div_cnt + 5'd1;
                    end else begin
                        next_state = UPDATE;
                    end
                end
            end

            UPDATE: begin
                // Store result
                case (index)
                    3'd0: result[0] = next_quotient;
                    3'd1: result[1] = next_quotient;
                    3'd2: result[2] = next_quotient;
                    3'd3: result[3] = next_quotient;
                    3'd4: result[4] = next_quotient;
                    3'd5: result[5] = next_quotient;
                    3'd6: result[6] = next_quotient;
                    3'd7: result[7] = next_quotient;
                endcase

                if (index + 3'd1 >= len) begin
                    next_state = FINISH;
                end else begin
                    next_index = index + 3'd1;
                    next_div_cnt = 5'd0;
                    next_state = DIVIDE;
                end
            end

            FINISH: begin
                next_done_reg = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule