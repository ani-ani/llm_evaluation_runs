module monotonic_check(
    input clk,
    input rst_n,
    input start,
    input [2:0] length,
    input [7:0] data [0:7],
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECKING = 2'b01;
    localparam DONE = 2'b10;
    localparam DONE_LATENT = 2'b11; // Additional state to hold done for latency

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index; // Counter for iteration (0 to length-2)
    reg [3:0] next_index;
    reg result_reg, next_result;
    reg [1:0] dir, next_dir; // 0=unknown, 1=inc, 2=dec (binary representation)
    reg [3:0] cycle_count, next_cycle_count; // To track 10 cycles

    // State transition logic
    always @(*) begin
        next_state = state;
        next_index = index;
        next_result = result_reg;
        next_dir = dir;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                if (start) begin
                    next_cycle_count = 4'd0;
                    next_index = 4'd0;
                    // Initialize result and dir
                    // Default: trivial monotonic (0 or 1 element)
                    next_result = 1'b1;
                    next_dir = 2'b00; // Unknown

                    // Check length for edge cases immediately
                    if (length <= 3'd1) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECKING;
                    end
                end
            end

            CHECKING: begin
                // Perform check for current index
                if (index < length - 1) begin
                    // Comparison logic
                    if (data[index] < data[index + 1]) begin
                        // Increasing
                        if (dir == 2'b00) begin
                            next_dir = 2'b01; // Set to increasing
                        end else if (dir == 2'b10) begin
                            // Violation: was decreasing, now increasing
                            next_result = 1'b0;
                            next_dir = 2'b00; // Keep checking but result is false
                        end
                    end else if (data[index] > data[index + 1]) begin
                        // Decreasing
                        if (dir == 2'b00) begin
                            next_dir = 2'b10; // Set to decreasing
                        end else if (dir == 2'b01) begin
                            // Violation: was increasing, now decreasing
                            next_result = 1'b0;
                            next_dir = 2'b00;
                        end
                    end
                    // If equal, do nothing to direction, result stays as is

                    next_index = index + 1;
                    next_state = CHECKING; // Stay in checking
                end else begin
                    // Finished iterating through array
                    next_state = DONE;
                end
            end

            DONE: begin
                // Latency requirement: Result valid 10 cycles after start
                // Start was asserted at cycle 0 (transition from IDLE to CHECKING)
                // Here we are in DONE state. We need to stay here until cycle 10.
                // However, since IDLE takes 1 cycle, CHECKING takes N cycles (N<=8),
                // Total so far is usually < 10. We need to wait out the rest.
                // To be precise: "Result valid 10 clock cycles after start asserted".
                // Start asserted at T=0. Result valid at T=10.
                // If we arrive here at T < 10, we must wait.
                // Let's implement a simple counter.
                
                if (cycle_count < 4'd10) begin
                    next_cycle_count = cycle_count + 1;
                    next_state = DONE_LATENT; // Use separate state to latch result
                end else begin
                    // 10 cycles met, stay in DONE (or we can create a hold state)
                    // But requirements say "Return to IDLE when done".
                    // Wait for start to go low?
                    // Usually done stays high until next start.
                    // We'll wait here until start is low, then go to IDLE.
                    if (!start) begin
                        next_state = IDLE;
                    end else begin
                        next_state = DONE;
                    end
                    // We need to hold 'done' high here. 
                end
            end

            DONE_LATENT: begin
                // This state is entered if we finished checking early.
                // We increment cycle count until 10.
                if (cycle_count < 4'd10) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    // Time to assert done
                    next_state = DONE;
                end
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            result_reg <= 1'b0;
            dir <= 2'b00;
            cycle_count <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            result_reg <= next_result;
            dir <= next_dir;
            cycle_count <= next_cycle_count;

            // Output assignments
            // Result is updated only when valid (at the end of latency)
            // Since we transition to DONE_LATENT -> DONE, we latch result when entering DONE logic
            // Actually, simpler: Result holds value from 'result_reg' which is updated during check.
            // We output 'result_reg' but only 'done' is high when ready.
            
            if (state == DONE || state == DONE_LATENT) begin
                // In DONE or DONE_LATENT, result is computed.
                // But we only want result valid at cycle 10.
                // If we are in DONE (after cycle 10), output result.
                if (cycle_count >= 4'd10 || state == DONE) begin
                     // To prevent outputting garbage before latency:
                     // We can use a 'valid' flag.
                     // Let's set output result only when cycle_count reaches 10.
                     // But 'cycle_count' is only incremented in DONE state.
                     // If CHECKING takes long (e.g. 8 cycles), we might hit 10 in CHECKING? 
                     // No, max length is 8. Max pairs is 7. IDLE=1. Total 8. 
                     // So CHECKING finishes before 10. We wait in DONE_LATENT.
                end
            end

            // Refined Output Logic
            // Update 'done' and 'result' only when we hit the DONE state after latency
            if (state == DONE_LATENT && cycle_count == 4'd10) begin
                 // Transition to DONE happens next cycle, but latency met now
                 // We need to output result at cycle 10.
                 // So we assign result = result_reg here or in next state?
                 // Let's assign it directly from result_reg whenever done is high.
            end

            // Assign outputs based on state
            if (state == DONE_LATENT && cycle_count == 4'd10) begin
                result <= result_reg;
                done <= 1'b1;
            end else if (state == DONE) begin
                done <= 1'b1;
                // Result is already latched from previous cycle
                if (!start) begin
                    done <= 1'b0;
                    result <= 1'b0; // Optional: clear result
                end
            end else begin
                done <= 1'b0;
                result <= 1'b0;
            end
        end
    end

    // Fix for sequential logic: Output assignment logic needs to be simpler.
    // The previous always block had some complex ifs. 
    // Let's clean up the sequential block.
    
endmodule

module monotonic_check_fixed(
    input clk,
    input rst_n,
    input start,
    input [2:0] length,
    input [7:0] data [0:7],
    output reg result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam CHECKING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] idx;
    reg [1:0] dir; // 0=unknown, 1=inc, 2=dec
    reg res_reg;
    reg [3:0] timer;

    // Wire for next state values
    wire [1:0] next_state_w;
    wire [3:0] next_idx_w;
    wire [1:0] next_dir_w;
    wire next_res_reg_w;
    wire [3:0] next_timer_w;
    wire next_done_w;
    wire next_result_w;

    // Combinational Logic for State Machine
    assign next_state_w = (state == IDLE && start) ? CHECKING : 
                          (state == CHECKING && idx >= length - 1) ? DONE :
                          (state == DONE && timer == 4'd10 && !start) ? IDLE :
                          (state == DONE && timer < 4'd10) ? DONE : 
                          state;

    assign next_idx_w = (state == IDLE && start) ? 4'd0 : 
                        (state == CHECKING) ? idx + 1 : idx;

    // Direction Logic
    // 0=unknown, 1=increasing, 2=decreasing
    wire [7:0] curr = data[idx];
    wire [7:0] next_val = data[idx+1];
    wire is_inc = (curr < next_val);
    wire is_dec = (curr > next_val);
    
    reg [1:0] dir_temp;
    always @(*) begin
        dir_temp = dir;
        if (state == IDLE && start) dir_temp = 2'b00;
        else if (state == CHECKING) begin
            if (is_inc) begin
                if (dir == 2'b00) dir_temp = 2'b01; // Set inc
                else if (dir == 2'b10) dir_temp = 2'b10; // Violation stays dec to force fail or keep check? 
            end else if (is_dec) begin
                if (dir == 2'b00) dir_temp = 2'b10; // Set dec
                else if (dir == 2'b01) dir_temp = 2'b01; // Violation stays inc
            end
            // If equal, dir_temp remains same
        end
    end
    assign next_dir_w = dir_temp;

    // Result Logic
    reg res_temp;
    always @(*) begin
        res_temp = res_reg;
        if (state == IDLE && start) res_temp = 1'b1; // Assume true unless proven false
        else if (state == CHECKING) begin
            if (is_inc) begin
                if (dir == 2'b10) res_temp = 1'b0; // Violation
            end else if (is_dec) begin
                if (dir == 2'b01) res_temp = 1'b0; // Violation
            end
        end
    end
    assign next_res_reg_w = res_temp;

    // Timer Logic for Latency
    assign next_timer_w = (state == IDLE && start) ? 4'd0 : 
                          (state == DONE) ? timer + 1 : timer;

    // Output Logic
    assign next_done_w = (state == DONE && timer >= 4'd10);
    // Result should be valid when done is high. 
    // If we are in DONE state and timer >= 10, we output the computed result_reg.
    // If we just entered DONE, timer is 0, but we might need to wait.
    // Wait, the spec says "Result valid 10 clock cycles after start asserted".
    // If length is 8, checking takes IDLE(1) + 7(CHECKING) = 8 cycles. 
    // We enter DONE at cycle 8. We need to wait 2 more cycles.
    // So if state == DONE and timer < 10, result is NOT valid yet.
    // But we should probably drive done low and result low/unknown until then.
    
    assign next_result_w = (state == DONE && timer >= 4'd10) ? res_reg : 1'b0;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            dir <= 2'b00;
            res_reg <= 1'b0;
            timer <= 4'd0;
            done <= 1'b0;
            result <= 1'b0;
        end else begin
            state <= next_state_w;
            idx <= next_idx_w;
            dir <= next_dir_w;
            res_reg <= next_res_reg_w;
            timer <= next_timer_w;
            done <= next_done_w;
            result <= next_result_w;
        end
    end

endmodule

module monotonic_check_final(
    input clk,
    input rst_n,
    input start,
    input [2:0] length,
    input [7:0] data [0:7],
    output reg result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam DONE_STATE = 2'b10;
    localparam WAIT_LATENCY = 2'b11; // Added to manage the 10 cycle requirement easily

    reg [1:0] state;
    reg [3:0] count; // used for index in CHECK, timer in WAIT_LATENCY
    reg [1:0] dir;   // 0=unknown, 1=inc, 2=dec
    reg res_reg;     // internal result accumulator

    // Combinational helper signals
    wire [7:0] val1 = data[count];
    wire [7:0] val2 = data[count + 1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            dir <= 2'b00;
            res_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        count <= 4'd0;
                        dir <= 2'b00;
                        res_reg <= 1'b1; // Default true for 0 or 1 element
                        if (length <= 3'd1) begin
                            // Edge case: 0 or 1 element. Fast path to done.
                            // We need to meet latency 10. Start is cycle 0. 
                            // We will go to WAIT_LATENCY to ensure 10 cycles.
                            state <= WAIT_LATENCY;
                            count <= 4'd0; // Timer starts at 0
                        end else begin
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // We need to check pairs from 0 to length-2
                    if (count < length - 1) begin
                        // Compare val1 and val2
                        if (val1 < val2) begin
                            // Increasing
                            if (dir == 2'b00) dir <= 2'b01; // Set dir
                            else if (dir == 2'b10) res_reg <= 1'b0; // Violation
                        end else if (val1 > val2) begin
                            // Decreasing
                            if (dir == 2'b00) dir <= 2'b10; // Set dir
                            else if (dir == 2'b01) res_reg <= 1'b0; // Violation
                        end
                        // If equal, do nothing
                        count <= count + 1;
                        state <= CHECK;
                    end else begin
                        // Finished checking all pairs
                        // Transition to waiting for latency
                        state <= WAIT_LATENCY;
                        count <= 4'd0; // Reset count to use as timer
                    end
                end

                WAIT_LATENCY: begin
                    // We are here because checking is done (or fast path from IDLE)
                    // We need to wait such that start -> result is 10 cycles.
                    // Let's count cycles here.
                    // If we came from IDLE (length<=1), we are at cycle 1 (IDLE took 1).
                    // If we came from CHECK (length=8), we are at cycle 1 (IDLE) + 7 (CHECK) = 8.
                    // We need to reach cycle 10.
                    // So we count up to 10.
                    // Actually, let's just count up to 10. If we arrive at T=8, we need 2 more.
                    // If we arrive at T=1, we need 9 more.
                    // A simple way: count until 9 (0 to 9 is 10 cycles).
                    
                    if (count < 4'd9) begin // 0,1,2,3,4,5,6,7,8 (9 cycles) -> next cycle is 10th?
                         // Start asserted at T=0. 
                         // If we enter here at T=8, we set count=0. T=9 count=1. ...
                         // We want done at T=10.
                         // Let's try: count until 2 for the fast path (1->2->3...10)
                         
                         // Actually, let's rely on a specific counter value.
                         // We need total 10 cycles from start.
                         // We don't know exactly when we entered WAIT_LATENCY.
                         // Let's just use a counter that starts at 0 on start, and done goes high when it hits 10.
                         // But we are in a state machine. 
                         // Let's keep it simple: Stay in WAIT_LATENCY for 2 cycles (if coming from long check) 
                         // or 9 cycles (if coming from short).
                         // Since max check is 8 cycles total (1 idle + 7 check), we have 2 cycles buffer.
                         // Min check is 1 cycle total (1 idle + 0 check), we have 9 cycles buffer.
                         // We can just wait 9 cycles in WAIT_LATENCY to be safe? No, that adds 9 to max.
                         // Max would be 8 + 9 = 17. Too long.
                         
                         // Re-reading: "Result valid 10 clock cycles after start asserted (max 8 elements + 2 cycles overhead)".
                         // This implies if start is at T=0, result is at T=10.
                         // State transitions take 1 cycle.
                         // IDLE: T=0 to T=1.
                         // CHECK (length 8, pairs 7): T=1 to T=8.
                         // Total 8 cycles elapsed. Need 2 more cycles.
                         // CHECK (length 0): T=1 to T=1. Need 9 more cycles.
                         
                         // Let's change the counter in WAIT_LATENCY to be a 'remaining wait' counter.
                         // Or just a cycle counter that increments. 
                         // Let's use the 'count' register to count cycles since start?
                         // But 'count' was used for index.
                         // Let's reset 'count' to 0 when we enter WAIT_LATENCY, 
                         // and wait FIXED number of cycles depending on length? No, that's variable.
                         
                         // Correct approach:
                         // We need a global cycle counter, or we calculate remaining wait.
                         // "Max 8 elements + 2 overhead". 
                         // Let's define WAIT_LATENCY as 2 cycles.
                         // If length <= 1, we need 9 cycles of wait after IDLE.
                         // The statement "max 8 elements + 2 overhead" suggests the case length=8 is handled by 2 cycles overhead.
                         // So for length=8, wait 2 cycles.
                         // For length=1, wait 9 cycles.
                         // Let's implement this calculation.
                         // Or, simpler: Just wait 10 cycles total, but reuse the index counter?
                         // No.
                         
                         // Let's use a fresh counter 'wait_cnt' if we can, or repurpose 'count'.
                         // Since we are in WAIT_LATENCY, 'count' is free.
                         // But we need to know how many cycles to wait.
                         // We can calculate remaining wait as (10 - current_cycle).
                         // Current cycle is roughly... we can't easily track global cycle count in the module without a wide counter.
                         // But we know: 
                         // If we just finished checking, the time elapsed is (length <= 1 ? 1 : (length - 1 + 1)).
                         // So elapsed = (length <= 1) ? 1 : length.
                         // (Wait: IDLE is 1. CHECK is length-1. Total = length).
                         // So elapsed cycles = length.
                         // We need total 10. So we need to wait (10 - length) cycles.
                         // If length=8, wait 2. If length=1, wait 9.
                         // Let's do that.
                         // We can store 'length' in a temp register or just use it since it's an input (assumed stable).
                         // 
                         // Wait, 'length' is an input. It might change. We should latch it in IDLE.
                         // Let's add a latch for 'length_latch' or rely on 'count' logic.
                         // Actually, we can use 'count' to track how many cycles we have WAITED in this state.
                         // We want to wait (10 - length).
                         // So if count < (10 - length), stay here.
                         // But 10 - length needs to be computed. 
                         // Max length is 8, so 10-8=2. Min length 0 -> 10.
                         // Let's use a temporary calculation.
                         
                         wire [3:0] wait_time = 4'd10 - {1'b0, length};
                         if (count < wait_time) begin
                             count <= count + 1;
                             state <= WAIT_LATENCY;
                         end else begin
                             state <= DONE_STATE;
                         end
                    end else begin
                         // Should not happen if logic above is correct, but default safety
                         state <= DONE_STATE;
                    end
                    // Note: The calculation 10 - length works because:
                    // IDLE takes 1.
                    // CHECK takes (length-1) (if length > 1).
                    // If length > 1, Total before wait = 1 + length - 1 = length.
                    // If length <= 1, CHECK is skipped. Total before wait = 1.
                    // Does 10 - length cover both? 
                    // If length=0: 10-0=10. We waited 1 in IDLE. Total 11? 
                    // Spec: "Empty... return 1". Spec says "10 cycles after start".
                    // If length=0, we go IDLE -> WAIT. Elapsed 1. Need 9 more.
                    // 10 - 0 = 10. That's 1 too many. 
                    // Let's fix: We need to wait (9 - length) for the length <= 1 case? No.
                    // Let's distinguish length in the WAIT_LATENCY entry logic.
                    // If length <= 1: wait 9 more cycles.
                    // If length > 1: wait (10 - length) more cycles.
                    // We can encode this in the state entry or use a flag.
                    // Let's check if length <= 1 in IDLE and branch to a specific wait state?
                    // Or pass a parameter.
                    // Let's just use a case statement for the wait duration.
                end
                
                DONE_STATE: begin
                    result <= res_reg;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                        result <= 1'b0;
                    end else begin
                        state <= DONE_STATE; // Hold
                    end
                end
            endcase
        end
    end

    // Logic refinement for WAIT_LATENCY:
    // We need to handle the variable wait time. 
    // The code inside WAIT_LATENCY above requires 'count' to be initialized to 0.
    // But the calculation `wait_time = 10 - length` is flawed for length=0/1 as discussed.
    // Let's implement the following logic inside WAIT_LATENCY:
    // 
    // We need to wait until total cycles from start == 10.
    // We entered WAIT_LATENCY at cycle `length` (if length > 1) or cycle `1` (if length <= 1).
    // We can express this as: current_cycle = (length > 1) ? length : 1;
    // We want to stay in WAIT_LATENCY until current_cycle + count == 10.
    // count starts at 0. So stop when count == 10 - current_cycle.
    // 
    // current_cycle = (length > 1) ? length : 1;
    // wait_target = 10 - current_cycle.
    // wait_target = (length > 1) ? (10 - length) : 9;
    // 
    // Let's verify:
    // Length=8: wait_target = 10-8 = 2. 
    //   Check cycle 7. Wait 0, 1. Cycle 9. Wait 2? Wait.
    //   IDLE: T0->T1. 
    //   CHECK: T1->T2...T8 (7 cycles? Wait. T1 to T2 is 1 cycle. 7 pairs -> 7 cycles. T1 to T8).
    //   So CHECK finishes at T=8. We enter WAIT_LATENCY at T=8.
    //   We need result at T=10. So we need 2 cycles (T=8->9, T=9->10).
    //   Wait target 2. Correct.
    // Length=1: wait_target = 9. 
    //   IDLE: T0->T1. Enter WAIT at T=1. Need T=10. Wait 9 cycles. Correct.
    // Length=0: wait_target = 9.
    //   Same as length=1. Correct.
    
    // Implementation in the WAIT_LATENCY state:
    // We need to compute target based on length.
    // Since length is an input, we can use it directly.
    // If we use 'count' to track wait cycles (0,1,2...), 
    // we stop when count == target.
    // target = (length > 1) ? (10 - length) : 4'd9;
    // 
    // However, we can't use 'length' in the sequential block easily if we want to avoid latch logic in comb block 
    // (though in seq block it's fine, but we need to compute next state).
    // 
    // Let's rewrite the WAIT_LATENCY section inside the always block:
    
    /*
    WAIT_LATENCY: begin
        // Calculate target wait cycles
        reg [3:0] target;
        if (length > 1) 
            target = 10 - length;
        else 
            target = 9;
            
        if (count < target) begin
            count <= count + 1;
            state <= WAIT_LATENCY;
        end else begin
            state <= DONE_STATE;
        end
    end
    */
    // Wait, `length` changes can cause glitches if not stable. 
    // But `length` is an input. It should be stable during operation.
    // We must assume `start` and `length` are held until done.
    // 
    // Also, note that `count` in IDLE is reset. In CHECK, it acts as index.
    // When we transition to WAIT_LATENCY, `count` is reset to 0.
    // So we can use `count` as the wait counter.

endmodule

module monotonic_check (
    input clk,
    input rst_n,
    input start,
    input [2:0] length,
    input [7:0] data [0:7],
    output reg result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam WAIT = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state;
    reg [3:0] count; // index in CHECK, timer in WAIT
    reg [1:0] dir;   // 0=unknown, 1=inc, 2=dec
    reg res;         // internal result

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            count <= 4'd0;
            dir <= 2'b00;
            res <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        count <= 4'd0;
                        dir <= 2'b00;
                        res <= 1'b1; // Assume monotonic
                        
                        if (length <= 3'd1) begin
                            // Trivial case, go to wait
                            state <= WAIT;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // count acts as index
                    if (count < length - 1) begin
                        // Compare adjacent
                        if (data[count] < data[count + 1]) begin
                            if (dir == 2'b00) dir <= 2'b01;
                            else if (dir == 2'b10) res <= 1'b0;
                        end else if (data[count] > data[count + 1]) begin
                            if (dir == 2'b00) dir <= 2'b10;
                            else if (dir == 2'b01) res <= 1'b0;
                        end
                        count <= count + 1;
                    end else begin
                        // Check finished
                        state <= WAIT;
                        count <= 4'd0; // Reset counter for timing
                    end
                end

                WAIT: begin
                    // We need to wait until 10 cycles from start have passed.
                    // Elapsed time before WAIT:
                    // If length > 1: 1 (IDLE) + (length - 1) (CHECK) = length cycles.
                    // If length <= 1: 1 (IDLE) = 1 cycle.
                    // Target time is 10.
                    // So we need to wait (10 - elapsed) cycles in WAIT.
                    // Let target = (length > 1) ? (10 - length) : 9;
                    
                    // Calculate target locally or use a fixed value if we can guarantee entry time.
                    // Since we are in a seq block, we can use a wire for target calculation.
                    wire [3:0] target = (length > 1) ? (10 - length) : 4'd9;
                    
                    if (count < target) begin
                        count <= count + 1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= res;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule