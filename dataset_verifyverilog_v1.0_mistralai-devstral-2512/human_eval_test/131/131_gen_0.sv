module odd_digit_product(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] MULTIPLY = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] current_num;
    reg [3:0] digit;
    reg [15:0] product;
    reg [3:0] digit_count;
    reg [15:0] temp_num;
    reg [3:0] i;
    reg [15:0] remainder;
    reg [15:0] quotient;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_num <= 16'd0;
            digit <= 4'd0;
            product <= 16'd1;
            digit_count <= 4'd0;
            temp_num <= 16'd0;
            i <= 4'd0;
            remainder <= 16'd0;
            quotient <= 16'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 4'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        current_num <= n_in;
                        product <= 16'd1;
                        digit_count <= 4'd0;
                        next_state <= EXTRACT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                EXTRACT: begin
                    // Extract digit using modulus 10
                    temp_num <= current_num;
                    remainder <= 16'd0;
                    quotient <= 16'd0;
                    i <= 4'd0;

                    // Modulus 10 calculation
                    for (i = 0; i < 16; i = i + 1) begin
                        if (temp_num >= 10) begin
                            temp_num <= temp_num - 10;
                            quotient <= quotient + 1;
                        end
                    end
                    remainder <= temp_num;
                    digit <= remainder;
                    current_num <= quotient;

                    // Check if digit is odd
                    if (digit[0] == 1'b1) begin
                        product <= product * digit;
                    end

                    digit_count <= digit_count + 4'd1;

                    // Check if all digits processed
                    if (current_num == 16'd0 || digit_count >= 4'd6) begin
                        next_state <= MULTIPLY;
                    end else begin
                        next_state <= EXTRACT;
                    end
                end

                MULTIPLY: begin
                    // Check if any odd digits were found
                    if (product == 16'd1) begin
                        result <= 16'd0;
                    end else begin
                        result <= product;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule