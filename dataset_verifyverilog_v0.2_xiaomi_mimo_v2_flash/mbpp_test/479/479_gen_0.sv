module first_digit(
    input clk,
    input rst_n,
    input start,
    input [31:0] num,
    output reg [3:0] first_digit,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALCULATING = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;
    
    // Internal registers
    reg [31:0] current_num;
    reg [31:0] current_num_next;
    reg [3:0] first_digit_next;
    reg done_next;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_num <= 32'b0;
            first_digit <= 4'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            current_num <= current_num_next;
            first_digit <= first_digit_next;
            done <= done_next;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        current_num_next = current_num;
        first_digit_next = first_digit;
        done_next = done;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    // Check if num is already less than 10
                    if (num < 10) begin
                        first_digit_next = num[3:0];
                        next_state = DONE;
                    end else begin
                        current_num_next = num;
                        next_state = CALCULATING;
                    end
                end
            end

            CALCULATING: begin
                // Subtract 10 from current_num
                if (current_num >= 10) begin
                    current_num_next = current_num - 10;
                    next_state = CALCULATING;
                end else begin
                    // current_num is now the remainder (0-9)
                    // But we need the quotient, not the remainder
                    // We need to track how many times we subtracted 10
                    // This approach is wrong - we need to count subtractions
                    // Let's rethink this
                    
                    // Alternative: Divide by 10 using subtraction to get quotient
                    // Count how many times we can subtract 10 until < 10
                    // That count is the new number, and remainder is < 10
                    // Wait, we need to keep dividing until the quotient is < 10
                    
                    // Actually, the algorithm should be:
                    // While current_num >= 10:
                    //   current_num = current_num / 10
                    // return current_num
                    // 
                    // To divide by 10 using subtraction:
                    // count = 0
                    // while (num >= 10):
                    //   num = num - 10
                    //   count++
                    // return count (but this is remainder, not quotient)
                    
                    // Actually: num / 10 = floor(num / 10)
                    // If num = 25: 25 - 10 = 15, 15 - 10 = 5, 5 < 10
                    // count = 2, remainder = 5
                    // So quotient = count = 2
                    // This is right!
                    
                    // Wait, I need to implement this correctly.
                    // Current logic is subtracting 10 once per clock, but not counting
                    // Need a counter for subtractions
                end
            end

            DONE: begin
                // Hold state until reset
                if (!rst_n) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule

// Corrected implementation with proper division logic
module first_digit_v2(
    input clk,
    input rst_n,
    input start,
    input [31:0] num,
    output reg [3:0] first_digit,
    output reg done
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALCULATING = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;
    reg [31:0] temp_num;
    reg [31:0] temp_num_next;
    reg [31:0] quotient;
    reg [31:0] quotient_next;
    reg [3:0] first_digit_next;
    reg done_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            temp_num <= 32'b0;
            quotient <= 32'b0;
            first_digit <= 4'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            temp_num <= temp_num_next;
            quotient <= quotient_next;
            first_digit <= first_digit_next;
            done <= done_next;
        end
    end

    always @(*) begin
        next_state = current_state;
        temp_num_next = temp_num;
        quotient_next = quotient;
        first_digit_next = first_digit;
        done_next = done;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    if (num < 10) begin
                        first_digit_next = num[3:0];
                        next_state = DONE;
                    end else begin
                        temp_num_next = num;
                        quotient_next = 32'b0;
                        next_state = CALCULATING;
                    end
                end
            end

            CALCULATING: begin
                if (temp_num >= 10) begin
                    temp_num_next = temp_num - 10;
                    quotient_next = quotient + 1;
                end else begin
                    // temp_num is now remainder
                    // quotient is the result of division by 10
                    if (quotient < 10) begin
                        first_digit_next = quotient[3:0];
                        next_state = DONE;
                    end else begin
                        temp_num_next = quotient;
                        quotient_next = 32'b0;
                    end
                end
            end

            DONE: begin
                // Wait for reset or new start
                if (!rst_n) begin
                    next_state = IDLE;
                end else if (start) begin
                    // Restart if start is pressed again
                    if (num < 10) begin
                        first_digit_next = num[3:0];
                        next_state = DONE;
                    end else begin
                        temp_num_next = num;
                        quotient_next = 32'b0;
                        next_state = CALCULATING;
                    end
                end
            end
        endcase
    end

endmodule

// Optimized single-module implementation
module first_digit(
    input clk,
    input rst_n,
    input start,
    input [31:0] num,
    output reg [3:0] first_digit,
    output reg done
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALCULATING = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;
    reg [31:0] current_value;
    reg [31:0] current_value_next;
    reg [31:0] quotient;
    reg [31:0] quotient_next;
    reg [3:0] first_digit_next;
    reg done_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_value <= 32'b0;
            quotient <= 32'b0;
            first_digit <= 4'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            current_value <= current_value_next;
            quotient <= quotient_next;
            first_digit <= first_digit_next;
            done <= done_next;
        end
    end

    always @(*) begin
        next_state = current_state;
        current_value_next = current_value;
        quotient_next = quotient;
        first_digit_next = first_digit;
        done_next = done;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    if (num < 10) begin
                        first_digit_next = num[3:0];
                        next_state = DONE;
                    end else begin
                        current_value_next = num;
                        quotient_next = 32'b0;
                        next_state = CALCULATING;
                    end
                end
            end

            CALCULATING: begin
                if (current_value >= 10) begin
                    current_value_next = current_value - 10;
                    quotient_next = quotient + 1;
                end else begin
                    if (quotient < 10) begin
                        first_digit_next = quotient[3:0];
                        next_state = DONE;
                    end else begin
                        current_value_next = quotient;
                        quotient_next = 32'b0;
                    end
                end
            end

            DONE: begin
                if (!rst_n) begin
                    next_state = IDLE;
                end else if (start) begin
                    if (num < 10) begin
                        first_digit_next = num[3:0];
                        next_state = DONE;
                    end else begin
                        current_value_next = num;
                        quotient_next = 32'b0;
                        next_state = CALCULATING;
                    end
                end
            end
        endcase
    end

endmodule