module average_cubes(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DIVIDE  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] n_reg;
    reg [35:0] sum;
    reg [35:0] dividend;
    reg [7:0] divisor;
    reg [31:0] quotient;
    reg [7:0] i;
    reg [7:0] shift_count;
    reg [35:0] remainder;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            n_reg <= 8'd0;
            sum <= 36'd0;
            dividend <= 36'd0;
            divisor <= 8'd0;
            quotient <= 32'd0;
            i <= 8'd0;
            shift_count <= 8'd0;
            remainder <= 36'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        sum <= 36'd0;
                        i <= 8'd0;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    if (i < n_reg) begin
                        // Compute i^3 and add to sum
                        reg [35:0] cube;
                        cube = i * i * i;
                        sum <= sum + cube;
                        i <= i + 8'd1;
                        next_state <= COMPUTE;
                    end else begin
                        // Prepare for division
                        dividend <= sum << 16;  // Q32.32 format
                        divisor <= n_reg;
                        quotient <= 32'd0;
                        remainder <= dividend;
                        shift_count <= 8'd0;
                        next_state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (shift_count < 32) begin
                        // Shift remainder left by 1
                        remainder <= remainder << 1;
                        quotient <= quotient << 1;

                        // Subtract divisor if possible
                        if (remainder[35:8] >= divisor) begin
                            remainder[35:8] <= remainder[35:8] - divisor;
                            quotient[0] <= 1'b1;
                        end

                        shift_count <= shift_count + 8'd1;
                        next_state <= DIVIDE;
                    end else begin
                        // Rounding: add 0.5 (0x8000 in Q16.16)
                        quotient <= quotient + 16'd32768;
                        result <= quotient[31:0];
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
endmodule