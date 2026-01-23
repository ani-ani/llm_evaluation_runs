module exponial_mod(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam CALC_BASE = 3'd1;
    localparam RECURSE = 3'd2;
    localparam POWER = 3'd3;
    localparam DONE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Computation registers
    reg [15:0] current_n;
    reg [15:0] current_m;
    reg [15:0] exp_result;      // Stores exponial(n-1) result
    reg [15:0] power_base;
    reg [15:0] power_exp;
    reg [15:0] power_result;
    reg [15:0] power_temp_base;
    reg [15:0] power_temp_result;
    reg [15:0] power_temp_exp;
    reg [5:0]  power_counter;   // Counter for exponentiation loop (max 16 bits)
    reg        power_mult_valid; // Flag for multiplication step
    
    // Stack for recursion (stores n values, max depth 6)
    reg [15:0] n_stack [0:5];
    reg [2:0]  stack_ptr;
    
    // Multiplication result register
    reg [31:0] mult_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            stack_ptr <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                        current_m <= m;
                        done <= 1'b0;
                        stack_ptr <= 3'd0;
                    end
                end
                
                CALC_BASE: begin
                    // Base case: exponial(1) = 1
                    if (current_n == 16'd1) begin
                        result <= (current_m == 16'd0) ? 16'd0 : 16'd1;
                        done <= 1'b1;
                    end
                end
                
                RECURSE: begin
                    // Push current n to stack and prepare for recursion
                    if (stack_ptr < 3'd6) begin
                        n_stack[stack_ptr] <= current_n;
                        stack_ptr <= stack_ptr + 1;
                        current_n <= current_n - 16'd1;
                    end
                end
                
                POWER: begin
                    // Modular exponentiation: base^exp mod m
                    if (power_counter == 6'd0) begin
                        // Initialize
                        power_temp_base <= power_base;
                        power_temp_exp <= power_exp;
                        power_temp_result <= 16'd1;
                        power_counter <= 6'd1;
                        power_mult_valid <= 1'b0;
                    end else if (power_temp_exp > 16'd0) begin
                        if (!power_mult_valid) begin
                            // Check LSB and multiply if needed
                            if (power_temp_exp[0]) begin
                                mult_result <= power_temp_result * power_temp_base;
                                power_mult_valid <= 1'b1;
                            end else begin
                                power_mult_valid <= 1'b1; // Skip to square
                            end
                        end else begin
                            // After multiplication (or skip), do square
                            if (power_temp_exp[0]) begin
                                power_temp_result <= mult_result % current_m;
                            end
                            // Square the base
                            mult_result <= power_temp_base * power_temp_base;
                            power_temp_base <= (power_temp_base * power_temp_base) % current_m;
                            power_temp_exp <= power_temp_exp >> 1;
                            power_mult_valid <= 1'b0;
                        end
                    end else begin
                        // Exponentiation complete
                        result <= power_temp_result;
                        power_counter <= 6'd0;
                    end
                end
                
                DONE: begin
                    // Done signal already handled, waiting for idle
                    if (!start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_BASE;
                end
            end
            
            CALC_BASE: begin
                if (current_n == 16'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = RECURSE;
                end
            end
            
            RECURSE: begin
                // After pushing to stack, check if we need more recursion
                if (current_n == 16'd1) begin
                    // Base case reached, compute result
                    next_state = POWER;
                    // Set up power: base = stacked_n, exp = 1 (since exponial(1)=1)
                    // But we need to pop stack and continue
                end else if (current_n > 16'd1) begin
                    next_state = RECURSE; // Continue recursing
                end else begin
                    // Shouldn't happen, but go to power
                    next_state = POWER;
                end
                
                // Check if we just computed exponial(n-1)
                // Actually, need to manage recursion properly
            end
            
            POWER: begin
                // Check if exponentiation is complete
                if (power_temp_exp == 16'd0 && power_counter > 6'd0) begin
                    next_state = DONE;
                end else if (power_counter > 6'd0 && power_temp_exp == 16'd0) begin
                    next_state = DONE;
                end else if (power_temp_exp == 16'd0 && power_mult_valid == 1'b0 && power_counter > 6'd0) begin
                    next_state = DONE;
                end
                // Handle nested power calls
                if (stack_ptr > 3'd0 && power_temp_exp == 16'd0 && power_counter > 6'd0) begin
                    // Pop stack and compute next level
                    // This needs complex state management
                end
            end
            
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Additional logic for recursive state management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                RECURSE: begin
                    if (current_n == 16'd1) begin
                        // Base case - set up power with result=1 and pop
                        power_base <= n_stack[stack_ptr - 1];
                        power_exp <= 16'd1; // exponial(1) = 1
                        power_counter <= 6'd0;
                    end
                end
                
                POWER: begin
                    // When power completes and stack has items, set up next level
                    if (power_temp_exp == 16'd0 && power_counter > 6'd0 && stack_ptr > 3'd0) begin
                        // Pop stack
                        stack_ptr <= stack_ptr - 1;
                        power_base <= n_stack[stack_ptr - 1];
                        power_exp <= power_temp_result; // Result from previous level
                        power_counter <= 6'd0;
                        next_state <= POWER;
                    end
                end
            endcase
        end
    end

endmodule

// Fixed recursive implementation
module exponial_mod_fixed(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam START_COMP = 3'd1;
    localparam POWER = 3'd2;
    localparam NEXT_LEVEL = 3'd3;
    localparam DONE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [15:0] current_n;
    reg [15:0] current_m;
    reg [15:0] exp_result;
    reg [15:0] base_reg;
    reg [15:0] exp_reg;
    reg [15:0] pow_result;
    reg [15:0] temp_base;
    reg [15:0] temp_exp;
    reg [15:0] temp_result;
    reg [31:0] mult_temp;
    reg [4:0]  bit_counter; // 0-16
    
    // Stack for n values
    reg [15:0] n_stack [0:5];
    reg [2:0]  stack_depth;
    reg        stack_push;
    reg        stack_pop;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            stack_depth <= 3'd0;
            bit_counter <= 5'd0;
        end else begin
            state <= next_state;
            
            // Stack operations
            if (stack_push && stack_depth < 3'd6) begin
                n_stack[stack_depth] <= current_n;
                stack_depth <= stack_depth + 1;
            end else if (stack_pop && stack_depth > 3'd0) begin
                stack_depth <= stack_depth - 1;
            end
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                        current_m <= m;
                        done <= 1'b0;
                        stack_depth <= 3'd0;
                        bit_counter <= 5'd0;
                    end
                end
                
                START_COMP: begin
                    if (current_n == 16'd1) begin
                        // Base case: exponial(1) = 1
                        result <= (current_m == 16'd0) ? 16'd0 : 16'd1;
                        done <= 1'b1;
                    end else if (stack_depth < 3'd6 && current_n > 1) begin
                        // Push current n and recurse to n-1
                        n_stack[stack_depth] <= current_n;
                        stack_depth <= stack_depth + 1;
                        current_n <= current_n - 16'd1;
                    end
                end
                
                POWER: begin
                    // Initialize modular exponentiation
                    if (bit_counter == 5'd0) begin
                        temp_base <= base_reg % current_m;
                        temp_exp <= exp_reg;
                        temp_result <= 16'd1;
                        bit_counter <= 5'd1;
                    end else if (bit_counter <= 5'd16) begin
                        if (temp_exp[0]) begin
                            mult_temp <= temp_result * temp_base;
                            temp_result <= (temp_result * temp_base) % current_m;
                        end
                        // Always square
                        temp_base <= (temp_base * temp_base) % current_m;
                        temp_exp <= temp_exp >> 1;
                        bit_counter <= bit_counter + 1;
                    end
                end
                
                NEXT_LEVEL: begin
                    // Move to next recursion level
                    if (stack_depth > 3'd0) begin
                        base_reg <= n_stack[stack_depth - 1];
                        exp_reg <= temp_result; // Result from current level
                        stack_depth <= stack_depth - 1;
                        bit_counter <= 5'd0;
                    end
                end
                
                DONE: begin
                    if (!start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        stack_push = 1'b0;
        stack_pop = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START_COMP;
                end
            end
            
            START_COMP: begin
                if (current_n == 16'd1) begin
                    next_state = DONE;
                end else if (stack_depth < 3'd6 && current_n > 1) begin
                    // Push and recurse
                    stack_push = 1'b1;
                    if (current_n - 1 == 16'd1) begin
                        // Would hit base case next - prepare for power
                        next_state = START_COMP;
                    end else begin
                        next_state = START_COMP;
                    end
                end
                // Special handling: when we should compute power
                if (current_n > 1 && (current_n - 1 == 16'd1 || stack_depth > 0)) begin
                    // Check if we need to compute power
                end
            end
            
            POWER: begin
                if (bit_counter > 5'd16) begin
                    // Computation complete
                    if (stack_depth > 3'd0) begin
                        next_state = NEXT_LEVEL;
                    end else begin
                        result <= temp_result;
                        next_state = DONE;
                    end
                end else begin
                    next_state = POWER;
                end
            end
            
            NEXT_LEVEL: begin
                // Set up for next power computation
                next_state = POWER;
            end
            
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule

// Corrected final version with proper state transitions
module exponial_mod(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

    localparam IDLE = 3'd0;
    localparam CHECK = 3'd1;
    localparam SETUP = 3'd2;
    localparam POWER = 3'd3;
    localparam DONE = 3'd4;

    reg [2:0] state;
    reg [15:0] current_n;
    reg [15:0] current_m;
    reg [15:0] work_base;
    reg [15:0] work_exp;
    reg [15:0] work_result;
    reg [15:0] work_mod;
    reg [4:0]  bit_cnt;
    reg [2:0]  depth;
    reg [15:0] n_stack [0:5];
    reg        pop_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            depth <= 3'd0;
            bit_cnt <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                        current_m <= m;
                        depth <= 3'd0;
                        done <= 1'b0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (current_n == 16'd1) begin
                        // Base case: exponial(1) = 1 % m
                        result <= (current_m == 16'd0) ? 16'd0 : 16'd1 % current_m;
                        if (depth == 3'd0) begin
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Return to previous level
                            work_result <= (current_m == 16'd0) ? 16'd0 : 16'd1 % current_m;
                            state <= SETUP;
                        end
                    end else if (current_n > 1 && depth < 3'd6) begin
                        // Push to stack and recurse
                        n_stack[depth] <= current_n;
                        depth <= depth + 1;
                        current_n <= current_n - 16'd1;
                        state <= CHECK;
                    end else begin
                        // Should not reach here
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                SETUP: begin
                    // Setup for exponentiation: base = n from stack, exp = result from recursion
                    if (depth > 3'd0) begin
                        depth <= depth - 1;
                        work_base <= n_stack[depth - 1];
                        work_exp <= work_result;
                        work_mod <= current_m;
                        work_result <= 16'd1;
                        bit_cnt <= 5'd0;
                        state <= POWER;
                    end else begin
                        // Final result
                        result <= work_result;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                POWER: begin
                    if (bit_cnt < 5'd16 && work_exp > 16'd0) begin
                        if (work_exp[0]) begin
                            work_result <= (work_result * work_base) % work_mod;
                        end
                        work_base <= (work_base * work_base) % work_mod;
                        work_exp <= work_exp >> 1;
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        // Exponentiation complete
                        if (depth > 3'd0) begin
                            // More levels to go
                            state <= SETUP;
                        end else begin
                            result <= work_result;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule

module exponial_mod(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

    localparam IDLE = 3'd0;
    localparam CHECK = 3'd1;
    localparam SETUP = 3'd2;
    localparam POWER = 3'd3;
    localparam DONE = 3'd4;

    reg [2:0] state;
    reg [15:0] current_n;
    reg [15:0] current_m;
    reg [15:0] work_base;
    reg [15:0] work_exp;
    reg [15:0] work_result;
    reg [15:0] work_mod;
    reg [4:0]  bit_cnt;
    reg [2:0]  depth;
    reg [15:0] n_stack [0:5];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            depth <= 3'd0;
            bit_cnt <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                        current_m <= m;
                        depth <= 3'd0;
                        done <= 1'b0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (current_n == 16'd1) begin
                        if (depth == 3'd0) begin
                            result <= (current_m == 16'd0) ? 16'd0 : 16'd1;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            work_result <= (current_m == 16'd0) ? 16'd0 : 16'd1;
                            state <= SETUP;
                        end
                    end else if (depth < 3'd6) begin
                        n_stack[depth] <= current_n;
                        depth <= depth + 1;
                        current_n <= current_n - 16'd1;
                        state <= CHECK;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                SETUP: begin
                    if (depth > 3'd0) begin
                        depth <= depth - 1;
                        work_base <= n_stack[depth - 1];
                        work_exp <= work_result;
                        work_mod <= current_m;
                        work_result <= 16'd1;
                        bit_cnt <= 5'd0;
                        state <= POWER;
                    end else begin
                        result <= work_result;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                POWER: begin
                    if (bit_cnt < 5'd16 && work_exp > 16'd0) begin
                        if (work_exp[0]) begin
                            work_result <= (work_result * work_base) % work_mod;
                        end
                        work_base <= (work_base * work_base) % work_mod;
                        work_exp <= work_exp >> 1;
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        if (depth > 3'd0) begin
                            state <= SETUP;
                        end else begin
                            result <= work_result;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule