module ArmstrongChecker (
    input clk,
    input rst_n,
    input start,
    input [15:0] number,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] COUNT_DIGITS   = 3'd1;
    localparam [2:0] CALCULATE_SUM  = 3'd2;
    localparam [2:0] DONE_STATE     = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] number_reg;          // Store original number
    reg [15:0] temp_value;          // For digit extraction
    reg [3:0] digit_count;          // Number of digits (1-5)
    reg [3:0] current_digit;        // Current digit being processed
    reg [3:0] power_counter;        // Counter for power calculation
    reg [31:0] sum;                 // Accumulated sum of powered digits
    reg [31:0] power_result;        // Temporary for digit^digit_count
    reg [3:0] cycle_counter;        // To prevent infinite loops
    
    // Control flags
    reg counting_done;
    reg calculation_done;
    reg power_calc_done;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 1'b0;
            done <= 1'b0;
            number_reg <= 16'd0;
            temp_value <= 16'd0;
            digit_count <= 4'd0;
            current_digit <= 4'd0;
            power_counter <= 4'd0;
            sum <= 32'd0;
            power_result <= 32'd0;
            cycle_counter <= 4'd0;
            counting_done <= 1'b0;
            calculation_done <= 1'b0;
            power_calc_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        number_reg <= number;
                        temp_value <= number;
                        digit_count <= 4'd0;
                        sum <= 32'd0;
                        cycle_counter <= 4'd0;
                        counting_done <= 1'b0;
                        calculation_done <= 1'b0;
                        power_calc_done <= 1'b0;
                    end
                end

                COUNT_DIGITS: begin
                    if (!counting_done && temp_value > 0 && cycle_counter < 4'd5) begin
                        temp_value <= temp_value / 10;  // Integer division by 10
                        digit_count <= digit_count + 4'd1;
                        cycle_counter <= cycle_counter + 4'd1;
                    end else begin
                        // Edge case: number is 0
                        if (number_reg == 16'd0 && !counting_done) begin
                            digit_count <= 4'd1;
                        end
                        counting_done <= 1'b1;
                    end
                end

                CALCULATE_SUM: begin
                    if (!calculation_done) begin
                        if (!power_calc_done) begin
                            // Initialize power calculation for current digit
                            if (power_counter == 4'd0) begin
                                current_digit <= number_reg % 10;  // Extract last digit
                                power_result <= 32'd1;  // Start with 1 for multiplication
                                power_counter <= 4'd0;
                            end
                            
                            // Iterative multiplication for power
                            if (power_counter < digit_count) begin
                                power_result <= power_result * current_digit;
                                power_counter <= power_counter + 4'd1;
                            end else begin
                                power_calc_done <= 1'b1;
                                power_counter <= 4'd0;
                            end
                        end else begin
                            // Add powered digit to sum
                            sum <= sum + power_result;
                            power_calc_done <= 1'b0;
                            
                            // Move to next digit
                            number_reg <= number_reg / 10;
                            
                            // Check if all digits processed
                            if (number_reg < 10) begin
                                calculation_done <= 1'b1;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Compare sum with original number (use number_reg which is now 0, need original)
                    // We saved original in temp register during IDLE, but overwrote it
                    // Need to save original separately
                    if (sum == number_reg) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT_DIGITS;
                end
            end

            COUNT_DIGITS: begin
                if (counting_done) begin
                    next_state = CALCULATE_SUM;
                end else if (cycle_counter >= 4'd5) begin
                    next_state = CALCULATE_SUM;
                end else begin
                    next_state = COUNT_DIGITS;
                end
            end

            CALCULATE_SUM: begin
                if (calculation_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALCULATE_SUM;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule