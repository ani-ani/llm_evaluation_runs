module MinimumFuel (
    input clk,
    input rst_n,
    input start,
    input [9:0] a_i [0:999],
    input [9:0] b_i [0:999],
    input [9:0] m,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point arithmetic parameters (Q16.16)
    localparam [31:0] Q16_16_SCALE = 32'd65536;
    localparam [31:0] Q16_16_ONE = 32'd65536;
    localparam [31:0] Q16_16_M1 = 32'hFFFFFFFF; // -1
    
    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_INVALID = 4'd1;
    localparam [3:0] CHECK_INVALID_WAIT = 4'd2;
    localparam [3:0] CALCULATE     = 4'd3;
    localparam [3:0] CALCULATE_WAIT = 4'd4;
    localparam [3:0] MULTIPLY      = 4'd5;
    localparam [3:0] SUBTRACT      = 4'd6;
    localparam [3:0] FINISH        = 4'd7;
    localparam [3:0] ERROR         = 4'd8;

    // Registers and counters
    reg [3:0] state, next_state;
    reg [31:0] product_acc;      // Accumulated product (Q16.16)
    reg [31:0] m_q16;            // m in Q16.16
    reg [31:0] temp_result;      // Intermediate result
    reg [15:0] index;            // Loop counter (0 to n-1)
    reg [15:0] n_reg;            // Store n (will be set to 1000 max)
    reg invalid_found;           // Flag for invalid coefficients
    
    // Temporary registers for calculation
    reg [31:0] a_q16, b_q16, a_minus_1, b_minus_1;
    reg [63:0] temp_mult;
    
    // Cycle counter for timeout protection
    reg [16:0] cycle_count;      // Up to 131,072 cycles
    localparam [16:0] MAX_CYCLES = 17'd100000;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_INVALID;
            end
            CHECK_INVALID: begin
                // Check a_i[0] and b_i[0] for immediate check
                next_state = CHECK_INVALID_WAIT;
            end
            CHECK_INVALID_WAIT: begin
                // Wait one cycle for async read
                next_state = CALCULATE;
            end
            CALCULATE: begin
                // Process all n coefficients
                if (index >= n_reg)
                    next_state = MULTIPLY;
                else
                    next_state = CALCULATE_WAIT;
            end
            CALCULATE_WAIT: begin
                // Wait for check and multiply operations
                next_state = CALCULATE;
            end
            MULTIPLY: begin
                // Multiply product by m
                next_state = SUBTRACT;
            end
            SUBTRACT: begin
                // Subtract m from result
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            ERROR: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            product_acc <= Q16_16_ONE;
            m_q16 <= 32'd0;
            temp_result <= 32'd0;
            index <= 16'd0;
            n_reg <= 16'd1000;  // Fixed at maximum
            invalid_found <= 1'b0;
            cycle_count <= 17'd0;
            a_q16 <= 32'd0;
            b_q16 <= 32'd0;
            a_minus_1 <= 32'd0;
            b_minus_1 <= 32'd0;
            temp_mult <= 64'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 17'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    product_acc <= Q16_16_ONE;
                    index <= 16'd0;
                    invalid_found <= 1'b0;
                    cycle_count <= 17'd0;
                    m_q16 <= {m, 16'd0};  // Convert m to Q16.16
                    result <= 32'd0;
                end
                
                CHECK_INVALID: begin
                    // Check first coefficients for immediate invalid detection
                    if (a_i[0] == 10'd1 || b_i[0] == 10'd1) begin
                        invalid_found <= 1'b1;
                    end
                end
                
                CHECK_INVALID_WAIT: begin
                    // Check remaining coefficients in array for efficiency
                    // Since a_i and b_i are inputs, we need to check them
                    // We'll do this in CALCULATE state
                end
                
                CALCULATE: begin
                    if (index < n_reg) begin
                        // Check if coefficients are valid (not 1)
                        // Note: inputs are 10-bit, so a_i[index] is valid
                        if (a_i[index] == 10'd1 || b_i[index] == 10'd1) begin
                            invalid_found <= 1'b1;
                        end
                        
                        // Convert a_i and b_i to Q16.16 format for division
                        // a_q16 = a_i * 65536
                        a_q16 <= {a_i[index], 16'd0};
                        b_q16 <= {b_i[index], 16'd0};
                        
                        // Compute (a_i - 1) and (b_i - 1) in Q16.16
                        a_minus_1 <= {a_i[index], 16'd0} - 32'd65536;
                        b_minus_1 <= {b_i[index], 16'd0} - 32'd65536;
                        
                        index <= index + 16'd1;
                    end else begin
                        // Done with all coefficients
                    end
                end
                
                CALCULATE_WAIT: begin
                    // Perform the multiplications for (a_i/(a_i-1)) * (b_i/(b_i-1))
                    if (!invalid_found && index <= n_reg && (a_i[index-1] != 10'd1 && b_i[index-1] != 10'd1)) begin
                        // Multiply numerator: a_q16 * b_q16 (64-bit result)
                        temp_mult <= a_q16 * b_q16;
                    end
                end
                
                MULTIPLY: begin
                    if (!invalid_found) begin
                        // Multiply product_acc by temp_mult / (a_minus_1 * b_minus_1)
                        // First compute denominator product (a-1)*(b-1)
                        // This is 32-bit * 32-bit = 64-bit
                        temp_mult <= a_minus_1 * b_minus_1;
                    end
                end
                
                SUBTRACT: begin
                    if (!invalid_found) begin
                        // Compute: product_acc * (a*q16 * b*q16) / ((a-1)*(b-1))
                        // We need to handle the division carefully with Q16.16
                        // For Q16.16 division: (A/B) = (A * SCALE) / B
                        // But A and B are already in Q16.16
                        
                        // Actually, we need: product_acc * (a_q16 / a_minus_1) * (b_q16 / b_minus_1)
                        // Let's compute step by step
                        // First: a_q16 / a_minus_1 (Q16.16 / Q16.16 = Q16.16)
                        // To avoid overflow, we should compute:
                        // (a_q16 * SCALE) / a_minus_1
                        temp_mult <= a_q16 * Q16_16_SCALE;  // 64-bit
                    end
                end
                
                FINISH: begin
                    if (invalid_found) begin
                        result <= 32'hFFFFFFFF;  // -1 in 32-bit
                    end else begin
                        // Final result should be in Q16.16 format
                        result <= temp_result;
                    end
                    done <= 1'b1;
                    cycle_count <= 17'd0;
                end
                
                ERROR: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    cycle_count <= 17'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end

    // Additional sequential logic for complex calculations
    // The above handles the main FSM, but we need additional logic
    // for the actual floating-point-like division and multiplication
    // in the CALCULATE_WAIT, MULTIPLY, and SUBTRACT states
    
    // We'll use a second always block for the calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main block
        end else begin
            // Only proceed when we have valid intermediate values
            if (state == CALCULATE_WAIT && index > 0 && !invalid_found) begin
                // Compute: (a_q16 / a_minus_1) in Q16.16
                // Division: (a_q16 * SCALE) / a_minus_1
                temp_mult <= a_q16 * Q16_16_SCALE;  // This gives Q32.16
                // We'll handle division in next state
            end
        end
    end
    
    // Simplified calculation approach
    // Since we cannot do division in a single state, we need to restructure
    
    // Let's create a more efficient implementation
    reg [63:0] div_temp;
    reg [63:0] num_temp;
    reg [63:0] den_temp;
    reg [31:0] factor_acc;  // Accumulated factor (Q16.16)
    
    // Add sequential logic for division
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_temp <= 64'd0;
            num_temp <= 64'd0;
            den_temp <= 64'd0;
            factor_acc <= Q16_16_ONE;
        end else begin
            case (state)
                IDLE: begin
                    factor_acc <= Q16_16_ONE;
                    div_temp <= 64'd0;
                end
                
                CALCULATE_WAIT: begin
                    if (index > 0 && !invalid_found) begin
                        // Compute a_q16 * b_q16 (numerator of factor)
                        num_temp <= a_q16 * b_q16;
                        // Compute a_minus_1 * b_minus_1 (denominator)
                        den_temp <= a_minus_1 * b_minus_1;
                    end
                end
                
                MULTIPLY: begin
                    if (!invalid_found && index > 0) begin
                        // Compute: factor_acc * (num_temp / den_temp)
                        // In Q16.16: (factor * num * SCALE) / den
                        div_temp <= factor_acc * num_temp;
                        // We'll multiply by SCALE in next cycle
                    end
                end
                
                SUBTRACT: begin
                    if (!invalid_found) begin
                        // Complete the multiplication by SCALE
                        temp_mult <= div_temp * Q16_16_SCALE;
                        // The division will be performed by: (temp_mult / den_temp)
                        // But we need to handle this as integer division
                        // For Q16.16, we can approximate by:
                        // result = (temp_mult >> 16) / (den_temp >> 16) if we were doing division
                        // Actually: result = (temp_mult * Q16_16_SCALE) / den_temp
                        
                        // Since we can't do large division easily, let's use:
                        // For the equation: initial_fuel = m * product - m
                        // product = ∏ (a_i / (a_i-1)) * (b_i / (b_i-1))
                        // We can compute incrementally
                        
                        // Instead of division, compute reciprocal of denominator
                        // factor = num_temp * Q16_16_SCALE / den_temp
                        // Then multiply factor_acc by factor
                        temp_result <= (num_temp * Q16_16_SCALE) / den_temp;
                    end
                end
                
                FINISH: begin
                    // Complete the subtraction
                    if (!invalid_found) begin
                        // result = m * product - m = m * (product - 1)
                        // In Q16.16: result = m_q16 * (factor_acc - Q16_16_ONE)
                        temp_result <= m_q16 * (factor_acc - Q16_16_ONE);
                        // Then convert back by dividing by SCALE if needed
                        result <= (m_q16 * (factor_acc - Q16_16_ONE)) >> 16;
                    end
                end
            endcase
        end
    end
    
endmodule

// Alternative simplified implementation
// Given the complexity of the calculation, let's provide a cleaner version
module MinimumFuel_Simplified (
    input clk,
    input rst_n,
    input start,
    input [9:0] a_i [0:999],
    input [9:0] b_i [0:999],
    input [9:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK = 4'd1;
    localparam [3:0] COMPUTE = 4'd2;
    localparam [3:0] CALC_FACTOR = 4'd3;
    localparam [3:0] MULT_RESULT = 4'd4;
    localparam [3:0] FINISH = 4'd5;
    localparam [3:0] ERROR = 4'd6;

    // Registers
    reg [3:0] state;
    reg [15:0] idx;
    reg [31:0] product;      // Q16.16 product accumulation
    reg [31:0] m_q16;        // m in Q16.16
    reg [31:0] temp_factor;  // Current factor (Q16.16)
    reg [63:0] mult_temp;
    reg invalid;
    reg [16:0] cycles;
    
    // Temporary storage for current coefficients
    reg [9:0] cur_a, cur_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            idx <= 16'd0;
            product <= 32'd65536;  // Q16.16 ONE
            m_q16 <= 32'd0;
            invalid <= 1'b0;
            cycles <= 17'd0;
            cur_a <= 10'd0;
            cur_b <= 10'd0;
            temp_factor <= 32'd0;
            mult_temp <= 64'd0;
        end else begin
            cycles <= cycles + 17'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    product <= 32'd65536;
                    idx <= 16'd0;
                    invalid <= 1'b0;
                    cycles <= 17'd0;
                    m_q16 <= {m, 16'd0};
                    result <= 32'd0;
                    
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check coefficients
                    cur_a <= a_i[idx];
                    cur_b <= b_i[idx];
                    
                    if (a_i[idx] == 10'd1 || b_i[idx] == 10'd1) begin
                        invalid <= 1'b1;
                    end
                    
                    idx <= idx + 16'd1;
                    
                    if (idx >= 1000) begin  // Fixed n = 1000
                        state <= COMPUTE;
                    end else begin
                        state <= CHECK;
                    end
                end
                
                COMPUTE: begin
                    // Reset for computation
                    idx <= 16'd0;
                    if (invalid) begin
                        state <= ERROR;
                    end else begin
                        state <= CALC_FACTOR;
                    end
                end
                
                CALC_FACTOR: begin
                    if (idx < 1000) begin
                        cur_a <= a_i[idx];
                        cur_b <= b_i[idx];
                        
                        // Compute factor = (a_i / (a_i-1)) * (b_i / (b_i-1)) in Q16.16
                        // For Q16.16: factor = (a * 65536) / (a-1) * (b * 65536) / (b-1)
                        // This becomes: (a*b*65536*65536) / ((a-1)*(b-1))
                        // But we want intermediate result in Q16.16
                        // So: factor = ((a*65536) / (a-1)) * ((b*65536) / (b-1)) / 65536
                        
                        // Compute a * 65536 / (a - 1)
                        mult_temp <= a_i[idx] * 65536;
                        state <= MULT_RESULT;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                MULT_RESULT: begin
                    // Complete the factor calculation
                    // temp_factor = (a * 65536) / (a - 1) * (b * 65536) / (b - 1) / 65536
                    // Simplified: temp_factor = (a * b * 65536) / ((a - 1) * (b - 1))
                    
                    // Use 64-bit division
                    if (cur_a > 1 && cur_b > 1) begin
                        mult_temp <= (cur_a * cur_b * 65536) / ((cur_a - 1) * (cur_b - 1));
                        temp_factor <= (cur_a * cur_b * 65536) / ((cur_a - 1) * (cur_b - 1));
                        
                        // Multiply into product
                        product <= (product * mult_temp) >> 16;
                        idx <= idx + 16'd1;
                        state <= CALC_FACTOR;
                    end else begin
                        invalid <= 1'b1;
                        state <= ERROR;
                    end
                end
                
                FINISH: begin
                    // final_fuel = m * product - m in Q16.16
                    // result = (m_q16 * product) - m_q16
                    result <= (m_q16 * product) - m_q16;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout
            if (cycles >= 17'd100000 && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end
endmodule

// Final clean implementation
module MinimumFuel_Final (
    input clk,
    input rst_n,
    input start,
    input [9:0] a_i [0:999],
    input [9:0] b_i [0:999],
    input [9:0] m,
    output reg [31:0] result,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK = 4'd1;
    localparam [3:0] COMPUTE = 4'd2;
    localparam [3:0] FINISH = 4'd3;
    localparam [3:0] ERROR = 4'd4;

    reg [3:0] state;
    reg [15:0] idx;
    reg [31:0] product;
    reg [31:0] m_q16;
    reg invalid;
    reg [16:0] cycles;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            idx <= 16'd0;
            product <= 32'd65536;
            m_q16 <= 32'd0;
            invalid <= 1'b0;
            cycles <= 17'd0;
        end else begin
            cycles <= cycles + 17'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    product <= 32'd65536;
                    idx <= 16'd0;
                    invalid <= 1'b0;
                    cycles <= 17'd0;
                    m_q16 <= {m, 16'd0};
                    result <= 32'd0;
                    
                    if (start) state <= CHECK;
                end
                
                CHECK: begin
                    // Check all coefficients for invalid values
                    if (a_i[idx] == 10'd1 || b_i[idx] == 10'd1) begin
                        invalid <= 1'b1;
                    end
                    
                    idx <= idx + 16'd1;
                    
                    if (idx >= 1000) begin
                        if (invalid) state <= ERROR;
                        else state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate product = ∏ (a_i/(a_i-1) * b_i/(b_i-1)) in Q16.16
                    // Using the formula: a_i * b_i * 65536 / ((a_i-1) * (b_i-1))
                    // All in Q16.16 fixed-point
                    
                    if (idx < 1000) begin
                        // Calculate current factor: (a*b*65536) / ((a-1)*(b-1))
                        // Use 64-bit for intermediate
                        if (a_i[idx] > 1 && b_i[idx] > 1) begin
                            // Compute in stages to avoid overflow
                            // factor = (a*b) / ((a-1)*(b-1)) * 65536
                            reg [63:0] num, den, factor;
                            num = a_i[idx] * b_i[idx];
                            den = (a_i[idx] - 1) * (b_i[idx] - 1);
                            factor = (num * 65536) / den;
                            
                            // Multiply into product and keep in Q16.16
                            product <= (product * factor) >> 16;
                            
                            idx <= idx + 16'd1;
                        end else begin
                            invalid <= 1'b1;
                            state <= ERROR;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // result = m * product - m (in Q16.16)
                    result <= (m_q16 * product) - m_q16;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycles >= 17'd100000 && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end
endmodule

// Best implementation - clean and synthesizable
module MinimumFuel (
    input clk,
    input rst_n,
    input start,
    input [9:0] a_i [0:999],
    input [9:0] b_i [0:999],
    input [9:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] CHECK      = 4'd1;
    localparam [3:0] COMPUTE    = 4'd2;
    localparam [3:0] FINISH     = 4'd3;
    localparam [3:0] ERROR      = 4'd4;

    // Registers
    reg [3:0] state, next_state;
    reg [15:0] idx;
    reg [31:0] product;      // Q16.16 accumulated product
    reg [31:0] m_q16;        // m in Q16.16
    reg invalid;
    reg [16:0] cycle_count;
    
    // Combinational computation registers
    reg [31:0] a_val, b_val;
    reg [63:0] num_val, den_val, fact_val;

    // State transition
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CHECK;
            CHECK: begin
                if (idx >= 1000) begin
                    next_state = invalid ? ERROR : COMPUTE;
                end
            end
            COMPUTE: begin
                if (idx >= 1000) next_state = FINISH;
            end
            FINISH, ERROR: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            idx <= 16'd0;
            product <= 32'd65536;  // Q16.16 ONE
            m_q16 <= 32'd0;
            invalid <= 1'b0;
            cycle_count <= 17'd0;
            a_val <= 32'd0;
            b_val <= 32'd0;
            num_val <= 64'd0;
            den_val <= 64'd0;
            fact_val <= 64'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 17'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    product <= 32'd65536;
                    idx <= 16'd0;
                    invalid <= 1'b0;
                    cycle_count <= 17'd0;
                    m_q16 <= {m, 16'd0};  // m in Q16.16
                    result <= 32'd0;
                end
                
                CHECK: begin
                    // Check for invalid coefficients (a_i = 1 or b_i = 1)
                    if (a_i[idx] == 10'd1 || b_i[idx] == 10'd1) begin
                        invalid <= 1'b1;
                    end
                    idx <= idx + 16'd1;
                end
                
                COMPUTE: begin
                    // Compute product = ∏(a_i/(a_i-1) * b_i/(b_i-1)) in Q16.16
                    if (idx < 1000) begin
                        a_val <= a_i[idx];
                        b_val <= b_i[idx];
                        
                        // Calculate factor = (a*b*65536) / ((a-1)*(b-1))
                        // This gives the multiplicative factor in Q16.16
                        num_val <= a_i[idx] * b_i[idx];  // a * b (20 bits max)
                        den_val <= (a_i[idx] - 10'd1) * (b_i[idx] - 10'd1);  // (a-1)*(b-1)
                        
                        // Perform division
                        if (a_i[idx] > 10'd1 && b_i[idx] > 10'd1) begin
                            fact_val <= (a_i[idx] * b_i[idx] * 65536) / ((a_i[idx] - 10'd1) * (b_i[idx] - 10'd1));
                            product <= (product * ((a_i[idx] * b_i[idx] * 65536) / ((a_i[idx] - 10'd1) * (b_i[idx] - 10'd1)))) >> 16;
                        end else begin
                            // Coefficient is 1, mark invalid
                            invalid <= 1'b1;
                            state <= ERROR;
                        end
                        
                        idx <= idx + 16'd1;
                    end
                end
                
                FINISH: begin
                    // final_result = m * product - m (in Q16.16)
                    result <= (m_q16 * product) - m_q16;
                    done <= 1'b1;
                    cycle_count <= 17'd0;
                end
                
                ERROR: begin
                    result <= 32'hFFFFFFFF;  // -1
                    done <= 1'b1;
                    cycle_count <= 17'd0;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= 17'd100000 && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end
endmodule

// Final optimized version
module MinimumFuel (
    input clk,
    input rst_n,
    input start,
    input [9:0] a_i [0:999],
    input [9:0] b_i [0:999],
    input [9:0] m,
    output reg [31:0] result,
    output reg done
);

    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] CHECK   = 4'd1;
    localparam [3:0] COMPUTE = 4'd2;
    localparam [3:0] FINISH  = 4'd3;
    localparam [3:0] ERROR   = 4'd4;

    reg [3:0] state;
    reg [15:0] idx;
    reg [31:0] product;
    reg [31:0] m_q16;
    reg invalid;
    reg [16:0] cycles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            idx <= 16'd0;
            product <= 32'd65536;
            m_q16 <= 32'd0;
            invalid <= 1'b0;
            cycles <= 17'd0;
        end else begin
            cycles <= cycles + 17'd1;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    product <= 32'd65536;
                    idx <= 16'd0;
                    invalid <= 1'b0;
                    cycles <= 17'd0;
                    m_q16 <= {m, 16'd0};
                    result <= 32'd0;
                    if (start) state <= CHECK;
                end

                CHECK: begin
                    // Check for invalid (coefficient = 1)
                    if (a_i[idx] == 10'd1 || b_i[idx] == 10'd1) begin
                        invalid <= 1'b1;
                    end
                    idx <= idx + 16'd1;
                    if (idx >= 1000) begin
                        if (invalid) state <= ERROR;
                        else state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (idx < 1000) begin
                        // Compute factor for this planet in Q16.16
                        // factor = (a_i * b_i * 65536) / ((a_i - 1) * (b_i - 1))
                        if (a_i[idx] > 10'd1 && b_i[idx] > 10'd1) begin
                            product <= (product * ((a_i[idx] * b_i[idx] * 65536) / ((a_i[idx] - 10'd1) * (b_i[idx] - 10'd1)))) >> 16;
                            idx <= idx + 16'd1;
                        end else begin
                            invalid <= 1'b1;
                            state <= ERROR;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // result = m * product - m (all in Q16.16)
                    result <= (m_q16 * product) - m_q16;
                    done <= 1'b1;
                    cycles <= 17'd0;
                end

                ERROR: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    cycles <= 17'd0;
                end

                default: state <= IDLE;
            endcase

            if (cycles >= 17'd100000 && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end
endmodule
