module digit_sum_binary(
    input clk,
    input rst_n,
    input start,
    input [13:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] DIVIDE  = 3'd1;
    localparam [2:0] SUM     = 3'd2;
    localparam [2:0] CONVERT = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Registers
    reg [2:0] state;
    reg [13:0] quotient;
    reg [5:0] sum_reg;
    reg [3:0] digit;
    reg [2:0] digit_counter;
    reg [2:0] convert_bit;
    reg [7:0] result_temp;
    reg [7:0] cycle_count;
    
    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            quotient <= 14'd0;
            sum_reg <= 6'd0;
            digit <= 4'd0;
            digit_counter <= 3'd0;
            convert_bit <= 3'd0;
            result_temp <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        quotient <= n_in;
                        sum_reg <= 6'd0;
                        digit_counter <= 3'd0;
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Division by 10 using repeated subtraction
                    // quotient = quotient / 10, digit = remainder
                    if (quotient >= 14'd10) begin
                        quotient <= quotient - 14'd10;
                        // Don't update digit yet, will be set in SUM state
                    end else begin
                        // quotient < 10, this is the digit
                        digit <= quotient[3:0];
                        state <= SUM;
                    end
                end

                SUM: begin
                    // Add digit to sum
                    sum_reg <= sum_reg + {2'b00, digit};
                    digit_counter <= digit_counter + 3'd1;
                    
                    // Check if we need more digits
                    if (quotient >= 14'd10) begin
                        quotient <= quotient - 14'd10;
                        state <= DIVIDE;
                    end else if (digit_counter < 3'd4) begin
                        // We found a digit, but need to continue checking for more
                        // The current quotient is the last digit if < 10
                        if (quotient < 14'd10) begin
                            digit <= quotient[3:0];
                            // Continue summing
                            if (digit_counter < 3'd4) begin
                                state <= SUM;
                            end else begin
                                state <= CONVERT;
                            end
                        end else begin
                            // Still need division
                            state <= DIVIDE;
                        end
                    end else begin
                        // Maximum digits processed
                        state <= CONVERT;
                    end
                    
                    // Early exit condition: if quotient < 10 and we've processed enough
                    if (quotient < 14'd10 && digit_counter >= 3'd4) begin
                        state <= CONVERT;
                    end
                end

                CONVERT: begin
                    // Convert 6-bit sum to 8-bit binary (right-aligned)
                    // This is already binary, just need to place in result
                    result_temp <= {2'b00, sum_reg};
                    state <= DONE;
                end

                DONE: begin
                    result <= result_temp;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule