module digit_distance(
    input clk,
    input rst_n,
    input start,
    input [31:0] n1,
    input [31:0] n2,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CALC_DIFF = 3'b001;
    localparam EXTRACT_DIGITS = 3'b010;
    localparam DONE = 3'b011;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] diff_reg, next_diff_reg;
    reg [7:0] sum_reg, next_sum_reg;
    reg [4:0] count_reg, next_count_reg; // Counter for digit extraction (max 10)
    reg [31:0] temp_diff, next_temp_diff; // Working variable for division
    reg [7:0] temp_sum, next_temp_sum; // Working variable for sum

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            diff_reg <= 32'b0;
            sum_reg <= 8'b0;
            count_reg <= 5'b0;
            temp_diff <= 32'b0;
            temp_sum <= 8'b0;
            result <= 8'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            diff_reg <= next_diff_reg;
            sum_reg <= next_sum_reg;
            count_reg <= next_count_reg;
            temp_diff <= next_temp_diff;
            temp_sum <= next_temp_sum;
            
            // Done is asserted only in DONE state
            if (state == DONE) begin
                result <= sum_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_diff_reg = diff_reg;
        next_sum_reg = sum_reg;
        next_count_reg = count_reg;
        next_temp_diff = temp_diff;
        next_temp_sum = temp_sum;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_DIFF;
                    // Compute absolute difference in CALC_DIFF state
                    // But we need to pass values, so prepare here
                    next_sum_reg = 8'b0;
                    next_count_reg = 5'b0;
                    next_diff_reg = (n1 >= n2) ? (n1 - n2) : (n2 - n1);
                    next_temp_diff = (n1 >= n2) ? (n1 - n2) : (n2 - n1);
                    next_temp_sum = 8'b0;
                end
            end

            CALC_DIFF: begin
                // Just transition to extraction, diff is already computed in previous cycle
                next_state = EXTRACT_DIGITS;
                // Initialize extraction variables if diff was 0
                if (diff_reg == 32'b0) begin
                    next_sum_reg = 8'b0;
                    next_state = DONE;
                end
            end

            EXTRACT_DIGITS: begin
                // Iterate through digits: digit = temp_diff % 10, temp_diff = temp_diff / 10
                // Since we need iterative division, we'll do one digit per cycle
                if (temp_diff == 32'b0 || count_reg >= 10) begin
                    next_state = DONE;
                    next_sum_reg = temp_sum;
                end else begin
                    // Extract one digit (modulo 10) using repeated subtraction or property
                    // For modulo 10: check last 4 bits
                    // But for synthesis, let's do proper iterative division logic
                    // Since this is a combinational logic block, we compute next values
                    // However, we need to do division iteratively. 
                    // Strategy: each cycle subtract based on decimal place
                    
                    // Simplified: Use the last digit directly
                    // This requires a multiplier, but we can do shift-and-subtract division
                    // However, for this FSM, let's assume we do one digit extraction per cycle
                    
                    // To keep it simple and synthesizable without DSP:
                    // We will calculate next values based on current temp_diff
                    // But wait, we can't do division in one cycle without DSP or logic.
                    // So we must do it iteratively.
                    
                    // Let's use a standard iterative modulo algorithm:
                    // Since we have 10 cycles allowed, we can extract one digit at a time
                    // Using % 10 and / 10. 
                    // In hardware, % 10 is expensive. 
                    // However, the problem allows 10 iterations.
                    // Let's assume we use a small loop or unrolled logic.
                    // But for a generic FSM, let's do:
                    
                    // Re-evaluating: The problem asks for an iterative state machine.
                    // One cycle for remainder, one for division is 20 cycles, but we have 15.
                    // So we must do one digit per cycle.
                    // How to do digit % 10 and digit / 10 in one cycle?
                    // If we assume a standard ALU with divide instructions, it takes cycles.
                    // Since no clock is specified for the "logic", but we have a clocked FSM.
                    // Let's assume we can do modulo in one cycle or use the remainder register approach.
                    
                    // Revised Strategy for EXTRACT_DIGITS state:
                    // We need to implement a sequential divider.
                    // Let's add divider logic. 
                    // Actually, since the problem says "Loop counter for digit extraction (max 10 iterations)" and "Each iteration: digit = diff % 10, diff = diff / 10",
                    // we need a state that iterates.
                    // We can use the `div` and `mod` operators if the synthesis tool supports it for constants, but it implies a combinational block.
                    // To be truly sequential and efficient:
                    // We will do the subtraction based division loop.
                    
                    // BUT, if we are just writing the FSM controller, the combinational logic block handles the transition.
                    // Let's stick to the FSM flow. 
                    
                    // Wait, the problem states: "Integer division and modulo can be implemented iteratively with a state machine".
                    // This implies we need more sub-states or a longer latency.
                    // However, the specific states provided are IDLE, CALC_DIFF, EXTRACT_DIGITS, DONE.
                    // So EXTRACT_DIGITS must handle the loop.
                    
                    // Let's assume we do one digit per cycle. We need to calculate % 10 and / 10.
                    // Since we can't use hardware divider easily, we can use shift-add if binary to BCD, but we want binary to decimal sum.
                    // Actually, simple way: `digit = temp_diff % 10` and `temp_diff = temp_diff / 10`.
                    // In Verilog 2001/SystemVerilog, division is synthesizable but expensive.
                    // Given the constraint "Maximum value... 2 billion", we can implement a slow division if needed.
                    // However, to meet the "15 cycles" suggestion (2+10+3), we need to do it fast.
                    // 
                    // Let's use a combinational block for division inside the sequential logic's condition.
                    // But strictly speaking, for a valid "sequential" module, we should ideally not have heavy combinational paths.
                    // Given the constraints, I will use the `div` and `mod` operators in the combinational `always @(*)` block.
                    // This is standard for FPGAs and modern ASICs with optimized dividers.
                    
                    next_temp_diff = temp_diff / 10;
                    next_temp_sum = temp_sum + (temp_diff % 10);
                    next_count_reg = count_reg + 1;
                    
                    if (temp_diff < 10) begin
                        // Last digit
                        next_state = DONE;
                        next_sum_reg = temp_sum + temp_diff;
                    end else if (count_reg >= 9) begin // Safety for 10 digits
                        next_state = DONE;
                        next_sum_reg = next_temp_sum;
                    end
                end
            end

            DONE: begin
                // Wait for start to go low
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule