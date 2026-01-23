module grade_optimizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_subjects,
    input [7:0] total_time,
    input [9:0][31:0] params_a,
    input [9:0][31:0] params_b,
    input [9:0][31:0] params_c,
    output reg [31:0] avg_grade,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_DERIV = 3'b001;
    localparam ALLOCATE_TIME = 3'b010;
    localparam CHECK_DONE = 3'b011;
    localparam CALC_AVG = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Fixed point constants
    // dt = 0.01 hours = 0x000028F6 in Q16.16 (100 * 256 = 25600 = 0x6400 for step count logic? No, spec says 0x000028F6)
    // 0.01 * 65536 = 655.36 ~ 655 (0x028F). Spec says 0x000028F6 which is 10486. 
    // Let's calculate: 0.01 * 65536 = 655.36. 
    // Spec example 0.01 hours represented as 0x000028F6 (10486). 
    // 10486 / 65536 = 0.16. That's wrong. 
    // Wait, 24000 cycles for 240 hours. 240 / 24000 = 0.01. 
    // The total_time input is scaled by 100. E.g. 96.00 -> 9600.
    // If total_time is 9600, and we iterate until total_accumulated_time >= 9600.
    // We add dt (scaled by 100) each step? 
    // Let's assume total_time is in units of 0.01 hours.
    // So T=9600 means 96.00 hours.
    // The hardware increments by 1 per cycle until it hits total_time.
    // The dt constant for derivative calculation must be 0.01 in Q16.16.
    // 0.01 * 65536 = 655 (approx). 
    // Spec says 0x000028F6 (10486). 10486 / 65536 = 0.16. 
    // Maybe spec means 10486 is the step value for some internal counter?
    // Or maybe 0.01 hours is represented as 10486 in some scaling.
    // Let's use the spec value for dt_val: 10486 (0x28F6).
    // Let's use 0x028F (655) for 0.01 in Q16.16.
    // I will stick to standard Q16.16 math for derivatives.
    // Let's assume the total_time input is in units of 0.01 hours.
    // So we iterate total_time times.
    // Derivative step: dt = 0.01. 
    // 0.01 in Q16.16 is 655. 
    // However, let's trust the spec constant provided: 0x000028F6.
    // Let's check: 0x28F6 = 10486. 
    // If we use 0x28F6 as dt, 1 step adds 10486/65536 = 0.16 to allocation.
    // To get 0.01 total, we need 0.01 / 0.16 = 0.0625 steps. 
    // This doesn't match "one per time step".
    // Let's use 0x028F (approx 655) for 0.01 Q16.16.
    // Spec says "Time allocation resolution: 0.01 hours (represented as 0x000028F6 in Q16.16)".
    // I will interpret this as the step value to add to the time accumulator.
    // But for derivative calculation, we use the derivative of f(t) with respect to t.
    // If t increases by 0.01, grade increases by derivative * 0.01.
    // Let's use dt_q16 = 32'h000028F6. 

    // Regs for storage
    reg [9:0][31:0] current_alloc; // Q16.16 per subject
    reg [31:0] current_alloc_sum;  // Q16.16 sum of allocations
    reg [31:0] total_time_q16;      // Q16.16 total time (scaled by 100? No, logic suggests unit scale)
    // If total_time input is scaled by 100 (e.g. 9600), we need to scale it to Q16.16.
    // 9600 = 96.00. 
    // Q16.16: 96 * 65536 = 6,291,456.
    // Actually, if total_time is 9600 (96.00 scaled by 100), and we want to add 0.01 (scaled by 100?) per step.
    // Let's simplify: total_time input is T * 100.
    // We iterate total_time times.
    // Internal counter counts up to total_time.
    // Let's treat total_time input as the number of iterations needed.
    // This avoids Q16.16 overflow on the counter.
    
    reg [9:0][31:0] t_accumulator; // Q16.16 accumulation for derivatives
    
    // Derivatives calculation
    wire [31:0] deriv [0:9];
    wire [31:0] term1 [0:9];
    wire [31:0] term2 [0:9];
    
    // 2*a*t + b
    // a is Q16.16, t is Q16.16. Product is Q32.32. Need to shift right 16 to get Q16.16.
    // b is Q16.16.
    
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : deriv_gen
            // Calculate 2*a*t
            // 2*a is Q16.16, t is Q16.16. Result Q32.32. Shift 16.
            // To avoid mult overflow, maybe split.
            // Or use logic to multiply. 
            // We assume inputs are small enough for standard multiply if we keep to Q16.16.
            // But 2*a*t can be large.
            // Let's just do multiplication and truncation.
            
            // Optimization: Use separate always block for derivatives if needed, but combinational wire is fine for synthesis if sized correctly.
            
            // We only compute for active subjects (i < num_subjects).
            // We mask later.
            
            // 2 * a
            wire [31:0] a2;
            assign a2 = {params_a[i][30:0], 1'b0}; // Shift left 1 (multiply by 2)
            
            // Multiply a2 (Q16.16) * current_alloc (Q16.16)
            // Using a temporary large wire for product
            wire [63:0] prod_full;
            assign prod_full = { {32{a2[31]}}, a2 } * { {32{current_alloc[i][31]}}, current_alloc[i] };
            
            // Take bits [47:16] of result for Q16.16 (shift right 16 from Q32.32 part of product)
            // Product is Q32.32. We want Q16.16.
            // Signed multiplication result is 64 bits. 
            // We need bits [47:16] (signed).
            wire [31:0] mult_res;
            assign mult_res = prod_full[47:16];
            
            // Add b
            // Saturating add
            wire [31:0] deriv_sum;
            assign deriv_sum = mult_res + params_b[i];
            
            // Apply mask for valid subjects
            // If i >= num_subjects, derivative is 0 (or negative infinity to never be selected)
            // Let's output 0.
            assign deriv[i] = (i < num_subjects) ? deriv_sum : 32'h80000000; 
            // 0x80000000 is most negative. It will never be max if others are valid.
        end
    endgenerate

    // Max finder logic
    reg [31:0] max_deriv;
    reg [3:0] max_idx;
    integer k;
    
    always @(*) begin
        max_deriv = deriv[0];
        max_idx = 0;
        for (k = 1; k < 10; k = k + 1) begin
            if (k < num_subjects) begin
                if (deriv[k] > max_deriv) begin
                    max_deriv = deriv[k];
                    max_idx = k[3:0];
                end
            end
        end
    end

    // Counter for iterations (handling total_time scaled by 100)
    reg [15:0] iter_count;
    wire [15:0] total_iterations; // total_time * 100? No, total_time IS scaled by 100.
    // If total_time is 9600, we need 9600 iterations of 0.01? No.
    // total_time input is T * 100.
    // If T=96.00, input=9600.
    // We want to accumulate until sum of steps >= T.
    // Each step adds 0.01.
    // So number of steps = T / 0.01 = 96.00 / 0.01 = 9600.
    // So iter_count goes up to total_time input.
    assign total_iterations = total_time;

    // Registers for accumulator addition
    reg [31:0] new_alloc;
    wire [31:0] dt_q16 = 32'h000028F6; // Spec value. Wait, if we iterate 9600 times, and add 0.01 each time, total is 96.
    // If we use 0x28F6 (0.16) and iterate 9600 times, total is 1536.
    // To get 96, we need to iterate 600 times if adding 0.16.
    // Spec says "Resolution 0.01 hours (represented as 0x000028F6)".
    // Let's check 0.01 in Q16.16: 0.01 * 65536 = 655.36 -> 655 (0x028F).
    // 0x28F6 = 10486. 10486 / 65536 = 0.16.
    // Is it possible the spec meant 0x28F6 for a different scale?
    // Let's assume the spec meant the step size for the accumulator.
    // If total_time is given as 9600 (96.00 scaled), and we do 9600 cycles.
    // We need to add 0.01 per cycle.
    // Let's use 0x028F (approx 655).
    // I will use 0x028F to match "0.01 hours" description.
    // If the system expects 0x28F6, maybe I should use it, but that implies a resolution of 0.16h.
    // "Time allocation resolution: 0.01 hours". This is explicit.
    // "(represented as 0x000028F6 in Q16.16)". This contradicts standard Q16.16.
    // Maybe they meant 0x28F6 is the value to ADD to the accumulator.
    // 0x28F6 = 10486.
    // 10486 * 24000 = 251,664,000.
    // 251,664,000 / 65536 = 3840.0.
    // 3840 hours? No.
    // Let's re-read: "Time allocation resolution: 0.01 hours (represented as 0x000028F6 in Q16.16)".
    // Perhaps they scaled by 256? 0.01 * 256 = 2.56.
    // I will assume the intent is to iterate `total_time` times (which is T*100) and add a step.
    // I will calculate the step as 0.01 in Q16.16 = 0x028F.
    // However, to be safe and match the spec "0x000028F6" exactly as the step value, 
    // I will use that constant, but adjust the iteration count logic.
    // If step is 0.16, and T=96, we need 600 iterations.
    // But spec says "24000 (for T=240 hours with 0.01 steps)".
    // This confirms T=240, steps=0.01, iterations=24000.
    // So the step MUST be 0.01.
    // Therefore, the spec text "0x000028F6" must be a typo in the prompt.
    // 0.01 in Q16.16 is roughly 0x028F.
    // I will use 0x0000028F. 
    // Wait, 0x28F6 is 10486. 65536 * 0.16 = 10485.
    // Maybe they are using Q16.16 for 1.0? No.
    // Let's stick to the math: 0.01 * 65536 = 655.
    // I will use 32'd655 as the step.
    
    // Wait, looking at input: `total_time` is scaled by 100.
    // So if T=96.00, total_time = 9600.
    // We want to run for T hours. 
    // If we add 0.01 per step, we need 9600 steps.
    // So iter_count should count up to total_time input.
    
    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            avg_grade <= 0;
            iter_count <= 0;
            current_alloc_sum <= 0;
            // Reset allocations
            // Can't reset array directly in always block without loop or initial.
            // We will reset valid part in logic.
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC_DERIV;
                        iter_count <= 0;
                        current_alloc_sum <= 0;
                        // Clear allocations
                        // Need to clear current_alloc register array.
                        // We handle this by a clear flag or just overwriting in CALC_DERIV first step?
                        // Better to clear here.
                    end
                end

                CALC_DERIV: begin
                    // Just a pass-through to ALLOCATE_TIME to latch max logic?
                    // Or calculate max here.
                    // We need to calculate derivatives based on CURRENT allocations.
                    // Derivatives are combinational based on current_alloc.
                    // We need to find the max subject.
                    // We can do max finding here.
                    
                    // Logic for max is combinational, but we need to register it to hold steady during allocation?
                    // No, we can just use it immediately in ALLOCATE_TIME.
                    // However, ALLOCATE_TIME needs to know WHO to allocate to.
                    // Let's latch the max index here.
                    // But combinational max updates as soon as current_alloc changes.
                    // So in CALC_DERIV, we just transition.
                    // Wait, we need to initialize allocations on first entry to loop.
                    if (iter_count == 0) begin
                        // Initialize everything to 0
                        // We have to manually clear registers for array.
                        current_alloc[0] <= 0;
                        current_alloc[1] <= 0;
                        current_alloc[2] <= 0;
                        current_alloc[3] <= 0;
                        current_alloc[4] <= 0;
                        current_alloc[5] <= 0;
                        current_alloc[6] <= 0;
                        current_alloc[7] <= 0;
                        current_alloc[8] <= 0;
                        current_alloc[9] <= 0;
                        current_alloc_sum <= 0;
                    end
                    
                    state <= ALLOCATE_TIME;
                end

                ALLOCATE_TIME: begin
                    // Add dt to max_idx allocation
                    // max_idx is combinational, so it will be valid here.
                    // Saturating add
                    if (max_idx < num_subjects) begin
                        // Add dt to current_alloc[max_idx]
                        // Check saturation
                        if (current_alloc[max_idx] < 32'hFFFF0000) begin
                            current_alloc[max_idx] <= current_alloc[max_idx] + 32'd655; // 0.01 in Q16.16
                            current_alloc_sum <= current_alloc_sum + 32'd655;
                        end else begin
                            current_alloc[max_idx] <= 32'hFFFFFFFF;
                        end
                    end
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    // iter_count increment
                    if (iter_count < total_time) begin
                        iter_count <= iter_count + 1;
                        state <= CALC_DERIV;
                    end else begin
                        state <= CALC_AVG;
                    end
                end

                CALC_AVG: begin
                    // Average grade = sum(f_i(t_i)) / N
                    // We have sum of derivatives? No, we have sum of allocations (current_alloc_sum).
                    // Wait. f_i(t) = a*t^2 + b*t + c.
                    // We need sum(f_i(t_i)).
                    // We haven't been calculating f_i, only derivatives.
                    // We need to calculate sum of f_i now.
                    // But we don't have t_i stored (except in current_alloc array).
                    // We need to compute f_i for each subject i, sum them, divide by N.
                    // This requires looping through subjects. We can do it in one cycle (combinational) or multi-cycle.
                    // Given the "approx 25000 cycles" limit, we have some budget.
                    // Let's do it in a loop inside this state.
                    // However, Verilog always block logic is sequential per cycle.
                    // We can create a sub-state machine or just use a counter to calculate sum in 10 cycles.
                    // Let's use a small counter 'calc_idx'.
                    // We need to register the accumulator for the sum.
                end
                
                // We need a state for the summation loop
                // Let's just do it in CALC_AVG using a sub-counter
                // But we need to hold CALC_AVG for multiple cycles.
                // Let's rename CALC_AVG to SUMMATION_START.
                // Actually, let's modify the state machine to have a summation phase.
                // To keep it simple, I will split CALC_AVG into SUM_F and DIVIDE.
                // But I need to iterate 10 times to compute 10 multiplications.
                // I'll add a register `sum_acc` to accumulate sum(f_i).
                // I'll add a register `loop_idx` for summation.
                // I'll add a state SUM_LOOP.
            endcase
            
            // Handle summation logic separately since I didn't code it fully in the case
            if (state == CALC_AVG) begin
                // Start summation loop
                // We need to register the sum accumulator to 0 and start loop.
                // But CALC_AVG is a single state in my machine.
                // I will transition to a new state SUM_LOOP or handle it.
                // Let's cheat: use a sub-counter in CHECK_DONE? No.
                // Let's add a state SUM_LOOP.
                // Wait, I need to rewrite the state case to handle this.
            end
        end
    end

    // Revised State Machine Logic with summation loop
    // We need a few more registers for the summation
    reg [31:0] sum_f_acc; // Sum of f_i
    reg [3:0] loop_idx;   // 0 to 9
    reg [31:0] temp_t;    // t for current subject
    reg [31:0] temp_a;    // a for current subject
    reg [31:0] temp_b;    // b for current subject
    reg [31:0] temp_c;    // c for current subject
    
    // Intermediate wires for f_i calculation
    // f = a*t^2 + b*t + c
    wire [63:0] t2_full;
    wire [63:0] at2_full;
    wire [31:0] at2;
    wire [63:0] bt_full;
    wire [31:0] bt;
    wire [31:0] f_partial;
    wire [31:0] f_total;
    
    // Combinational logic for f calculation (for the summation stage)
    // We use the latched values for the current loop_idx
    // t = current_alloc[loop_idx]
    // a = params_a[loop_idx]
    // b = params_b[loop_idx]
    // c = params_c[loop_idx]
    
    // t^2
    assign t2_full = { {32{temp_t[31]}}, temp_t } * { {32{temp_t[31]}}, temp_t };
    // a*t^2 -> Q16.16
    assign at2_full = { {32{temp_a[31]}}, temp_a } * t2_full[63:32]; // Taking upper 32 bits of t^2? 
    // t^2 is Q32.32 (if t is Q16.16). Correct.
    // a is Q16.16. Product is Q48.48? No, 32x32 -> 64.
    // a is Q16.16, t^2 is Q32.32. 
    // We want result Q16.16.
    // We need to shift right 32 bits? (16 for a, 16 for t^2 adjustment).
    // Let's simplify: Multiply a * t * t.
    // Step 1: a * t. Q16.16 * Q16.16 = Q32.32. Keep [47:16] -> Q16.16.
    // Step 2: (a*t) * t. Q16.16 * Q16.16 = Q32.32. Keep [47:16] -> Q16.16.
    
    wire [63:0] at_full;
    wire [31:0] at;
    assign at_full = { {32{temp_a[31]}}, temp_a } * { {32{temp_t[31]}}, temp_t };
    assign at = at_full[47:16];
    
    assign at2_full = { {32{at[31]}}, at } * { {32{temp_t[31]}}, temp_t };
    assign at2 = at2_full[47:16];
    
    // b*t
    assign bt_full = { {32{temp_b[31]}}, temp_b } * { {32{temp_t[31]}}, temp_t };
    assign bt = bt_full[47:16];
    
    // a*t^2 + b*t + c
    wire [31:0] sum1;
    wire [31:0] sum2;
    assign sum1 = at2 + bt; // Add with saturation if needed, but assume safe
    assign sum2 = sum1 + temp_c;
    assign f_total = sum2;

    // Rewriting the always block for the complete flow
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            avg_grade <= 0;
            iter_count <= 0;
            current_alloc_sum <= 0;
            sum_f_acc <= 0;
            loop_idx <= 0;
            // Reset arrays
            current_alloc[0] <= 0; current_alloc[1] <= 0; current_alloc[2] <= 0; current_alloc[3] <= 0;
            current_alloc[4] <= 0; current_alloc[5] <= 0; current_alloc[6] <= 0; current_alloc[7] <= 0;
            current_alloc[8] <= 0; current_alloc[9] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize allocations to 0
                        current_alloc[0] <= 0; current_alloc[1] <= 0; current_alloc[2] <= 0; current_alloc[3] <= 0;
                        current_alloc[4] <= 0; current_alloc[5] <= 0; current_alloc[6] <= 0; current_alloc[7] <= 0;
                        current_alloc[8] <= 0; current_alloc[9] <= 0;
                        iter_count <= 0;
                        current_alloc_sum <= 0; // Not strictly needed for output but good for tracking
                        state <= CALC_DERIV;
                    end
                end

                // CALC_DERIV state: Just logic setup. We don't need to latch derivatives explicitly.
                // We just need to decide where to allocate. The max logic is combinational.
                // To ensure stability, we might latch the max_idx here if logic was slow, but it's small.
                // We just transition to ALLOCATE_TIME.
                // However, we must ensure current_alloc is ready.
                CALC_DERIV: begin
                    // We need to handle the first iteration initialization here if not done in IDLE
                    // But IDLE does it. 
                    // We might need to latch the selected subject index.
                    // Let's latch max_idx in a register 'selected_subj' to avoid combinational glitch during allocation.
                    if (max_idx < num_subjects) begin // Check valid
                         state <= ALLOCATE_TIME;
                    end else begin
                         // Should not happen if num_subjects > 0. 
                         state <= CHECK_DONE;
                    end
                end

                ALLOCATE_TIME: begin
                    // Perform the allocation on the selected subject
                    // We use the combinational max_idx. 
                    // To be safe, let's latch it in CALC_DERIV or just use it here.
                    // It's stable because current_alloc hasn't changed.
                    if (max_idx < num_subjects) begin
                        // Add 0.01 (0x028F) to allocation
                        if (current_alloc[max_idx][31:16] < 16'hFFFF) begin // Simple saturate check on integer part
                            current_alloc[max_idx] <= current_alloc[max_idx] + 32'h0000028F; 
                        end else begin
                            current_alloc[max_idx] <= 32'hFFFFFFFF;
                        end
                    end
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    if (iter_count < total_time) begin
                        iter_count <= iter_count + 1;
                        state <= CALC_DERIV;
                    end else begin
                        // Done with allocation, move to summation
                        sum_f_acc <= 0;
                        loop_idx <= 0;
                        state <= CALC_AVG; // Start of summation loop
                    end
                end

                CALC_AVG: begin
                    // Summation Loop
                    // We need to compute f_i for subject loop_idx
                    // We need to latch the inputs for the combinational block
                    temp_t <= current_alloc[loop_idx];
                    temp_a <= params_a[loop_idx];
                    temp_b <= params_b[loop_idx];
                    temp_c <= params_c[loop_idx];
                    
                    // We transition to a state to accumulate, or just accumulate here if timing permits.
                    // To be safe with pipelining, let's use a sub-state or just accumulate in next cycle.
                    // Actually, the combinational block `f_total` depends on `temp_t` etc.
                    // `temp_t` is updated in this block, so `f_total` will be old value this cycle.
                    // We need a buffer cycle.
                    // Let's introduce a state CALC_F_NEXT.
                    state <= 4; // Placeholder for next state (we need to extend state encoding)
                end
                
                // New state for accumulation (let's say state 4)
                4: begin 
                    // Add f_total to sum_f_acc
                    // f_total is valid now (based on latched temp_* from previous state)
                    // Check if we are still within valid subjects
                    if (loop_idx < num_subjects) begin
                        sum_f_acc <= sum_f_acc + f_total;
                        loop_idx <= loop_idx + 1;
                        state <= CALC_AVG; // Loop back to load next subject
                        
                        if (loop_idx == num_subjects - 1) begin
                            // Last one added. Next step should be division.
                            // But we incremented loop_idx.
                            // If loop_idx becomes num_subjects, we stop.
                            // We need a check after accumulation.
                            // Let's check here.
                            if (loop_idx + 1 == num_subjects) begin
                                state <= 5; // Divide state
                            end
                        end
                    end else begin
                         // Should not reach here if logic correct
                         state <= 5;
                    end
                end

                5: begin // Divide state
                    // avg_grade = sum_f_acc / num_subjects
                    // Integer division in Verilog is truncating.
                    // We have Q16.16 sum. Divide by integer N.
                    // Result is Q16.16.
                    // We need to handle division carefully.
                    // If num_subjects is small, we can just divide.
                    // But sum_f_acc might be huge. 
                    // If N=10, we shift right by 4 approx? No, 2^4=16. Not exact.
                    // We must use division operator.
                    // Division is slow in hardware, but allowed in behavioral verilog for synthesis.
                    if (num_subjects != 0) begin
                        // Saturate if division result is too large? No.
                        // Just compute.
                        // Division of Q16.16 by integer preserves Q16.16 roughly (scales by 1/N).
                        // Example: Sum = 10.0 (655360). N=5. Result = 2.0 (131072).
                        // 655360 / 5 = 131072. Correct.
                        avg_grade <= sum_f_acc / num_subjects;
                    end else begin
                        avg_grade <= 0;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
        end
    end

    // Helper: saturating add for derivative (used in combinational logic, but we didn't saturate there)
    // The combinational logic `deriv_sum` just adds. 
    // It's fine for synthesis, overflow wraps. We select max.
    // If overflow, it might become negative and not be selected.
    // But let's ensure saturation in the ALLOCATE_TIME step.
    
endmodule
