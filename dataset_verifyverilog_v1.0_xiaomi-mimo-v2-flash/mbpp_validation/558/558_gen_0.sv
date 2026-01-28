module sum_digit_differences (
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COMPUTE_DIFF = 3'd1;
    localparam [2:0] EXTRACT_DIGIT = 3'd2;
    localparam [2:0] SUM_DIGITS = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [15:0] abs_diff;
    reg [15:0] divisor;
    reg [15:0] remainder;
    reg [3:0] digit_count;  // Track how many digits processed (max 5)
    reg [7:0] digit_sum;    // Sum of extracted digits
    reg [7:0] current_digit;
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Combinational logic for division/modulo
    wire [15:0] quotient;
    wire [15:0] modulo;
    
    // Division by 10: simple repeated subtraction or shift-add
    // For 16-bit / 10, we can use shift-subtract algorithm
    // Since 10 = 1010 binary, use shift-add method
    
    // Generate quotient and remainder for division by 10
    // Use shift-add algorithm: quotient = (dividend * 6554) >> 16
    // where 6554 = 2^16 / 10 (rounded)
    wire [31:0] mult_temp;
    wire [15:0] q_temp;
    wire [3:0] r_temp;
    
    assign mult_temp = {16'd0, remainder} * 16'd6554;  // 16x16=32 bit
    assign q_temp = mult_temp[31:16];  // Quotient
    
    // Calculate remainder: dividend - quotient * 10
    wire [15:0] prod_times_10;
    wire [15:0] diff_temp;
    
    assign prod_times_10 = q_temp * 4'd10;
    assign diff_temp = remainder - prod_times_10;
    assign modulo = diff_temp[3:0];  // Remainder is 0-9
    assign quotient = q_temp;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE_DIFF;
                else
                    next_state = IDLE;
            end
            COMPUTE_DIFF: begin
                next_state = EXTRACT_DIGIT;
            end
            EXTRACT_DIGIT: begin
                if (remainder < 10 || digit_count >= 4'd5)
                    next_state = SUM_DIGITS;
                else
                    next_state = EXTRACT_DIGIT;
            end
            SUM_DIGITS: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            abs_diff <= 16'd0;
            divisor <= 16'd10;  // Constant divisor
            remainder <= 16'd0;
            digit_count <= 4'd0;
            digit_sum <= 8'd0;
            current_digit <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    digit_sum <= 8'd0;
                    digit_count <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Start computation
                    end
                end
                
                COMPUTE_DIFF: begin
                    // Compute absolute difference |a - b|
                    if ($signed(a) > $signed(b)) begin
                        abs_diff <= a - b;
                    end else begin
                        abs_diff <= b - a;
                    end
                    remainder <= ($signed(a) > $signed(b)) ? (a - b) : (b - a);
                    digit_count <= 4'd0;
                    digit_sum <= 8'd0;
                end
                
                EXTRACT_DIGIT: begin
                    // Extract digit via division by 10
                    if (remainder >= 10 && digit_count < 4'd5) begin
                        current_digit <= {4'd0, modulo};  // Lower 4 bits is digit
                        remainder <= quotient;
                        digit_sum <= digit_sum + {4'd0, modulo};
                        digit_count <= digit_count + 4'd1;
                    end else begin
                        // Last digit or reached max digits
                        if (remainder < 10) begin
                            current_digit <= {4'd0, remainder};
                            digit_sum <= digit_sum + {4'd0, remainder};
                            digit_count <= digit_count + 4'd1;
                        end
                    end
                end
                
                SUM_DIGITS: begin
                    // No operation needed, sum already accumulated
                    // Clamp result to 8 bits (should be <= 45 for 5 digits)
                    result <= (digit_sum > 8'd255) ? 8'd255 : digit_sum;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
            
            // Clear done when leaving FINISH
            if (state == FINISH && next_state == IDLE) begin
                done <= 1'b0;
            end
        end
    end
endmodule