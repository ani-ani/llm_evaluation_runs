module largest_proper_divisor(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ZERO = 3'd1;
    localparam [2:0] CHECK_ONE = 3'd2;
    localparam [2:0] SEARCH = 3'd3;
    localparam [2:0] FOUND = 3'd4;
    localparam [2:0] NOT_FOUND = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] divisor_reg;  // Current divisor being tested (counts down from n-1)
    reg [15:0] n_reg;        // Stored input value
    reg [15:0] remainder_reg; // For modulo calculation
    reg [15:0] count_reg;    // Counter for modulo operation
    reg [15:0] result_reg;   // Temporary result storage
    reg modulo_done;         // Flag for modulo completion
    reg modulo_valid;        // Flag for valid modulo result

    // Combinational outputs for modulo operation
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg mod_start;
    reg mod_busy;

    always @(*) begin
        // Default values
        quotient = 16'd0;
        remainder = n_reg;
        mod_busy = 1'b0;
        mod_start = 1'b0;

        if (state == SEARCH && !modulo_done) begin
            mod_busy = 1'b1;
            // Perform modulo: n % divisor_reg using repeated subtraction
            // This is a combinational calculation for one iteration
            if (n_reg >= divisor_reg) begin
                remainder = n_reg - divisor_reg;
                quotient = 16'd1;
            end else begin
                remainder = n_reg;
                quotient = 16'd0;
            end
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            divisor_reg <= 16'd0;
            n_reg <= 16'd0;
            remainder_reg <= 16'd0;
            count_reg <= 16'd0;
            result_reg <= 16'd0;
            modulo_done <= 1'b0;
            modulo_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= CHECK_ZERO;
                    end
                end

                CHECK_ZERO: begin
                    if (n_reg == 16'd0) begin
                        // n = 0: result = 0
                        result_reg <= 16'd0;
                        state <= FINISH;
                    end else begin
                        state <= CHECK_ONE;
                    end
                end

                CHECK_ONE: begin
                    if (n_reg == 16'd1) begin
                        // n = 1: result = 0
                        result_reg <= 16'd0;
                        state <= FINISH;
                    end else begin
                        // Start searching from n-1 down to 1
                        divisor_reg <= n_reg - 16'd1;
                        modulo_done <= 1'b0;
                        modulo_valid <= 1'b0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (modulo_done) begin
                        if (modulo_valid) begin
                            // Found a divisor
                            result_reg <= divisor_reg;
                            state <= FOUND;
                        end else begin
                            // Try next divisor
                            if (divisor_reg > 16'd1) begin
                                divisor_reg <= divisor_reg - 16'd1;
                                modulo_done <= 1'b0;
                                modulo_valid <= 1'b0;
                            end else begin
                                // Reached 1, no divisor found (prime number)
                                // For n > 1, 1 is always a divisor, but we need proper divisor
                                // Actually for prime numbers, result should be 1
                                result_reg <= 16'd1;
                                state <= NOT_FOUND;
                            end
                        end
                    end else begin
                        // Perform modulo check in next cycle
                        // Check if n_reg % divisor_reg == 0
                        // Simple division by repeated subtraction for remainder
                        if (n_reg >= divisor_reg) begin
                            remainder_reg <= n_reg - divisor_reg;
                            count_reg <= 16'd1;
                        end else begin
                            remainder_reg <= n_reg;
                            count_reg <= 16'd0;
                        end
                        modulo_done <= 1'b1;
                        // Check if remainder is 0
                        modulo_valid <= (remainder_reg == 16'd0);
                    end
                end

                FOUND: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                NOT_FOUND: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule