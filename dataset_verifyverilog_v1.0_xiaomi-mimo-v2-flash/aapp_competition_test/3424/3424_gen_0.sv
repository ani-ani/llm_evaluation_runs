module FindLargestBase (
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

    // Parameters
    localparam [5:0] MAX_ITERATIONS = 6'd32;
    localparam [5:0] MAX_DIGITS = 6'd32;
    localparam [4:0] BASE_BITS = 5'd24;

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] EXTRACT    = 3'd2;
    localparam [2:0] VALIDATE   = 3'd3;
    localparam [2:0] CONVERT    = 3'd4;
    localparam [2:0] COMPARE    = 3'd5;
    localparam [2:0] DECREMENT  = 3'd6;
    localparam [2:0] FINISH     = 3'd7;

    // 64-bit registers (split into high/low)
    reg [63:0] y_reg;
    reg [63:0] l_reg;
    reg [63:0] b_reg;  // Current base being tested
    reg [63:0] decimal_val;
    
    // Digit array (packed for Icarus compatibility)
    reg [3:0] digits [0:31];  // Max 32 digits, each 0-15
    reg [5:0] digit_idx;
    reg [5:0] num_digits;
    
    // Control signals
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] iter_count;
    reg all_digits_valid;
    reg [63:0] temp_y;
    reg [63:0] temp_dividend;
    reg [63:0] temp_quotient;
    reg [63:0] temp_remainder;
    reg [5:0] div_step;
    reg [63:0] pow10;
    reg [5:0] calc_idx;
    reg [63:0] current_sum;
    reg [63:0] digit_val;
    reg [5:0] i;  // Loop variable
    reg comparison_result;
    
    // Division helper state
    localparam [1:0] DIV_IDLE = 2'd0;
    localparam [1:0] DIV_RUN  = 2'd1;
    localparam [1:0] DIV_DONE = 2'd2;
    reg [1:0] div_state;

    // 64-bit division by b (b >= 2)
    // Algorithm: simple repeated subtraction (sufficient for small b)
    // For b >= 2, max iterations = y/b <= 2^63 / 2 = 2^62, too many!
    // Use binary long division instead
    reg [6:0] div_bit_idx;
    reg [63:0] div_remainder;
    reg [63:0] div_quotient;
    reg [63:0] div_b_scaled;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_reg <= 64'd0;
            l_reg <= 64'd0;
            b_reg <= 64'd0;
            decimal_val <= 64'd0;
            result_base <= 32'd0;
            done <= 1'b0;
            state <= IDLE;
            next_state <= IDLE;
            iter_count <= 6'd0;
            digit_idx <= 6'd0;
            num_digits <= 6'd0;
            all_digits_valid <= 1'b0;
            temp_y <= 64'd0;
            temp_dividend <= 64'd0;
            temp_quotient <= 64'd0;
            temp_remainder <= 64'd0;
            div_step <= 6'd0;
            pow10 <= 64'd0;
            calc_idx <= 6'd0;
            current_sum <= 64'd0;
            digit_val <= 64'd0;
            i <= 6'd0;
            comparison_result <= 1'b0;
            div_state <= DIV_IDLE;
            div_bit_idx <= 7'd0;
            div_remainder <= 64'd0;
            div_quotient <= 64'd0;
            div_b_scaled <= 64'd0;
            // Initialize digits array
            for (i = 0; i < 32; i = i + 1) begin
                digits[i] <= 4'd0;
            end
            i <= 6'd0;
        end else begin
            done <= 1'b0;  // Default: done stays low unless explicitly set
            
            case (state)
                IDLE: begin
                    // Wait for start signal
                    if (start) begin
                        // Combine 64-bit values from split inputs
                        y_reg <= {y_msb, y_lsb};
                        l_reg <= {l_msb, l_lsb};
                        result_base <= 32'd0;
                        done <= 1'b0;
                        next_state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize base search from y
                    // For large y (> 2^32-1), start from 2^32-1 as upper bound
                    if (y_reg[63:32] != 32'd0) begin
                        b_reg <= 64'hFFFFFFFF;  // Start from 2^32-1
                    end else begin
                        b_reg <= {32'd0, y_reg[31:0]};  // Use y directly
                    end
                    iter_count <= 6'd0;
                    next_state <= EXTRACT;
                end
                
                EXTRACT: begin
                    // Extract digits of y in base b using repeated division
                    case (div_state)
                        DIV_IDLE: begin
                            // Start division: dividend = y, divisor = b
                            if (b_reg >= 2) begin
                                div_quotient <= 64'd0;
                                div_remainder <= y_reg;
                                div_b_scaled <= b_reg;
                                div_bit_idx <= 6'd63;  // Start from MSB
                                div_state <= DIV_RUN;
                            end else begin
                                // Invalid base, skip
                                next_state <= DECREMENT;
                            end
                        end
                        
                        DIV_RUN: begin
                            // Binary long division
                            if (div_bit_idx < 64) begin
                                // Shift remainder left by 1
                                div_remainder <= {div_remainder[62:0], 1'b0};
                                
                                // Check if remainder >= divisor
                                if (div_remainder >= div_b_scaled) begin
                                    div_remainder <= div_remainder - div_b_scaled;
                                    div_quotient <= {div_quotient[62:0], 1'b1};
                                end else begin
                                    div_quotient <= {div_quotient[62:0], 1'b0};
                                end
                                
                                div_bit_idx <= div_bit_idx - 7'd1;
                            end else begin
                                // Division complete
                                // Extract last remainder (least significant digit)
                                if (num_digits < MAX_DIGITS) begin
                                    digits[num_digits] <= div_remainder[3:0];
                                    num_digits <= num_digits + 6'd1;
                                end
                                
                                // Check if quotient is zero
                                if (div_quotient == 64'd0) begin
                                    // Extraction complete
                                    div_state <= DIV_IDLE;
                                    digit_idx <= 6'd0;
                                    next_state <= VALIDATE;
                                end else begin
                                    // Continue with next digit
                                    div_remainder <= div_quotient;
                                    div_quotient <= 64'd0;
                                    div_bit_idx <= 6'd63;
                                    // div_state stays in DIV_RUN
                                end
                            end
                        end
                        
                        default: begin
                            div_state <= DIV_IDLE;
                            next_state <= DECREMENT;
                        end
                    endcase
                end
                
                VALIDATE: begin
                    // Check if all digits are 0-9
                    if (digit_idx < num_digits) begin
                        if (digits[digit_idx] > 4'd9) begin
                            all_digits_valid <= 1'b0;
                            digit_idx <= num_digits;  // Skip remaining
                        end else begin
                            digit_idx <= digit_idx + 6'd1;
                        end
                    end else begin
                        // All digits checked
                        if (all_digits_valid) begin
                            next_state <= CONVERT;
                        end else begin
                            next_state <= DECREMENT;
                        end
                    end
                end
                
                CONVERT: begin
                    // Convert digit string to decimal value
                    // decimal_val = sum(digit[i] * 10^i)
                    case (div_state)
                        DIV_IDLE: begin
                            // Initialize for power of 10 calculation
                            if (calc_idx < num_digits) begin
                                // Compute 10^calc_idx
                                pow10 <= 64'd1;
                                i <= 6'd0;
                                div_state <= DIV_RUN;
                            end else begin
                                // Conversion complete
                                decimal_val <= current_sum;
                                calc_idx <= 6'd0;
                                current_sum <= 64'd0;
                                div_state <= DIV_IDLE;
                                next_state <= COMPARE;
                            end
                        end
                        
                        DIV_RUN: begin
                            // Multiply pow10 by 10 for i iterations
                            if (i < calc_idx) begin
                                pow10 <= pow10 * 10;
                                i <= i + 6'd1;
                            end else begin
                                // Now compute digit_val = digits[calc_idx] * pow10
                                digit_val <= digits[calc_idx] * pow10;
                                div_state <= DIV_DONE;
                            end
                        end
                        
                        DIV_DONE: begin
                            // Add to sum
                            current_sum <= current_sum + digit_val;
                            calc_idx <= calc_idx + 6'd1;
                            div_state <= DIV_IDLE;
                        end
                        
                        default: begin
                            div_state <= DIV_IDLE;
                            next_state <= DECREMENT;
                        end
                    endcase
                end
                
                COMPARE: begin
                    // Compare decimal_val with l
                    if (decimal_val >= l_reg) begin
                        // Valid base found
                        result_base <= b_reg[31:0];
                        next_state <= FINISH;
                    end else begin
                        next_state <= DECREMENT;
                    end
                end
                
                DECREMENT: begin
                    // Decrement base and continue search
                    if (b_reg > 2) begin
                        b_reg <= b_reg - 64'd1;
                        // Reset for next extraction
                        num_digits <= 6'd0;
                        digit_idx <= 6'd0;
                        all_digits_valid <= 1'b1;
                        calc_idx <= 6'd0;
                        current_sum <= 64'd0;
                        div_state <= DIV_IDLE;
                        iter_count <= iter_count + 6'd1;
                        
                        // Check iteration limit
                        if (iter_count < MAX_ITERATIONS) begin
                            next_state <= EXTRACT;
                        end else begin
                            // Time limit reached, assume no valid base
                            next_state <= FINISH;
                        end
                    end else begin
                        // Base is 1 or less, no valid base found
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Operation complete
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update state
            state <= next_state;
        end
    end

endmodule