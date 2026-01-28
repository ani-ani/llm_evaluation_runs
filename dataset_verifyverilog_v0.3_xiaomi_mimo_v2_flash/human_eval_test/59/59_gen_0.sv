module largest_prime_factor (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE             = 3'd0;
    localparam [2:0] INIT             = 3'd1;
    localparam [2:0] CHECK_LOOP_CONDITION = 3'd2;
    localparam [2:0] FACTOR_CHECK     = 3'd3;
    localparam [2:0] DIVIDE           = 3'd4;
    localparam [2:0] INCREMENT        = 3'd5;
    localparam [2:0] FINAL_CHECK      = 3'd6;
    localparam [2:0] DONE_STATE       = 3'd7;

    reg [2:0] state, next_state;
    reg [31:0] temp_n, factor, max_factor;
    reg [31:0] factor_sq;
    reg [31:0] next_temp_n, next_factor, next_max_factor;
    
    // Registers for arithmetic results
    reg [31:0] div_result, mod_result;
    reg [31:0] mul_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_n <= 32'd0;
            factor <= 32'd0;
            max_factor <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    temp_n <= n;
                    factor <= 32'd2;
                    max_factor <= 32'd1;
                    state <= CHECK_LOOP_CONDITION;
                end

                CHECK_LOOP_CONDITION: begin
                    // Check if factor * factor <= temp_n
                    // We calculate factor * factor here
                    mul_result <= factor * factor;
                    // Next cycle we evaluate
                    state <= FACTOR_CHECK;
                end

                FACTOR_CHECK: begin
                    if (mul_result > temp_n) begin
                        state <= FINAL_CHECK;
                    end else begin
                        // Check if temp_n % factor == 0
                        mod_result <= temp_n % factor;
                        state <= DIVIDE; // We use DIVIDE state to check result
                    end
                end

                DIVIDE: begin
                    if (mod_result == 32'd0) begin
                        // Divisible
                        div_result <= temp_n / factor;
                        temp_n <= temp_n / factor;
                        max_factor <= factor;
                        // Loop back to check same factor again
                        state <= FACTOR_CHECK;
                    end else begin
                        // Not divisible, increment factor
                        factor <= factor + 32'd1;
                        state <= CHECK_LOOP_CONDITION;
                    end
                end

                FINAL_CHECK: begin
                    if (temp_n > 32'd1) begin
                        result <= temp_n;
                    end else begin
                        result <= max_factor;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
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