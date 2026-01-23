module triangle_area(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam VALIDATE = 5'b00010;
    localparam COMPUTE_S = 5'b00100;
    localparam COMPUTE_PRODUCT = 5'b01000;
    localparam SQRT = 5'b10000;
    
    reg [4:0] state;
    reg [4:0] next_state;
    
    // Validation registers
    reg [8:0] sum_ab, sum_ac, sum_bc;
    reg valid;
    reg valid_reg;
    
    // Q16.16 conversion registers
    reg [31:0] a_q16, b_q16, c_q16;
    
    // Intermediate computation registers
    reg [31:0] s;
    reg [31:0] s_a, s_b, s_c;
    
    // Product calculation registers
    reg [31:0] p1, p2, p3, p4;
    reg [63:0] prod1, prod2, prod3;
    reg [31:0] product;
    reg [2:0] mult_cnt;
    
    // Square root registers
    reg [31:0] sqrt_low, sqrt_high, sqrt_mid;
    reg [63:0] sqrt_mid_sq;
    reg [4:0] sqrt_iter;
    reg [31:0] sqrt_result;
    
    // Counter for timing
    reg [3:0] counter;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = VALIDATE;
                else
                    next_state = IDLE;
            end
            VALIDATE: begin
                if (counter >= 2)
                    next_state = COMPUTE_S;
                else
                    next_state = VALIDATE;
            end
            COMPUTE_S: begin
                if (counter >= 1)
                    next_state = COMPUTE_PRODUCT;
                else
                    next_state = COMPUTE_S;
            end
            COMPUTE_PRODUCT: begin
                if (mult_cnt >= 3)
                    next_state = SQRT;
                else
                    next_state = COMPUTE_PRODUCT;
            end
            SQRT: begin
                if (sqrt_iter >= 16 || sqrt_low > sqrt_high)
                    next_state = IDLE;  // Go to IDLE directly for done
                else
                    next_state = SQRT;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'h0;
            done <= 1'b0;
            counter <= 4'b0;
            mult_cnt <= 3'b0;
            sqrt_iter <= 5'b0;
            valid_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'b0;
                    mult_cnt <= 3'b0;
                    sqrt_iter <= 5'b0;
                    if (start) begin
                        // Convert inputs to Q16.16
                        a_q16 <= {a, 16'b0};
                        b_q16 <= {b, 16'b0};
                        c_q16 <= {c, 16'b0};
                    end
                end
                
                VALIDATE: begin
                    if (counter == 0) begin
                        // Calculate sums
                        sum_ab <= {1'b0, a} + {1'b0, b};
                        sum_ac <= {1'b0, a} + {1'b0, c};
                        sum_bc <= {1'b0, b} + {1'b0, c};
                        counter <= counter + 1;
                    end else if (counter == 1) begin
                        // Check validity
                        valid <= (sum_ab > c) && (sum_ac > b) && (sum_bc > a);
                        counter <= counter + 1;
                    end else begin
                        valid_reg <= valid;
                        counter <= 4'b0;
                    end
                end
                
                COMPUTE_S: begin
                    if (!valid_reg) begin
                        // Invalid triangle - skip to done
                        result <= 32'hFFFFFFFF;
                        done <= 1'b1;
                        counter <= 4'b0;
                    end else begin
                        if (counter == 0) begin
                            // Calculate s = (a + b + c) / 2 in Q16.16
                            // First calculate a+b+c
                            s <= (a_q16 + b_q16 + c_q16) >> 1;
                            counter <= counter + 1;
                        end else if (counter == 1) begin
                            // Calculate s-a, s-b, s-c
                            s_a <= s - a_q16;
                            s_b <= s - b_q16;
                            s_c <= s - c_q16;
                            counter <= 4'b0;
                        end
                    end
                end
                
                COMPUTE_PRODUCT: begin
                    if (valid_reg) begin
                        case (mult_cnt)
                            0: begin
                                prod1 <= s[31:0] * s_a[31:0];
                                mult_cnt <= 1;
                            end
                            1: begin
                                // Take upper 32 bits of product for Q16.16 multiplication
                                p1 <= prod1[63:32];
                                prod2 <= s_b[31:0] * s_c[31:0];
                                mult_cnt <= 2;
                            end
                            2: begin
                                p2 <= prod2[63:32];
                                // Wait for next cycle
                                mult_cnt <= 3;
                            end
                            3: begin
                                // Final multiplication
                                prod3 <= p1 * p2;
                                mult_cnt <= 4;
                            end
                            default: begin
                                product <= prod3[63:32];
                                mult_cnt <= 0;
                            end
                        endcase
                    end
                end
                
                SQRT: begin
                    if (valid_reg && mult_cnt == 4) begin
                        if (sqrt_iter == 0) begin
                            // Initialize sqrt
                            sqrt_low <= 32'b0;
                            sqrt_high <= product;
                            sqrt_result <= 32'b0;
                            sqrt_iter <= 1;
                        end else if (sqrt_low <= sqrt_high) begin
                            // Binary search step
                            sqrt_mid <= (sqrt_low + sqrt_high) >> 1;
                            sqrt_mid_sq <= (sqrt_low + sqrt_high) >> 1;
                            sqrt_mid_sq <= ((sqrt_low + sqrt_high) >> 1) * ((sqrt_low + sqrt_high) >> 1);
                            
                            // Check if mid^2 <= product in next cycle
                            if (((sqrt_low + sqrt_high) >> 1) * ((sqrt_low + sqrt_high) >> 1) <= product) begin
                                sqrt_result <= (sqrt_low + sqrt_high) >> 1;
                                sqrt_low <= ((sqrt_low + sqrt_high) >> 1) + 1;
                            end else begin
                                sqrt_high <= ((sqrt_low + sqrt_high) >> 1) - 1;
                            end
                            sqrt_iter <= sqrt_iter + 1;
                        end else begin
                            // Done with sqrt
                            result <= sqrt_result;
                            done <= 1'b1;
                            sqrt_iter <= 5'b0;
                            mult_cnt <= 3'b0;
                        end
                    end else if (!valid_reg) begin
                        // Should not reach here but safety
                        result <= 32'hFFFFFFFF;
                        done <= 1'b1;
                    end
                end
                
                default: begin
                    done <= 1'b0;
                    result <= 32'h0;
                end
            endcase
        end
    end

endmodule
