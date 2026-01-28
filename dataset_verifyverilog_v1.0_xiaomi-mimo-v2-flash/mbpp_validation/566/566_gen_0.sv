module DigitSumCalculation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] number,
    output reg [7:0] sum,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] num_reg;           // Current number being processed
    reg [15:0] remainder_reg;     // Stores remainder for division
    reg [7:0] accumulator;        // Accumulates digit sums
    reg [3:0] cycle_count;        // Prevents infinite loops (max 5 cycles for 16-bit)
    reg process_done;             // Signal when processing is complete

    // Division by 10 constants for non-restoring algorithm
    localparam [15:0] DIVISOR = 16'd10;
    localparam [4:0] MAX_CYCLES = 5'd5;

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESSING: begin
                if (process_done || cycle_count >= MAX_CYCLES) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            num_reg <= 16'd0;
            remainder_reg <= 16'd0;
            accumulator <= 8'd0;
            cycle_count <= 4'd0;
            process_done <= 1'b0;
            sum <= 8'd0;
            done <= 1'b0;
        end else begin
            // Update state
            state <= next_state;

            case (state)
                IDLE: begin
                    // Clear done and prepare for new operation
                    done <= 1'b0;
                    process_done <= 1'b0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        // Sample input number
                        num_reg <= number;
                        remainder_reg <= 16'd0;
                        accumulator <= 8'd0;
                    end
                end

                PROCESSING: begin
                    // Non-restoring division by 10 to extract last digit
                    // Algorithm: remainder = previous_remainder * 10 + (current_digit)
                    // To get last digit: remainder = num % 10
                    // To get quotient: num / 10
                    
                    // Combined calculation for current digit and next number
                    reg [15:0] next_num;
                    reg [15:0] current_digit;
                    reg [15:0] next_remainder;
                    
                    // Fast division by 10 using approximation
                    // For 16-bit numbers, we can use direct division
                    // quotient = num_reg / 10
                    // digit = num_reg % 10
                    
                    current_digit = num_reg % 10;
                    next_num = num_reg / 10;
                    
                    // Add current digit to accumulator
                    accumulator <= accumulator + current_digit[7:0];
                    
                    // Update number for next iteration
                    num_reg <= next_num;
                    
                    // Increment cycle counter
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if we're done
                    if (next_num == 16'd0) begin
                        process_done <= 1'b1;
                    end
                end

                COMPLETE: begin
                    // Output the final sum
                    sum <= accumulator;
                    done <= 1'b1;
                    process_done <= 1'b0;
                end

                default: begin
                    // Reset to safe state
                    state <= IDLE;
                    num_reg <= 16'd0;
                    remainder_reg <= 16'd0;
                    accumulator <= 8'd0;
                    cycle_count <= 4'd0;
                    process_done <= 1'b0;
                    sum <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule