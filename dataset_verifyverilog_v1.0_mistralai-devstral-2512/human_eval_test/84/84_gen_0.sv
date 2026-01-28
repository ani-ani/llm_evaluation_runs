module digit_sum_binary(
    input clk,
    input rst_n,
    input start,
    input [13:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] DIVIDE  = 3'd1;
    localparam [2:0] SUM     = 3'd2;
    localparam [2:0] CONVERT = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [13:0] quotient;
    reg [3:0] digit;
    reg [5:0] sum_reg;
    reg [2:0] digit_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Digit extraction and sum calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            quotient <= 14'd0;
            digit <= 4'd0;
            sum_reg <= 6'd0;
            digit_count <= 3'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= DIVIDE;
                        quotient <= n_in;
                        sum_reg <= 6'd0;
                        digit_count <= 3'd0;
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Extract digit using modulo 10
                    digit <= quotient % 10;
                    // Update quotient for next digit
                    quotient <= quotient / 10;
                    digit_count <= digit_count + 3'd1;
                    state <= SUM;
                end

                SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    sum_reg <= sum_reg + digit;
                    // Check if all digits processed (max 5 digits)
                    if (digit_count >= 3'd4 || quotient == 14'd0) begin
                        state <= CONVERT;
                    end else begin
                        state <= DIVIDE;
                    end
                end

                CONVERT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Convert sum to binary (right-aligned in 8-bit output)
                    result <= sum_reg[5:0];
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule