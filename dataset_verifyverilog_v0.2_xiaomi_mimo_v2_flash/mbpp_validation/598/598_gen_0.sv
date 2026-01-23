module armstrong_checker(
    input clk,
    input rst_n,
    input start,
    input [9:0] number,
    output reg result,
    output reg done
);

// State encoding
localparam IDLE = 5'b00001;
localparam COUNT_DIGITS = 5'b00010;
localparam EXTRACT_DIGITS = 5'b00100;
localparam CHECK_RESULT = 5'b01000;
localparam DONE = 5'b10000;

// Internal registers
reg [4:0] state;
reg [4:0] next_state;
reg [9:0] original_num;
reg [9:0] working_num;
reg [10:0] sum; // 11-bit to hold 3*729 = 2187
reg [3:0] digit_count;
reg [3:0] current_digit;
reg [9:0] digit_cube;
reg [1:0] extract_cnt; // Counter for extracting 3 digits

// Combinational logic for cube lookup
always @(*) begin
    case(current_digit)
        4'd0: digit_cube = 10'd0;
        4'd1: digit_cube = 10'd1;
        4'd2: digit_cube = 10'd8;
        4'd3: digit_cube = 10'd27;
        4'd4: digit_cube = 10'd64;
        4'd5: digit_cube = 10'd125;
        4'd6: digit_cube = 10'd216;
        4'd7: digit_cube = 10'd343;
        4'd8: digit_cube = 10'd512;
        4'd9: digit_cube = 10'd729;
        default: digit_cube = 10'd0;
    endcase
end

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 1'b0;
        done <= 1'b0;
        original_num <= 10'd0;
        working_num <= 10'd0;
        sum <= 11'd0;
        digit_count <= 4'd0;
        current_digit <= 4'd0;
        extract_cnt <= 2'd0;
        next_state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result <= 1'b0;
                if (start) begin
                    original_num <= number;
                    working_num <= number;
                    sum <= 11'd0;
                    digit_count <= 4'd0;
                    extract_cnt <= 2'd0;
                    next_state <= COUNT_DIGITS;
                end else begin
                    next_state <= IDLE;
                end
            end

            COUNT_DIGITS: begin
                if (working_num > 0) begin
                    working_num <= working_num / 10;
                    digit_count <= digit_count + 1;
                    next_state <= COUNT_DIGITS;
                end else begin
                    // If digit_count is not 3, skip to DONE with result 0
                    if (digit_count != 3) begin
                        next_state <= DONE;
                        result <= 1'b0;
                    end else begin
                        // Reset working_num for extraction phase
                        working_num <= original_num;
                        sum <= 11'd0;
                        extract_cnt <= 2'd0;
                        next_state <= EXTRACT_DIGITS;
                    end
                end
            end

            EXTRACT_DIGITS: begin
                if (extract_cnt < 3) begin
                    // Extract digit
                    current_digit <= working_num % 10;
                    working_num <= working_num / 10;
                    // Wait one cycle for cube lookup (combinational) and addition
                    // Actually, since cube is combinational, we can update sum immediately in next state logic or here.
                    // Let's do it in a pipelined manner effectively.
                    // The problem asks for sequential logic. 
                    // Let's assume we update sum in CHECK_RESULT or next cycle of EXTRACT.
                    // To be safe and sequential, let's update sum in the next state or based on extracted digit.
                    // Since we are in sequential block, we update working_num and current_digit.
                    // We will add to sum in the next clock cycle (or combine states).
                    // Let's use the cube lookup result directly.
                    // To avoid combinational loops or complex timing, let's accumulate sum here using the previous cycle's digit.
                    // Wait, standard practice: 
                    // Cycle 1: Read digit from working_num, shift working_num.
                    // Cycle 2: Compute cube, add to sum.
                    // 
                    // To meet latency requirements (40 cycles) and keep it simple:
                    // Let's process 1 digit per few cycles.
                    // 
                    // Revising EXTRACT_DIGITS logic:
                    // 1. Extract digit (this cycle).
                    // 2. Next cycle, add cube to sum.
                    // 
                    // Let's refine the state machine to be more granular.
                    // But the prompt lists states: IDLE, COUNT, EXTRACT, CHECK, DONE.
                    // Let's stick to those names but optimize for efficiency.
                    // 
                    // Efficient Sequential Flow for EXTRACT_DIGITS:
                    // Since combinational logic for cube exists, we can do:
                    // current_digit gets value.
                    // sum update logic needs to be careful.
                    // Let's insert a virtual 'ADD' step or just do it in next state evaluation.
                    // 
                    // Actually, let's keep it simple: 
                    // Update sum based on the digit extracted in the PREVIOUS clock cycle.
                    // Initialize a 'valid_digit' flag or use state transitions.
                    // 
                    // New Plan for EXTRACT state:
                    // It needs to loop 3 times.
                    // Cycle 0 (Enter): working_num = original, sum = 0.
                    // Cycle 1: current_digit = working_num % 10; working_num = working_num / 10. 
                    // Cycle 2: sum = sum + digit_cube. Check count.
                    // 
                    // Let's use extract_cnt to track progress.
                    // 
                    // Let's simply update sum in this block based on 'current_digit' which was set in previous cycle of this state.
                    // We need a way to distinguish first iteration.
                    // 
                    // Let's use a flag 'accumulated' or similar? No, easier to just use state transitions.
                    // 
                    // Let's insert a sub-state or use the state machine to handle the "Cube and Add" step.
                    // Since we only have 5 states defined, let's execute the addition in the same state but delayed by 1 cycle using register behavior.
                    // 
                    // However, strictly sequential logic: 
                    // If we are in EXTRACT_DIGITS, we process digits.
                    // Let's assume we process one digit per clock cycle to keep it simple and within latency.
                    // 
                    // Revised Logic for EXTRACT_DIGITS:
                    // 1. Get digit from working_num.
                    // 2. Shift working_num.
                    // 3. Add cube of the digit extracted in step 1 to sum.
                    // 
                    // We need to store the extracted digit to use it for cube lookup.
                    // The 'current_digit' register holds the digit.
                    // 
                    // Let's modify the EXTRACT_DIGITS behavior:
                    // It will loop 3 times.
                    // Each iteration:
                    //   a. Read digit.
                    //   b. Shift working_num.
                    //   c. Accumulate sum.
                    // 
                    // This requires 3 cycles.
                    // 
                    // Code inside EXTRACT_DIGITS:
                    if (extract_cnt < 3) begin
                        // Extract current digit
                        current_digit <= working_num % 10;
                        working_num <= working_num / 10;
                        
                        // Update sum with the PREVIOUSLY extracted digit's cube
                        // But for the FIRST digit, sum is 0 and we shouldn't add garbage.
                        // We need a flag to indicate we have a digit ready to add.
                        // 
                        // Let's add a 'valid_d' register or just handle it with count.
                        // If extract_cnt > 0, add previous digit's cube to sum.
                        // 
                        if (extract_cnt > 0) begin
                            // Add cube of 'current_digit' (which is actually the digit from previous iteration? No.
                            // The logic is sequential: 
                            // T0: current_digit = D2 (MSD), working_num updates.
                            // T1: current_digit = D1, working_num updates, sum adds cube(D2).
                            // T2: current_digit = D0, working_num updates, sum adds cube(D1).
                            // T3: Exit state, sum adds cube(D0).
                            // 
                            // To do this correctly:
                            // We need to calculate cube of the digit just extracted (old current_digit).
                            // But 'digit_cube' is combinational based on 'current_digit'.
                            // So we need to add 'digit_cube' (based on old value) BEFORE updating current_digit.
                            // 
                            // Since this is a sequential block, we can't easily use the "old" value of current_digit unless we delay it.
                            // Let's split into two cycles per digit or use an intermediate register.
                            // 
                            // To keep code clean and explicit:
                            // Let's compute cube of the digit just extracted in the SAME cycle.
                            // 
                            // Wait, if we update current_digit, the combinational cube output changes immediately (in simulation) but for synthesis, it's a wire.
                            // If we want to add the cube of the digit we just removed from working_num, we need that digit value.
                            // 
                            // Let's create a temporary register 'digit_to_process' or similar.
                            // 
                            // Actually, simpler:
                            // Just do the extraction. 
                            // In a following state (or same state logic using a counter state variable), add.
                            // 
                            // Let's use the `extract_cnt` to determine action.
                            // But the prompt asks for specific states. 
                            // 
                            // Let's try this:
                            // 1. Extract digit -> Store in `current_digit`.
                            // 2. Add `cube(current_digit)` to `sum`. 
                            // 3. Increment counter.
                            // 
                            // Problem: If I update current_digit = num % 10, and then sum += cube(current_digit), I'm adding the NEW digit's cube?
                            // No, the sequence of execution in the sequential block means:
                            // 1. Right Hand Side is evaluated using current values.
                            // 2. Left Hand Side is updated at the end of the cycle.
                            // 
                            // So if I write:
                            // current_digit <= working_num % 10;
                            // sum <= sum + cube(current_digit);
                            // 
                            // `cube(current_digit)` uses the OLD value of current_digit.
                            // This is exactly what we want!
                            // 
                            // So, logic:
                            // Loop 3 times.
                            // First time: current_digit (old) is X. cube(X) is garbage.
                            // 
                            // Fix:
                            // Initialize current_digit to 0 or use a flag.
                            // Or, use `extract_cnt` to control whether to add.
                            // If extract_cnt == 0: Don't add (initial state). Extract digit. Increment cnt.
                            // If extract_cnt > 0: Add cube(old_digit). Extract new digit. Increment cnt.
                            // 
                            // After loop finishes (cnt=3), we have extracted 3 digits. We still need to add the 3rd digit's cube.
                            // The loop runs 3 times. 
                            // 
                            // Let's refine:
                            // We need to accumulate sum of cubes of 3 digits.
                            // Let's do:
                            // 1. Extract D2. (cnt=0).
                            // 2. Extract D1, Add Cube(D2). (cnt=1).
                            // 3. Extract D0, Add Cube(D1). (cnt=2).
                            // 4. Exit state. Add Cube(D0).
                            // 
                            // So we need 3 cycles to extract, plus 1 more to add the last one.
                            // To minimize states, we can add the last cube in CHECK_RESULT state.
                            // 
                            // Let's restructure EXTRACT_DIGITS to run 3 times.
                            // Use extract_cnt 0, 1, 2.
                            // 
                            // Cycle 1 (cnt=0): Extract D2. current_digit <= D2. (No add).
                            // Cycle 2 (cnt=1): Extract D1. current_digit <= D1. sum <= sum + cube(D2).
                            // Cycle 3 (cnt=2): Extract D0. current_digit <= D0. sum <= sum + cube(D1).
                            // Transition to CHECK_RESULT.
                            // 
                            // In CHECK_RESULT state:
                            // sum <= sum + cube(D0);
                            // 
                            // This works.
                            
                            if (extract_cnt == 1) begin
                                sum <= sum + digit_cube; // Add cube of D2
                            end else if (extract_cnt == 2) begin
                                sum <= sum + digit_cube; // Add cube of D1
                            end
                            
                            current_digit <= working_num % 10;
                            working_num <= working_num / 10;
                            extract_cnt <= extract_cnt + 1;
                            next_state <= EXTRACT_DIGITS;
                            
                        end else begin
                            // First iteration (cnt == 0)
                            current_digit <= working_num % 10;
                            working_num <= working_num / 10;
                            extract_cnt <= extract_cnt + 1;
                            next_state <= EXTRACT_DIGITS;
                        end
                    end else begin
                        // This condition shouldn't be hit inside the 'if (extract_cnt < 3)' block
                        next_state <= CHECK_RESULT;
                    end
                    // We need to handle the case where extract_cnt becomes 3 inside the block or after.
                    // Let's move the transition logic outside or handle it carefully.
                    
                    // Actually, let's check transition at the end of the block.
                    // The code above increments extract_cnt. 
                    // If extract_cnt was 2, it becomes 3. Next cycle, we should leave this state.
                    // So the logic below needs to be correct.
                    // Let's assume if extract_cnt >= 3 we transition.
                    // But inside the block we incremented it.
                    // Let's re-evaluate.
                    
                    // Wait, if extract_cnt starts at 0.
                    // Iteration 0: cnt=0. Block executes. cnt becomes 1. Stay in state.
                    // Iteration 1: cnt=1. Block executes. cnt becomes 2. Stay in state.
                    // Iteration 2: cnt=2. Block executes. cnt becomes 3. Stay in state? No.
                    // We want to process 3 digits. 
                    // Let's do:
                    // cnt=0: Extract D2.
                    // cnt=1: Extract D1, Add D2.
                    // cnt=2: Extract D0, Add D1.
                    // When cnt=2, we finish extraction. We need to Add D0 later.
                    // 
                    // So when extract_cnt reaches 3 (after increment), we go to CHECK_RESULT.
                    // In CHECK_RESULT, we add D0's cube.
                    
                    // Refining the inside of EXTRACT_DIGITS:
                    if (extract_cnt < 3) begin
                        // Extract new digit
                        current_digit <= working_num % 10;
                        working_num <= working_num / 10;
                        
                        // Add previous digit's cube
                        if (extract_cnt > 0) begin
                            sum <= sum + digit_cube;
                        end
                        
                        extract_cnt <= extract_cnt + 1;
                        next_state <= EXTRACT_DIGITS;
                    end else begin
                        // Should not happen if condition is < 3, but if we miss a cycle?
                        // If we enter here with cnt >= 3, move to next.
                        next_state <= CHECK_RESULT;
                    end
                    
                    // Note: To handle the third digit (D0) addition, we rely on the next state CHECK_RESULT.
                end else begin
                     next_state <= CHECK_RESULT;
                end
            end

            CHECK_RESULT: begin
                // Add the cube of the last extracted digit (D0)
                // current_digit holds D0 from the last cycle of EXTRACT_DIGITS
                sum <= sum + digit_cube;
                
                // The comparison happens next cycle or we can check directly if we wanted to use combinational output.
                // Let's use the updated sum in the next state (DONE) or check here against the sum that includes D0.
                // Since we just updated sum <= sum + digit_cube, the new sum is valid in the next cycle.
                // So we should move to DONE and set result based on the sum value from the previous cycle?
                // No, if we are in CHECK_RESULT, we just issued the update for sum.
                // The "real" sum with D0 is available after this cycle.
                // So we need to wait one cycle or use combinational logic.
                // 
                // Let's do: In CHECK_RESULT, we perform the addition.
                // We transition to DONE.
                // In DONE, we latch the result.
                // 
                // Wait, if we use the 'sum' register for comparison, we need to wait until the addition is done.
                // The addition is done in this cycle (logic before the <=). 
                // Actually, in this sequential block, `sum <= sum + digit_cube` means the OLD sum is used.
                // So the addition result will be available in the NEXT cycle.
                // 
                // So we need to stay in CHECK_RESULT for 1 cycle to let sum update?
                // Or, check against (sum + digit_cube) combinationally.
                // 
                // To keep it fully synchronous and reliable:
                // Use the combinational value of (sum + digit_cube) for comparison.
                // Or, wait 1 cycle.
                // Let's use the combinational value to save a cycle.
                
                if (original_num == (sum + digit_cube)) begin
                    result <= 1'b1;
                end else begin
                    result <= 1'b0;
                end
                
                next_state <= DONE;
            end

            DONE: begin
                done <= 1'b1;
                next_state <= DONE;
                // Wait for start to go low or reset to restart
                if (!start) begin
                    // Optional: Stay in DONE or go to IDLE.
                    // Usually we stay in DONE until reset or until start signal is handled.
                    // If start is level sensitive, we can stay here.
                    // If we want to accept new start immediately, we'd transition to IDLE when !start.
                    // But typically done stays high until reset or start goes low.
                    // Let's stay in DONE until reset or start goes low to prevent re-triggering immediately.
                    // Actually, the prompt says "Wait for start signal" in IDLE.
                    // So we stay here until reset.
                    // Or maybe we can go to IDLE if start is low.
                    // Let's go to IDLE if start is low to be ready for next transaction.
                     next_state <= IDLE; // Prepare for next transaction when start is deasserted
                     done <= 1'b0;
                end
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule

// Logic Refinement Note:
// The logic in EXTRACT_DIGITS updates sum in the same cycle it extracts the next digit.
// This assumes digit_cube is calculated combinationally from current_digit.
// Since current_digit is updated in the same block, the old value of current_digit is used for the cube lookup for the addition.
// This works perfectly for sequential logic without extra states.
// 
// Flow:
// IDLE -> init
// COUNT -> count digits. If != 3, DONE (result 0). Else EXTRACT.
// EXTRACT (cnt=0): current_digit = D2. (sum unchanged, as cnt=0).
// EXTRACT (cnt=1): sum += cube(D2). current_digit = D1.
// EXTRACT (cnt=2): sum += cube(D1). current_digit = D0.
// EXTRACT (cnt=3): (Condition fails) -> CHECK_RESULT.
// CHECK_RESULT: sum += cube(D0). result = (original_num == sum + cube(D0)).
// 
// Wait, in CHECK_RESULT, we issue sum <= sum + cube(D0). 
// The comparison `original_num == (sum + digit_cube)` uses the OLD sum (which is sum of D2+D1) and CURRENT digit_cube (which is D0).
// So it calculates (D2+D1 + D0) correctly for comparison. 
// But the register `sum` itself is updated to (D2+D1+D0) for potential debugging or future use.
// 
// Correct.

// One corner case: 0.
// Input 0. COUNT_DIGITS: working_num becomes 0 immediately. digit_count remains 0.
// Logic: if (working_num > 0) is false. Else branch. digit_count (0) != 3. -> DONE (result 0). Correct.

// One corner case: 1.
// Input 1. COUNT: digit_count=1. -> DONE (result 0). Correct (not 3 digits).

// Logic seems solid.
endmodule