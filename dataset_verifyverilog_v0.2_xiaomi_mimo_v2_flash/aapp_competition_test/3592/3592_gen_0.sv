module profit_calculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] total_profit,
    input [31:0] profit_pita,
    input [31:0] profit_pizza,
    output reg [31:0] num_pitas,
    output reg [31:0] num_pizzas,
    output reg valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCH = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [31:0] x; // current number of pitas
    reg [31:0] remainder;
    reg [31:0] pizza_count;
    reg div_valid;
    reg div_ready;
    reg [63:0] mul_op1;
    reg [63:0] mul_op2;
    wire [63:0] mul_res;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x <= 32'b0;
        end else begin
            state <= next_state;
            if (state == IDLE && start) begin
                x <= 32'b0;
            end else if (state == SEARCH) begin
                x <= x + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SEARCH : IDLE;
            SEARCH: begin
                // Check if we need to stop. We stop if remainder becomes negative.
                // Since x increments, once (x * profit_pita) > total_profit, remainder < 0.
                // We use the calculated remainder from the current cycle to decide transition.
                // Note: In synchronous logic, we check the condition based on current 'x' which corresponds to previous cycle's calculation.
                // However, here we pre-calculate for the next cycle's output.
                // Let's simplify: Check if current 'x' calculation yielded a negative remainder.
                // If current 'x' produces negative remainder, we are done.
                // Actually, logic is:
                // 1. x is current pita count.
                // 2. Compute remainder = total - x * profit_pita.
                // 3. If remainder < 0, go to DONE.
                // 4. Else if remainder % profit_pizza == 0, output valid.
                // 5. Increment x.
                // The check happens in combinational logic below.
                next_state = (remainder >= total_profit) && (x > 0) ? DONE : SEARCH; // Wait, remainder is decreasing. 
                // If x * profit_pita > total_profit, then total_profit - x * profit_pita < 0.
                // Let's use: (x * profit_pita) > total_profit.
                // We need to evaluate this condition.
                // To avoid timing loops, we check if x * profit_pita >= total_profit.
                // If so, next state is DONE.
                // But we must output valid result for the last valid x.
                // So we transition to DONE when we detect that the NEXT x will be invalid.
                // Or we can transition to DONE when current x is invalid.
                // Let's transition to DONE when current x yields negative remainder.
                if ($signed(remainder) < 0) next_state = DONE;
                else if (start) next_state = SEARCH; // stay in search if started
                else next_state = SEARCH;
            end
            DONE: next_state = start ? IDLE : DONE; // Wait for reset or start low? 
            // Typically done stays high until start goes low. Or until reset.
            // Let's stay in DONE until start goes low, then back to IDLE.
            default: next_state = IDLE;
        endcase
        
        // Correction for SEARCH state transition:
        // We need to stop when x * profit_pita > total_profit.
        // Since we calculate remainder = total - x * profit_pita.
        // If remainder < 0, we are done.
        // Since we are in state SEARCH, we want to transition to DONE when we detect this.
        // However, the state transition usually happens at the clock edge.
        // We need to look ahead or use the result of the current cycle.
        // If remainder < 0, next_state = DONE.
        if (state == SEARCH) begin
             // Logic moved inside the case block for clarity in synthesis
             if ($signed(remainder) < 0) next_state = DONE;
             else next_state = SEARCH;
        end
        if (state == DONE) begin
            if (!start) next_state = IDLE;
            else next_state = DONE;
        end
    end

    // Multiplication: x * profit_pita
    // Use a multiplier or combinational logic. 
    // Since total_profit <= 1,000,000, 32x32 multiplication fits in 64 bits.
    // We compute this combinationally.
    always @(*) begin
        mul_op1 = {32'b0, x};
        mul_op2 = {32'b0, profit_pita};
    end
    assign mul_res = mul_op1 * mul_op2; // Combinational multiplier

    // Remainder calculation: total_profit - (x * profit_pita)
    // Since mul_res is 64 bits and total_profit is 32, we cast.
    // Check boundary: x * profit_pita might exceed total_profit.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remainder <= 32'b0;
            div_valid <= 1'b0;
        end else begin
            if (state == IDLE && start) begin
                remainder <= total_profit; // x=0 case logic handled in SEARCH next cycle? No, x resets to 0 in SEARCH.
                // Let's align remainder with x.
                // When x=0, remainder = total_profit.
                // Calculation for x=0 happens in SEARCH state.
                // We need to compute remainder for the current x.
                // So on posedge clk:
                // x increments. 
                // We compute remainder for the new x.
                // To align valid output:
                // Cycle 1: x=0. Compute rem. Output valid if divisible.
                // Cycle 2: x=1. Compute rem. Output valid.
                // So we compute remainder in the cycle where x is valid.
                // We do this combinationally from x.
                // But we need to store it if we want to use it in next state logic?
                // No, next state logic is combinational.
                // However, the problem asks for a sequential module.
                // Let's pipeline the remainder calculation to avoid long paths.
                // Pipeline Stage 1: Compute Mul.
                // Pipeline Stage 2: Compute Rem.
                // Pipeline Stage 3: Check Divisibility.
                // Pipeline Stage 4: Output.
                // But constraints say approx 100-200 cycles latency. 
                // It doesn't specify high frequency requirement.
                // Let's stick to a simple 1-cycle per iteration approach.
                // To make it efficient, we need to hide the latency of division.
                // Division is expensive.
                // We can perform the division check for x in parallel with calculating x+1's remainder.
                // Wait, we can't check x without remainder.
                // So, let's compute remainder in one cycle.
                // But division check takes many cycles (or needs combinational divider).
                // Given the constraints (100-200 cycles total), it implies a sequential search (one per cycle).
                // Therefore, the remainder and division check must be combinational OR fast enough.
                // But division is not a single cycle operation in hardware usually.
                // However, we are asked for a specific algorithm.
                // "Iterate x... Output one combination per clock cycle".
                // This implies we need to solve the division in 1 cycle or wait.
                // If we assume a combinational divider (area expensive but fits in 1 cycle): 
                // 1. Compute Remainder (Combinational from current x).
                // 2. Check if Remainder >= 0.
                // 3. Check if Remainder % profit_pizza == 0 (Combinational).
                // 4. If yes, valid = 1.
                // 5. Update x on next clock edge.
                // This is the standard interpretation for such assignment questions unless 'done' implies latency.
                // Let's implement combinational remainder and division check.
            end
            
            // Valid signal logic
            // Valid is high if remainder >= 0 and remainder is divisible by profit_pizza.
            // We need to handle the check.
            // Check divisibility: (remainder % profit_pizza) == 0.
            // This usually takes cycles. 
            // To adhere to "one per clock cycle", we will assume we can compute this in 1 cycle for this specific task.
            // Or use a simple status update.
            
            // Let's refine the remainder logic to be registered.
            // We register the result of (total - x*pita) to break the comb path.
            // However, we need the result NOW to decide valid.
            // If we register it, we are one cycle late.
            // Let's assume a single cycle implementation where latency is not the primary constraint, but functionality is.
            // We will perform the subtraction and check in combinational logic.
            
            // Actually, let's look at the state machine again.
            // If we stay in SEARCH state, we output valid.
            // If valid, we increment x.
            // If not valid, we increment x.
            // We stop when x * profit_pita > total_profit.
            
            // Revised sequential logic:
            // Calculate remainder combinationally based on current x.
            // If remainder < 0, transition to DONE.
            // Else, calculate division check combinationally.
            // If divisible, valid = 1.
            // Else valid = 0.
            // num_pitas = x.
            // num_pizzas = remainder / profit_pizza.
        end
    end
    
    // Combinational Logic for current cycle outputs
    // We calculate this based on the current value of x (which updates on clock edge)
    wire [63:0] x_ext = {32'b0, x};
    wire [63:0] pita_ext = {32'b0, profit_pita};
    wire [63:0] current_mul = x_ext * pita_ext;
    wire [63:0] current_rem_ext = (current_mul > total_profit) ? 64'hFFFF_FFFF_FFFF_FFFF : ({32'b0, total_profit} - current_mul);
    
    // For division check, we need combinational division or status.
    // Since synthesis of arbitrary division in 1 cycle is heavy, but allowed here by the "one per cycle" requirement without mentioning latency.
    // We assume standard division logic (iterative or combinational) is acceptable.
    // However, we cannot write iterative division in pure combinational block (it would be a loop).
    // We must rely on the tool or assume a fast divider.
    // OR, we implement a small FSM just for the division check? 
    // No, the module has a main FSM. 
    // To be robust, let's assume we have a "divisible" flag calculated in a previous cycle.
    // Wait, if we need to output one per cycle, and we have to iterate 100-200 times, 
    // the only way to do this sequentially is to have the check be 1 cycle or less.
    // So we will use a combinational check using the `/` and `%` operators.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            done <= 1'b0;
            num_pitas <= 32'b0;
            num_pizzas <= 32'b0;
        end else begin
            // Default assignments
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b1; // Idle implies done/ready
                    valid <= 1'b0;
                    if (start) begin
                        done <= 1'b0;
                    end
                end
                
                SEARCH: begin
                    // Check for termination condition first
                    // If current x makes remainder negative, we are done (no valid output this cycle)
                    if ($signed(current_rem_ext) < 0) begin
                        done <= 1'b1;
                        // transition to DONE handled by next_state logic
                        // But we need to assert done now for this cycle? 
                        // The next_state logic sets next_state = DONE.
                        // So on the NEXT clock edge, we enter DONE.
                        // So here we just finish the SEARCH cycle.
                    end else begin
                        // Check divisibility
                        if (current_rem_ext % profit_pizza == 0) begin
                            valid <= 1'b1;
                            num_pitas <= x;
                            num_pizzas <= current_rem_ext / profit_pizza;
                        end
                        // x will increment on next clock edge handled by sequential block
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    if (!start) begin
                        // Reset logic is handled by the reset block or returning to IDLE
                        // But next_state logic handles the return to IDLE.
                    end
                end
            endcase
        end
    end

endmodule