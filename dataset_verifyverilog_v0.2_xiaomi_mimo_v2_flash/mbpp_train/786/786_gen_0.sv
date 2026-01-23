module right_insertion(
    input clk,
    input rst_n,
    input start,
    input [3:0] value,
    input [7:0] sorted_data [7:0],
    output reg [3:0] position,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCHING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] mid;
    
    // Helper wire for comparison to avoid timing issues
    wire cmp_result;
    
    // Determine which N is valid based on the array content (last valid index + 1)
    // We check from the end (8) backwards to find the first non-zero element or just use 8
    // However, the problem says "first N valid elements may be used (N<=8)".
    // To implement this robustly without knowing N explicitly as an input,
    // we assume the full 8 elements are always considered in the binary search range,
    // but the logic handles it correctly.
    // Wait, actually, if N < 8, the array might have garbage at the end.
    // The problem implies we might not want to search the full 8 elements if N is smaller.
    // Since N is not an input, we can look at sorted_data to deduce N or just search 8.
    // Let's look at the last element to see if the array is smaller than 8?
    // No, the problem states: "Input array has 8 elements, but only first N valid elements may be used".
    // This implies we shouldn't blindly look at index 7 if N=4.
    // We need to detect N dynamically.
    
    reg [3:0] valid_n;
    integer i;
    
    // Detect N (number of valid elements) based on sorted_data changes or non-zero?
    // The prompt doesn't give N as input. We must infer it from sorted_data.
    // Assuming sorted_data holds valid data for indices 0 to N-1, and is undefined or 0 afterwards?
    // The test case 5: [10,20,30,40] vs 5 -> pos 0. This implies 4 elements.
    // But since sorted_data is an input array, it provides all 8 values.
    // If N=4, does sorted_data[4] contain garbage or valid data? 
    // Usually, we'd need a valid_n input. Since it's missing, we will assume the full 8 elements 
    // are valid for the purpose of the search logic, OR we detect N.
    // Given the specific instruction "Input array has 8 elements, but only first N valid elements may be used",
    // we must be careful. 
    // Let's detect N by checking if sorted_data[i] changes from sorted_data[i-1] in a way that implies continuity?
    // This is hard without knowing N. 
    // Let's look at Test Case 5: "Array [10,20,30,40]". This implies N=4. 
    // If sorted_data is an input of size 8, indices 0..3 are those values.
    // What about indices 4..7? If they are 0, then binary search might fail (e.g. finding 5 < 0?).
    // We need to define N. 
    // Since N is not an input, I will add a helper logic to find the "effective" number of elements
    // or search only within 0..7.
    // Actually, a simple way: If we treat it as a sorted array of size 8, but we want the right insertion point
    // relative to the *actual* elements. 
    // Let's assume we need to find the maximum index that contains valid data.
    // We'll use a combinational block to find `actual_n`.
    
    reg [3:0] actual_n;
    
    always @(*) begin
        // Heuristic: If the array is sorted, and we have garbage at the end, 
        // maybe we assume 0 is the terminator? Or we just search 0..7.
        // The problem says "first N valid elements". 
        // Without an explicit N, let's assume we must iterate to find N.
        // But for the binary search to work correctly on truncated arrays, we must set `right` to N.
        // Let's search backwards to find the last valid element.
        // Assume 0 is invalid? No, 0 can be valid data.
        // Let's assume `actual_n` is 8 for safety unless we can detect it.
        // However, to pass Test 5, if [10,20,30,40] implies N=4, and indices 4-7 are garbage (e.g., 0),
        // searching 0..7 would find the insertion point for 5.
        // 10 > 5? No. 20 > 5? No. ... 0 > 5? No? wait, 0 is usually smaller.
        // If garbage is 0, and sorted, [10,20,30,40,0,0,0,0] is NOT sorted ascending.
        // So we must assume the array is perfectly sorted or we need N.
        // I will assume that `actual_n` must be determined. 
        // To be safe and meet requirements, I will implement the search over 0 to 7 (the full range).
        // If the problem strictly requires N-logic, we might need to assume a convention.
        // Given the constraints, I will implement the binary search loop 0 to 8.
        // But wait, what if N=0? Then pos=0.
        // Let's implement a search over the full 8 elements as defined by the input size.
        // To satisfy "first N valid elements", I will look at the largest index where sorted_data[index] is 'valid'.
        // Let's define 'valid' as non-zero or just stick to 8.
        // Actually, let's look at the provided example: [1,2,4,5] has 4 elements. 
        // If we treat it as 8, and the rest are garbage, we are in trouble.
        // I will assume the module should search `0` to `actual_n`.
        // I will infer `actual_n` by assuming the array is packed at the start, so 
        // `actual_n` is 8, unless specified otherwise.
        // However, to be robust for the "N" constraint, I will check `sorted_data[7]`.
        // If it is 0, does that mean N<8? Not necessarily.
        // Let's just do the search on 0..7. The prompt implies the array is passed.
        // I will simply use the logic: `right` starts at 8.
    end
    
    // Combinational comparison logic
    assign cmp_result = (value < sorted_data[mid]); // If value < sorted_data[mid], we want left part (else right part)
    // Correction: Logic in prompt:
    // If sorted_data[mid] <= value: left = mid+1
    // Else: right = mid
    // So if sorted_data[mid] > value, we go left (right = mid).
    // My `cmp_result` check `value < sorted_data[mid]` means `sorted_data[mid] > value`. Correct.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            position <= 4'd0;
            left <= 4'd0;
            right <= 4'd8;
            mid <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCHING;
                        left <= 4'd0;
                        right <= 4'd8;
                    end
                end

                SEARCHING: begin
                    if (left < right) begin
                        // mid = (left + right) >> 1
                        mid <= (left + right) >> 1;
                        // The actual update logic needs to happen in next cycle or combinational?
                        // Sequential is easier to meet latency. 
                        // We need to do the comparison and update.
                        // Since it's sequential, let's use the registered mid from previous cycle?
                        // No, we calculate mid in this cycle based on updated left/right.
                        // Wait, if we update mid in the block, we need the result in the next block of code or next cycle.
                        // To keep it simple:
                        // Cycle 1: Update mid. Wait, we need to read sorted_data[mid].
                        // Let's read sorted_data[mid] immediately.
                        // If we update mid in always block, it samples old left/right.
                        // Let's do:
                        // 1. Calculate mid based on current left/right.
                        // 2. Compare.
                        // 3. Update left/right.
                        // This looks like a combinational path.
                        // To meet 10 cycles latency (worst case for 8 elements), we need 3 cycles per iteration?
                        // Binary search on 8 elements takes log2(8)=3 iterations.
                        // If we do 1 iteration per cycle, it takes 3 cycles. 
                        // But the prompt says "Result valid 10 clock cycles after start".
                        // This implies we can be slower. 
                        // Let's implement a robust finite state machine.
                        // State: SEARCHING.
                        // Action: 
                        //   mid = (left + right) / 2;
                        //   if (sorted_data[mid] <= value) left = mid + 1;
                        //   else right = mid;
                        //   if left >= right, go to DONE.
                        // We need to handle the array bound N.
                        // Let's stick to the prompt's instruction: search 0..7 (so right=8).
                        // The "N" constraint might be hinting at dynamic range.
                        // Since we don't have N, I will stick to 0..7. 
                        // If the user expects 0..N, they must ensure unused elements are treated correctly (e.g., infinity).
                        
                        // Implementation details:
                        // We need to check the condition for the CURRENT mid.
                        // We should register mid or use a combinational signal.
                        // Let's calculate mid combinationally to save a cycle.
                        // But let's follow the state machine approach strictly.
                        
                        // Optimization: 
                        // We can do the iteration in a single cycle (combinational logic update), 
                        // but to meet the "10 cycles" requirement (and maybe pipeline it), 
                        // let's do one iteration per cycle.
                        
                        // Step 1: Calculate Mid
                        mid <= (left + right) >> 1;
                        
                        // Step 2: Compare and Update (need to use the mid calculated in previous cycle or combinational logic?)
                        // If we calculate mid in the same cycle, we need to read sorted_data[mid] which is valid.
                        // So we can do the check and update in the same cycle.
                        // However, if `sorted_data` is a register file or BRAM, it might have a 1-cycle latency.
                        // The prompt doesn't specify. It looks like standard logic.
                        // Let's do:
                        //   if (sorted_data[mid] <= value) left <= mid + 1;
                        //   else right <= mid;
                        // But `mid` is just updated. We can use it.
                        
                        if (sorted_data[mid] <= value) begin
                            left <= mid + 1;
                        end else begin
                            right <= mid;
                        end
                        
                        // Check termination condition for THIS cycle (based on new left/right after update)
                        // Wait, if we update left/right, we check if (left < right) for NEXT cycle.
                        // We need to detect when the loop finishes.
                        // If we do one update per cycle:
                        // Start: left=0, right=8. 
                        // Iter 1: mid=4. 
                        // ...
                        // Iter 3: left and right meet.
                        // We need to transition to DONE when left >= right.
                        
                        if ((left + 1 == right) || (left == right)) begin
                             // Actually, the update happens, then we check.
                             // If we are at the last step, we will have left == right or left+1==right.
                        end
                        
                        // Let's use a separate check for state transition.
                        // We need to see if the NEXT state should be DONE.
                        // The new values are latched next cycle. 
                        // So we can't easily check `next_left >= next_right` in the same cycle without combinational logic.
                        // Let's use combinational logic for the update decision.
                        
                        // Revised approach for the SEARCHING state logic:
                        // Calculate next_left, next_right combinationally.
                        // If (next_left >= next_right), go to DONE next cycle.
                        
                    end else begin
                        // left >= right. 
                        state <= DONE;
                        position <= left;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Wait for reset or start again?
                    // Usually stay here until reset or new start.
                    // If start is asserted again, we should restart.
                    // If start is high, go to SEARCHING.
                    if (start) begin
                        state <= SEARCHING;
                        done <= 1'b0;
                        left <= 4'd0;
                        right <= 4'd8;
                    end
                end
            endcase
        end
    end
    
    // Combinational helper for the SEARCHING state logic
    // This handles the "update and check" in one cycle if we structure the FSM correctly.
    // But wait, the FSM above updates mid, left, right on the clock edge.
    // The condition check for state transition is tricky.
    // Let's refine the `SEARCHING` block logic to be purely sequential and safe.
    
    // Correct Sequential Logic:
    // 1. In IDLE, wait for start.
    // 2. In SEARCHING:
    //    - If (left < right):
    //       mid = (left + right) / 2.
    //       If (sorted_data[mid] <= value) left = mid + 1;
    //       else right = mid.
    //    - Else (left >= right):
    //       go to DONE.
    // 3. In DONE, output position.
    
    // To handle the "10 cycles" requirement, we just need to be slower than 3 cycles?
    // No, 10 cycles is the "result valid" time. It doesn't say we MUST wait 10.
    // It says "Result valid 10 clock cycles after start asserted (worst case)".
    // This implies our design should complete within 10 cycles. 
    // Since 8 elements needs 3 iterations, we are well within budget.
    // The 10 cycles might be a hint to use a slower state machine, or just a guarantee for the testbench.
    // I will implement the efficient 1-iteration per cycle version.
    
    // One issue: `sorted_data` is an input array. In Verilog, accessing `sorted_data[mid]` where `mid` is variable 
    // usually requires `mid` to be a constant or the array must be synthesized into logic (not BRAM).
    // If we synthesize this, it becomes a large multiplexer tree. This is fine for small N=8.
    
    // Let's rewrite the `SEARCHING` block to be clearer.
    // Actually, the previous code works but let's make sure the `left < right` check is correct.
    // We need to check `left < right` *before* calculating mid.
    // If we update `left` and `right` in the block, they update at the end of the cycle.
    // So `left < right` check at the beginning of the block uses the values from the *previous* cycle (or IDLE).
    
    // Refined Block:
    // In IDLE: left=0, right=8.
    // Transition to SEARCHING.
    // Cycle 1 (SEARCHING): 
    //   Check if left < right (0 < 8). Yes.
    //   Calculate mid = 4.
    //   Compare sorted_data[4] <= value.
    //   Update left or right.
    //   (Cycle 2 will use new left/right)
    // 
    //   Wait, do we check termination condition immediately?
    //   If we update left/right such that left >= right, we should transition to DONE *next* cycle.
    //   But if we do that, we go through the loop one last time.
    //   Correct way: 
    //   If (left < right) -> compute mid, update, stay in SEARCHING.
    //   If (left >= right) -> go to DONE.
    
    //   But if we are in SEARCHING, and left < right is false, we go to DONE.
    //   So the check must happen at the start of the cycle.
    
    //   What about the very first cycle of SEARCHING? 
    //   We come from IDLE where left=0, right=8. 
    //   Check 0<8 -> True. Compute mid=4. Update left/right. Stay in SEARCHING.
    //   Next cycle: Check new left < new right. 
    //   This works.
    
    //   Edge case: what if we just updated left/right and now left >= right?
    //   We stay in SEARCHING for one extra cycle, then go to DONE.
    //   This adds 1 cycle latency. Total ~4 cycles. Still < 10.
    
    //   Optimization: Go to DONE immediately if the update results in left >= right.
    //   To do this, we need to compute the NEXT values combinationally to decide the next state.
    //   Let's do that to be precise and efficient.
    
    //   Combinational next state logic:
    //   next_left = (sorted_data[mid] <= value) ? mid + 1 : left;
    //   next_right = (sorted_data[mid] <= value) ? right : mid;
    //   Wait, `mid` needs to be calculated from current left/right.
    //   So: 
    //   next_mid = (left + right) >> 1;
    //   next_left = (sorted_data[next_mid] <= value) ? next_mid + 1 : left;
    //   next_right = (sorted_data[next_mid] <= value) ? right : next_mid;
    //   next_state = (next_left < next_right) ? SEARCHING : DONE;
    
    //   This allows single-cycle iterations.

    // Let's implement the fully synchronous logic with combinational helpers for clarity and speed.

    // Combinational block for next state decision
    reg [3:0] next_left;
    reg [3:0] next_right;
    reg [1:0] next_state;
    reg [3:0] calc_mid;
    
    always @(*) begin
        if (state == SEARCHING) begin
            calc_mid = (left + right) >> 1;
            
            if (sorted_data[calc_mid] <= value) begin
                next_left = calc_mid + 1;
                next_right = right;
            end else begin
                next_left = left;
                next_right = calc_mid;
            end
            
            if (next_left < next_right) begin
                next_state = SEARCHING;
            end else begin
                next_state = DONE;
            end
        end else if (state == IDLE && start) begin
            // On start, initialize and go to searching
            next_state = SEARCHING;
            next_left = 4'd0;
            next_right = 4'd8;
        end else if (state == DONE && start) begin
            // Restart if done and start is pressed again
            next_state = SEARCHING;
            next_left = 4'd0;
            next_right = 4'd8;
        end else begin
            // Stay in current state
            next_state = state;
            next_left = left;
            next_right = right;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            left <= 4'd0;
            right <= 4'd8;
            position <= 4'd0;
            done <= 1'b0;
        end else begin
            // Update state
            state <= next_state;
            left <= next_left;
            right <= next_right;
            
            // Update outputs
            if (next_state == DONE) begin
                position <= next_left; // Position is left
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
endmodule