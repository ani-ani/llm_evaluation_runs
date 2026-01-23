module digits_product(
    input clk,
    input rst_n,
    input start,
    input [7:0] number,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam INIT = 5'b00010;
    localparam PROCESS_DIGIT_0 = 5'b00100;
    localparam PROCESS_DIGIT_1 = 5'b01000;
    localparam PROCESS_DIGIT_2 = 5'b10000;
    // PROCESS_DIGIT_2 leads to DONE directly or through next state logic
    // Requirement says latency 5 cycles after start, states: IDLE, INIT, 3 PROCESS states, DONE.
    // That is 5 states, so we stay in PROCESS_DIGIT_2 for one cycle, then go to DONE, then back to IDLE.
    // Or combine PROCESS_DIGIT_2 processing and transition to DONE in same cycle if combinational output allows.
    // Requirement: "Complete in 3 clock cycles (one per digit) plus 1 cycle for initialization."
    // "Specify latency: Result valid 5 clock cycles after start asserted."
    // Start asserted in IDLE. Next cycle INIT. Next cycle Digit0. Next cycle Digit1. Next cycle Digit2.
    // At end of Digit2 cycle, result is ready. So we need to stay in Digit2 for the multiplication.
    // Then transition to DONE. That makes 5 cycles from start (assertion) to result validity.
    // Wait, if start is high in cycle 0, INIT in cycle 1, Digit0 in 2, Digit1 in 3, Digit2 in 4.
    // Result ready at end of cycle 4. So we need 5 cycles from start asserted to done/result valid.
    // Let's use states: IDLE -> INIT -> P0 -> P1 -> P2 -> DONE -> IDLE.
    // That is 6 states, but only 5 active steps. We can merge P2 and DONE or use a counter.
    // Let's stick to the named states requested: IDLE, INIT, PROCESS_DIGIT_0, PROCESS_DIGIT_1, PROCESS_DIGIT_2, DONE.
    // We will spend 1 cycle in each, total 6 states. 
    // Wait, the requirement says "Complete in 3 clock cycles (one per digit) plus 1 cycle for initialization".
    // That implies INIT (1) + P0 (1) + P1 (1) + P2 (1) = 4 cycles of computation.
    // "Latency: Result valid 5 clock cycles after start asserted."
    // If start is asserted in cycle N, result valid in cycle N+5.
    // That implies 5 cycles total delay. 
    // Cycle 0: Start high (IDLE). Cycle 1: INIT. Cycle 2: P0. Cycle 3: P1. Cycle 4: P2. Cycle 5: DONE (result valid).
    // Or Cycle 4: P2 (result computed), Cycle 5: DONE.
    // To match exactly 5 cycles latency: 
    // Cycle 0: Start (IDLE). Cycle 1: INIT. Cycle 2: P0. Cycle 3: P1. Cycle 4: P2. 
    // If we transition to DONE on cycle 5 and assert done, that is 5 cycles.
    // However, if result is valid in P2, we might not need a separate DONE state if we keep done high in IDLE.
    // But we are asked for states: IDLE, INIT, P0, P1, P2, DONE.
    // That is 6 states. If we are IDLE for 1, then 4 processing, then DONE, that is 6 cycles.
    // Let's check: "Complete in 3 clock cycles (one per digit) plus 1 cycle for initialization."
    // This sounds like the active computation takes 4 cycles.
    // If we start at cycle 0 (start high): 
    // Cycle 1: INIT. Cycle 2: P0. Cycle 3: P1. Cycle 4: P2. Computation done.
    // We can go to DONE in cycle 5 or stay in P2.
    // Let's assume we use a 3-bit counter or state register to manage the flow.
    // We will map states as requested.
    // To achieve 5 cycles latency: 
    // Cycle 0: Start (IDLE). 
    // Cycle 1: INIT. 
    // Cycle 2: PROCESS_DIGIT_0. 
    // Cycle 3: PROCESS_DIGIT_1. 
    // Cycle 4: PROCESS_DIGIT_2. 
    // Cycle 5: DONE. 
    // This requires 6 states (IDLE + 4 processing + DONE = 6). 
    // Wait, "3 clock cycles (one per digit) plus 1 cycle for initialization" = 4 cycles.
    // If start is in cycle 0, done in cycle 4, latency is 4.
    // If done in cycle 5, latency is 5.
    // Let's strictly follow the state names and latency requirement.
    // We will use a 3-bit counter to track progress and map it to states.
    // 000: IDLE
    // 001: INIT
    // 010: PROCESS_DIGIT_0
    // 011: PROCESS_DIGIT_1
    // 100: PROCESS_DIGIT_2
    // 101: DONE
    // 110, 111: unused

    reg [2:0] current_state, next_state;
    reg [15:0] temp_product;
    reg [7:0] temp_number;
    reg [3:0] digit;
    
    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: next_state = PROCESS_DIGIT_0;
            PROCESS_DIGIT_0: next_state = PROCESS_DIGIT_1;
            PROCESS_DIGIT_1: next_state = PROCESS_DIGIT_2;
            PROCESS_DIGIT_2: next_state = DONE;
            DONE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = INIT; // If start stays high, restart (or stay DONE? Let's restart on start)
            end
            default: next_state = IDLE;
        endcase
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
            temp_product <= 16'b0;
            temp_number <= 8'b0;
            digit <= 4'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'b0; // Initialize result to 0 (default for no odd digits)
                end

                INIT: begin
                    // Load input number and initialize product to 1
                    temp_number <= number;
                    temp_product <= 16'b1;
                end

                PROCESS_DIGIT_0: begin
                    // Extract ones digit: number % 10 (using temp_number which holds original 'number')
                    // Note: For PROCESS_DIGIT_0, we use original number. 
                    // For PROCESS_DIGIT_1 and 2, we need to divide by 10 and 100.
                    // We can update temp_number or compute inline.
                    // Let's use temp_number for cumulative division.
                    // In INIT: temp_number = number
                    // In P0: Extract temp_number % 10. Then temp_number = temp_number / 10.
                    // In P1: Extract temp_number % 10. Then temp_number = temp_number / 10.
                    // In P2: Extract temp_number % 10.
                    
                    digit <= temp_number % 10;
                    temp_number <= temp_number / 10;
                end

                PROCESS_DIGIT_1: begin
                    digit <= temp_number % 10;
                    temp_number <= temp_number / 10;
                end

                PROCESS_DIGIT_2: begin
                    digit <= temp_number % 10;
                    // At this stage we have digit. We update product.
                    // If digit is odd, multiply.
                    // We update temp_product.
                    // Then we assign result = temp_product (updated).
                end

                DONE: begin
                    // In PROCESS_DIGIT_2 we updated product. 
                    // However, we need to handle the case where no odd digits exist.
                    // If temp_product remains 1 (from INIT), and no multiplication happened, result should be 0.
                    // We can check this in DONE state.
                    if (temp_product == 16'b1) 
                        result <= 16'b0;
                    else
                        result <= temp_product;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational multiplication logic to be used in PROCESS_DIGIT_2 (or all if we wanted)
    // We need to update temp_product in PROCESS_DIGIT_2 state based on the 'digit' captured in that cycle.
    // Wait, the extraction in PROCESS_DIGIT_2 happens at the same time as the multiplication.
    // The sequence of operations within a state depends on clock edge.
    // We have 'digit' register updated from previous state (P1).
    // In P2 state logic (always block), we need to decide whether to multiply.
    // But the multiplication should happen for the digit extracted in P2.
    // P2 state does two things: Extract digit % 10 (from current temp_number) and multiply if that digit is odd.
    // Since we are doing sequential logic, we need to be careful with the ordering.
    // We can do this by capturing the digit in P2 (inside the sequential block) and using it.
    // But we also need to update temp_product in P2.
    // Actually, let's refine P2:
    // In P2 state, we calculate the digit from the remaining temp_number (which holds hundreds digit).
    // And we multiply temp_product by this digit if it is odd.
    // We need to perform this update in P2 state.
    // However, since we are inside a sequential block, we can simply use the values.
    // The 'digit' calculated in P2 will be available for multiplication in P2.
    // But 'digit' is a register. If we read 'digit' in P2, it holds the value from P1.
    // We want the value from P2.
    // So we should calculate the digit combinationally or use a wire.
    // Let's use combinational logic for digit extraction to avoid timing issues.

    wire [3:0] ones_digit;
    assign ones_digit = temp_number % 10;

    // Re-write the Datapath logic to use combinational extraction for current digit
    // and sequential update for registers.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
            temp_product <= 16'b0;
            temp_number <= 8'b0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Start triggered transition to INIT, logic handled in INIT
                        // But wait, if start is high in IDLE, next_state is INIT.
                        // So on next clock edge, we enter INIT.
                        // We should keep done low.
                    end
                end

                INIT: begin
                    temp_number <= number;
                    temp_product <= 16'b1;
                end

                PROCESS_DIGIT_0: begin
                    // Ones digit from current temp_number
                    if (ones_digit[0]) begin
                        temp_product <= temp_product * ones_digit;
                    end
                    // Shift right for next state
                    temp_number <= temp_number / 10;
                end

                PROCESS_DIGIT_1: begin
                    // Tens digit (now in ones place after division)
                    if (ones_digit[0]) begin
                        temp_product <= temp_product * ones_digit;
                    end
                    // Shift right for next state
                    temp_number <= temp_number / 10;
                end

                PROCESS_DIGIT_2: begin
                    // Hundreds digit
                    if (ones_digit[0]) begin
                        temp_product <= temp_product * ones_digit;
                    end
                    // At the end of this cycle, temp_product holds the final product (or 1 if none)
                end

                DONE: begin
                    if (temp_product == 16'b1) 
                        result <= 16'b0;
                    else
                        result <= temp_product;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
