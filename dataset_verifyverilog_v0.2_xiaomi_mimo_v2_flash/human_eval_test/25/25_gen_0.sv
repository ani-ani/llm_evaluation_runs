module factorize (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] factors_out,
    output reg factors_valid,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_DIVISOR = 3'b001;
    localparam OUTPUT_FACTOR = 3'b010;
    localparam INCREMENT_DIVISOR = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [15:0] current_n;
    reg [15:0] divisor;
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Combinational signals for division and comparison
    wire [15:0] quotient;
    wire [15:0] remainder;
    wire [15:0] divisor_squared;
    wire is_divisible;
    wire divisor_gt_sqrt;

    // Combinational division logic (restoring division for efficiency)
    // Using combinational logic to compute remainder and quotient
    // For 16-bit division, this is synthesizable and fast enough
    assign {quotient, remainder} = div_mod(current_n, divisor);
    assign is_divisible = (remainder == 16'b0);
    
    // Compute divisor * divisor
    assign divisor_squared = divisor * divisor;
    
    // Check if divisor^2 > current_n (early termination condition)
    assign divisor_gt_sqrt = (divisor_squared > current_n);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = current_state; // Default to stay in current state
        factors_valid = 1'b0;
        done = 1'b0;
        factors_out = factors_out; // Keep previous value
        
        case (current_state)
            IDLE: begin
                done = 1'b1;
                if (start) begin
                    done = 1'b0;
                    if (n <= 16'd1) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK_DIVISOR;
                    end
                end
            end
            
            CHECK_DIVISOR: begin
                if (is_divisible) begin
                    next_state = OUTPUT_FACTOR;
                end else begin
                    next_state = INCREMENT_DIVISOR;
                end
            end
            
            OUTPUT_FACTOR: begin
                factors_out = divisor;
                factors_valid = 1'b1;
                // Next state depends on remaining n
                // Updated current_n will be available in next cycle from sequential logic
                // But for next state decision, we need to check if quotient <= 1
                // Since quotient is computed combinationally, we need to think carefully
                // Actually, let's compute the check with current_n and divisor
                // We'll handle the transition in sequential logic to avoid combinational loops
                // For now, just transition to CHECK_DIVISOR
                next_state = CHECK_DIVISOR;
            end
            
            INCREMENT_DIVISOR: begin
                // Check if we should continue or finish
                // divisor + 1 is computed, then check divisor^2 > n
                next_state = CHECK_DIVISOR;
                if (divisor + 1 > current_n) begin
                    // Should never happen as divisor < current_n always when n > 1
                    next_state = DONE;
                end
                // Also check if we increment to the point where divisor^2 > n
                // This will be evaluated after increment happens
            end
            
            DONE: begin
                done = 1'b1;
                next_state = DONE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic for updating state variables
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_n <= 16'b0;
            divisor <= 16'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start && n > 16'd1) begin
                        current_n <= n;
                        divisor <= 16'd2;
                    end
                end
                
                OUTPUT_FACTOR: begin
                    // Update current_n = current_n / divisor
                    current_n <= quotient;
                    // divisor stays the same (might divide by same factor again)
                    divisor <= divisor;
                end
                
                INCREMENT_DIVISOR: begin
                    // Increment divisor
                    divisor <= divisor + 1;
                    // Check early termination: if divisor^2 > n, then n is prime
                    // This happens when incremented divisor squared > original remaining n
                    // But we need to use pre-increment current_n
                    // Actually, the condition should be checked after increment
                    // So we'll increment, then next cycle in CHECK_DIVISOR, we check again
                    // But if current_n is 1, we're done
                    if (current_n <= 16'd1) begin
                        // This shouldn't happen if logic is correct
                    end
                end
                
                CHECK_DIVISOR: begin
                    // In this state, we might transition based on conditions
                    // But we already handle transitions in next_state logic
                    // We need to handle the case where current_n becomes 1 after division
                    // This is tricky because quotient is available combinationally
                    // Let's add special handling: if current_n <= 1, go to DONE
                    // But current_n updates from previous OUTPUT_FACTOR state
                end
                
                DONE: begin
                    // Stay in DONE
                end
            endcase
            
            // Additional condition to detect completion
            // If after OUTPUT_FACTOR, quotient is 1, we're done
            // This needs to be checked in the cycle after OUTPUT_FACTOR
            if (current_state == OUTPUT_FACTOR && quotient == 16'd1) begin
                // We just output the last factor
                // Next state should be DONE
                // This overrides next_state assignment
                // This is problematic because next_state is already assigned in combinational block
                // Let's handle this differently
            end
        end
    end
    
    // Fix for completion detection:
    // We need to handle the case where after division, quotient = 1
    // This should be caught in CHECK_DIVISOR state
    // Let's restructure the logic

    // Revised sequential logic to handle all updates cleanly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_n <= 16'b0;
            divisor <= 16'b0;
            current_state <= IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start && n > 16'd1) begin
                        current_n <= n;
                        divisor <= 16'd2;
                        current_state <= CHECK_DIVISOR;
                    end else if (start && n <= 16'd1) begin
                        current_state <= DONE;
                    end
                end
                
                CHECK_DIVISOR: begin
                    if (current_n == 16'd1) begin
                        current_state <= DONE;
                    end else if (is_divisible) begin
                        current_state <= OUTPUT_FACTOR;
                    end else begin
                        // Check if we should increment or finish
                        // Need to compute (divisor+1)^2 > current_n
                        // We'll compute increment and check in INCREMENT_DIVISOR state
                        current_state <= INCREMENT_DIVISOR;
                    end
                end
                
                OUTPUT_FACTOR: begin
                    factors_out <= divisor;
                    factors_valid <= 1'b1;
                    current_n <= quotient;
                    // Stay on same divisor (might divide again)
                    if (quotient == 16'd1) begin
                        current_state <= DONE;
                    end else begin
                        current_state <= CHECK_DIVISOR;
                    end
                end
                
                INCREMENT_DIVISOR: begin
                    divisor <= divisor + 1;
                    // After increment, need to check if new divisor^2 > current_n
                    // We'll check this in the next state (CHECK_DIVISOR)
                    // But we need to see if current_n is prime
                    // If divisor + 1 > current_n, then current_n is prime
                    // Actually, the condition is: if (divisor+1)^2 > current_n, then current_n is prime
                    // Let's set a flag or compute it next cycle
                    current_state <= CHECK_DIVISOR;
                end
                
                DONE: begin
                    factors_valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
            
            // Handle early termination after increment:
            // In INCREMENT_DIVISOR, after incrementing, if new divisor^2 > current_n, 
            // then current_n itself is prime (as a factor)
            // We need to detect this and output current_n as a factor, then go to DONE
            // This requires looking ahead or special handling
            
            // Revised approach: In INCREMENT_DIVISOR state, check before incrementing
            // If divisor^2 > current_n, then current_n is prime
            if (current_state == INCREMENT_DIVISOR) begin
                if (divisor_squared > current_n) begin
                    // current_n is prime, output it
                    factors_out <= current_n;
                    factors_valid <= 1'b1;
                    current_state <= DONE;
                end
            end
        end
    end
    
    // Update done signal based on state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b1;
        end else begin
            done <= (current_state == DONE);
        end
    end

    // Helper task for division (combinational)
    // We need to implement this as a function or continuous assignment
    // But Verilog functions can't have loops easily synthesizable
    // Let's use a recursive function or use built-in operators
    // Actually, we can just use the % and / operators which are synthesizable
    // However, they might be expensive, but for 16-bit it's acceptable
    
    // The following uses Verilog's built-in division which is synthesizable
    // To avoid issues with the function definition inside the module, 
    // let's just use the operators directly
    
endmodule

// We need to use the operators directly in the assigns
// The previous assigns used a function that doesn't exist
// Let's fix this

module factorize (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] factors_out,
    output reg factors_valid,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_DIVISOR = 3'b001;
    localparam OUTPUT_FACTOR = 3'b010;
    localparam INCREMENT_DIVISOR = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [15:0] current_n;
    reg [15:0] divisor;
    reg [2:0] current_state;
    reg factors_valid_reg;
    reg done_reg;

    // Combinational signals using built-in operators
    wire [15:0] quotient = current_n / divisor;
    wire [15:0] remainder = current_n % divisor;
    wire is_divisible = (remainder == 16'b0);
    wire [31:0] divisor_squared_32 = divisor * divisor;
    wire divisor_gt_sqrt = (divisor_squared_32[31:16] != 0) || (divisor_squared_32[15:0] > current_n);

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_n <= 16'b0;
            divisor <= 16'b0;
            factors_out <= 16'b0;
            factors_valid_reg <= 1'b0;
            done_reg <= 1'b1;
        end else begin
            factors_valid_reg <= 1'b0;
            done_reg <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    done_reg <= 1'b1;
                    if (start) begin
                        done_reg <= 1'b0;
                        if (n <= 16'd1) begin
                            current_state <= DONE;
                        end else begin
                            current_n <= n;
                            divisor <= 16'd2;
                            current_state <= CHECK_DIVISOR;
                        end
                    end
                end
                
                CHECK_DIVISOR: begin
                    if (current_n == 16'd1) begin
                        current_state <= DONE;
                    end else if (is_divisible) begin
                        current_state <= OUTPUT_FACTOR;
                    end else begin
                        // Check if divisor^2 > current_n (early termination)
                        // If true, current_n is prime
                        if (divisor_gt_sqrt) begin
                            factors_out <= current_n;
                            factors_valid_reg <= 1'b1;
                            current_state <= DONE;
                        end else begin
                            current_state <= INCREMENT_DIVISOR;
                        end
                    end
                end
                
                OUTPUT_FACTOR: begin
                    factors_out <= divisor;
                    factors_valid_reg <= 1'b1;
                    current_n <= quotient;
                    // Remain on same divisor to check for repeated factors
                    if (quotient == 16'd1) begin
                        current_state <= DONE;
                    end else begin
                        current_state <= CHECK_DIVISOR;
                    end
                end
                
                INCREMENT_DIVISOR: begin
                    divisor <= divisor + 1;
                    current_state <= CHECK_DIVISOR;
                end
                
                DONE: begin
                    done_reg <= 1'b1;
                end
            endcase
        end
    end

    // Assign outputs
    always @(*) begin
        factors_valid = factors_valid_reg;
        done = done_reg;
    end

endmodule