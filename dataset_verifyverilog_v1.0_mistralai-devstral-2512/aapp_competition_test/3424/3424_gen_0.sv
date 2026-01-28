module largest_base_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] y_lsb,
    input wire [31:0] y_msb,
    input wire [31:0] l_lsb,
    input wire [31:0] l_msb,
    output reg [31:0] result_base,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_BASE = 3'd2;
    localparam [2:0] EXTRACT_DIGITS = 3'd3;
    localparam [2:0] CHECK_DIGITS = 3'd4;
    localparam [2:0] CONVERT_DECIMAL = 3'd5;
    localparam [2:0] COMPARE = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state, next_state;

    // 64-bit y and l
    reg [63:0] y_reg, l_reg;

    // Current base
    reg [31:0] current_base;

    // Digit storage (max 32 digits, 4 bits each)
    reg [3:0] digits [0:31];
    reg [4:0] digit_count;

    // Decimal conversion
    reg [63:0] decimal_value;
    reg [5:0] digit_index;

    // Temporary values for division
    reg [63:0] dividend, quotient, remainder;
    reg [31:0] divisor;

    // Iteration counter
    reg [4:0] iteration_count;
    localparam [4:0] MAX_ITERATIONS = 5'd32;

    // Status flags
    reg all_digits_valid;
    reg decimal_ge_l;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            y_reg <= 64'd0;
            l_reg <= 64'd0;
            current_base <= 32'd0;
            digit_count <= 5'd0;
            decimal_value <= 64'd0;
            digit_index <= 6'd0;
            dividend <= 64'd0;
            quotient <= 64'd0;
            remainder <= 64'd0;
            divisor <= 32'd0;
            iteration_count <= 5'd0;
            all_digits_valid <= 1'b0;
            decimal_ge_l <= 1'b0;
            result_base <= 32'd0;
            done <= 1'b0;
            
            // Initialize digits array
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Load y and l
                y_reg = {y_msb, y_lsb};
                l_reg = {l_msb, l_lsb};
                
                // Initialize base to y (clamped to 32 bits)
                if (y_reg > 32'd0) begin
                    current_base = y_reg[31:0];
                end else begin
                    current_base = 32'd10; // Minimum base is 2, but start from y
                end
                
                iteration_count = 5'd0;
                next_state = CHECK_BASE;
            end

            CHECK_BASE: begin
                // Check if we've exceeded max iterations or base < 2
                if (iteration_count >= MAX_ITERATIONS || current_base < 32'd2) begin
                    next_state = FINISH;
                end else begin
                    // Reset digit count and decimal value
                    digit_count = 5'd0;
                    decimal_value = 64'd0;
                    
                    // Initialize for digit extraction
                    dividend = y_reg;
                    divisor = current_base;
                    
                    next_state = EXTRACT_DIGITS;
                end
            end

            EXTRACT_DIGITS: begin
                // Perform division to extract digits
                if (dividend >= divisor) begin
                    // Calculate quotient and remainder
                    quotient = dividend / divisor;
                    remainder = dividend % divisor;
                    
                    // Store digit
                    digits[digit_count] = remainder[3:0];
                    digit_count = digit_count + 5'd1;
                    
                    // Update dividend
                    dividend = quotient;
                end else begin
                    // Last digit
                    digits[digit_count] = dividend[3:0];
                    digit_count = digit_count + 5'd1;
                    
                    next_state = CHECK_DIGITS;
                end
            end

            CHECK_DIGITS: begin
                // Check if all digits are <= 9
                reg [31:0] i;
                all_digits_valid = 1'b1;
                
                for (i = 0; i < digit_count; i = i + 1) begin
                    if (digits[i] > 4'd9) begin
                        all_digits_valid = 1'b0;
                    end
                end
                
                if (all_digits_valid) begin
                    // Reset for decimal conversion
                    digit_index = 6'd0;
                    decimal_value = 64'd0;
                    next_state = CONVERT_DECIMAL;
                end else begin
                    // Move to next base
                    current_base = current_base - 32'd1;
                    iteration_count = iteration_count + 5'd1;
                    next_state = CHECK_BASE;
                end
            end

            CONVERT_DECIMAL: begin
                // Convert digits to decimal value
                if (digit_index < digit_count) begin
                    reg [63:0] power_of_10;
                    reg [5:0] j;
                    
                    // Calculate 10^digit_index
                    power_of_10 = 64'd1;
                    for (j = 0; j < digit_index; j = j + 1) begin
                        power_of_10 = power_of_10 * 64'd10;
                    end
                    
                    // Add digit * power_of_10
                    decimal_value = decimal_value + (digits[digit_index] * power_of_10);
                    
                    digit_index = digit_index + 6'd1;
                end else begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                // Compare decimal_value with l
                decimal_ge_l = (decimal_value >= l_reg);
                
                if (decimal_ge_l) begin
                    // Found valid base
                    result_base = current_base;
                    next_state = FINISH;
                end else begin
                    // Try next base
                    current_base = current_base - 32'd1;
                    iteration_count = iteration_count + 5'd1;
                    next_state = CHECK_BASE;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule