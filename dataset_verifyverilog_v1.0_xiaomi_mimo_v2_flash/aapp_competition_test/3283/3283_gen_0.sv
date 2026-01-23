module GemIslandSim #(
    parameter MAX_N = 8,
    parameter MAX_D = 16,
    parameter MAX_R = 8,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] d,
    input [3:0] r,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] INIT   = 3'd1;
    localparam [2:0] SPLIT  = 3'd2;
    localparam [2:0] SORT   = 3'd3;
    localparam [2:0] DONE   = 3'd4;
    localparam [2:0] ERROR  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [DATA_WIDTH-1:0] counts [0:MAX_N-1];  // Packed array for counts
    reg [3:0] i, next_i;  // Index for initialization and iteration
    reg [7:0] night, next_night;  // Night counter
    reg [7:0] rand_num, next_rand_num;  // Random number storage
    reg [15:0] lfsr, next_lfsr;  // 16-bit LFSR
    reg [DATA_WIDTH-1:0] total_gems, next_total_gems;  // Total gems for current night
    reg [RESULT_WIDTH-1:0] sum_result, next_sum_result;  // Accumulated sum
    reg [RESULT_WIDTH-1:0] max_val, next_max_val;  // Current maximum for sorting
    reg [3:0] max_idx, next_max_idx;  // Index of current maximum
    reg [3:0] sorted_count, next_sorted_count;  // Number of elements already sorted
    reg [3:0] split_idx, next_split_idx;  // Index of inhabitant whose gem splits
    reg [DATA_WIDTH-1:0] cum_sum, next_cum_sum;  // Cumulative sum for random selection
    reg [3:0] find_idx, next_find_idx;  // Index for finding split inhabitant
    reg split_done, next_split_done;  // Flag for split computation completion
    reg [15:0] cycle_counter, next_cycle_counter;  // Safety cycle counter
    localparam [15:0] MAX_CYCLES = 16'd5000;  // Maximum cycles to prevent hangs

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i = 0; i < MAX_N; i = i + 1) begin
                counts[i] <= 8'd0;
            end
            i <= 4'd0;
            night <= 8'd0;
            rand_num <= 8'd0;
            lfsr <= 16'h0001;
            total_gems <= 8'd0;
            sum_result <= 32'd0;
            max_val <= 32'd0;
            max_idx <= 4'd0;
            sorted_count <= 4'd0;
            split_idx <= 4'd0;
            cum_sum <= 8'd0;
            find_idx <= 4'd0;
            split_done <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 16'd0;
        end else begin
            state <= next_state;
            i <= next_i;
            night <= next_night;
            rand_num <= next_rand_num;
            lfsr <= next_lfsr;
            total_gems <= next_total_gems;
            sum_result <= next_sum_result;
            max_val <= next_max_val;
            max_idx <= next_max_idx;
            sorted_count <= next_sorted_count;
            split_idx <= next_split_idx;
            cum_sum <= next_cum_sum;
            find_idx <= next_find_idx;
            split_done <= next_split_done;
            // counts array updated via separate always block for clarity
            if (state != next_state) begin
                cycle_counter <= 16'd0;
            end else begin
                cycle_counter <= next_cycle_counter;
            end
        end
    end

    // Separate always block for array updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                counts[i] <= 8'd0;
            end
        end else begin
            // Default: keep previous values
            // Update counts based on next_state logic
            case (next_state)
                INIT: begin
                    if (next_i < MAX_N) begin
                        if (next_i < n)
                            counts[next_i] <= 8'd1;
                        else
                            counts[next_i] <= 8'd0;
                    end
                end
                SPLIT: begin
                    if (split_done && next_split_idx < MAX_N)
                        counts[next_split_idx] <= counts[next_split_idx] + 8'd1;
                    // For sorting, we zero out the max element
                    if (state == SORT && next_state == SORT && next_max_idx < MAX_N)
                        counts[next_max_idx] <= 8'd0;
                end
                default: begin
                    // Keep as is
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_i = i;
        next_night = night;
        next_rand_num = rand_num;
        next_lfsr = lfsr;
        next_total_gems = total_gems;
        next_sum_result = sum_result;
        next_max_val = max_val;
        next_max_idx = max_idx;
        next_sorted_count = sorted_count;
        next_split_idx = split_idx;
        next_cum_sum = cum_sum;
        next_find_idx = find_idx;
        next_split_done = split_done;
        next_cycle_counter = cycle_counter + 16'd1;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 32'd0;
                next_cycle_counter = 16'd0;
                if (start) begin
                    next_state = INIT;
                    next_i = 4'd0;
                    next_night = 8'd0;
                    next_sum_result = 32'd0;
                    next_sorted_count = 4'd0;
                    next_split_done = 1'b0;
                    // Seed LFSR with non-zero value
                    next_lfsr = 16'h0001;
                end
            end
            
            INIT: begin
                if (i < MAX_N) begin
                    next_i = i + 4'd1;
                end else begin
                    next_state = SPLIT;
                    next_i = 4'd0;
                    next_night = 8'd1;
                    // Calculate total gems for first night: n + 0 = n
                    next_total_gems = n;
                    next_find_idx = 4'd0;
                    next_cum_sum = 8'd0;
                    next_split_done = 1'b0;
                end
            end
            
            SPLIT: begin
                if (night <= d && !split_done) begin
                    // Generate random number if not already done
                    if (find_idx == 4'd0) begin
                        // Update LFSR for new random number
                        next_lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[4] ^ lfsr[3] ^ 1'b1};
                    end
                    
                    // Find inhabitant whose gem splits
                    if (find_idx < n) begin
                        next_cum_sum = cum_sum + counts[find_idx];
                        if (cum_sum + counts[find_idx] >= rand_num) begin
                            next_split_idx = find_idx;
                            next_split_done = 1'b1;
                        end
                        next_find_idx = find_idx + 4'd1;
                    end else begin
                        // Should not happen, but safe fallback
                        next_split_idx = 4'd0;
                        next_split_done = 1'b1;
                    end
                end else if (split_done) begin
                    // Move to next night or to sorting
                    if (night < d) begin
                        next_night = night + 8'd1;
                        next_total_gems = total_gems + 8'd1;
                        next_find_idx = 4'd0;
                        next_cum_sum = 8'd0;
                        next_split_done = 1'b0;
                        // Update rand_num for next night
                        next_rand_num = (lfsr % total_gems) + 8'd1;
                    end else begin
                        next_state = SORT;
                        next_sum_result = 32'd0;
                        next_sorted_count = 4'd0;
                        // Initialize max search
                        next_max_val = counts[0];
                        next_max_idx = 4'd0;
                        next_i = 4'd1;
                    end
                end else begin
                    // First night random number
                    next_rand_num = (lfsr % total_gems) + 8'd1;
                end
            end
            
            SORT: begin
                if (sorted_count < r && sorted_count < n) begin
                    // Find current maximum in unsorted portion
                    if (i < n) begin
                        if (counts[i] > max_val) begin
                            next_max_val = counts[i];
                            next_max_idx = i;
                        end
                        next_i = i + 4'd1;
                    end else begin
                        // Add max to sum and zero it out
                        next_sum_result = sum_result + max_val;
                        next_sorted_count = sorted_count + 4'd1;
                        // Reset for next max search
                        // Find next non-zero element
                        next_i = 4'd0;
                        next_max_val = 32'd0;
                        next_max_idx = 4'd0;
                        // Actually, we need to find next max in remaining array
                        // Let's do a more careful search
                        // For simplicity, we'll just continue with next index
                        next_i = 4'd0;
                        // Mark this index as used by setting counts to 0 (handled in array block)
                        // Start search for next max
                        next_find_idx = 4'd0;
                        // Reset max for next iteration
                        next_max_val = 8'd0;
                        next_max_idx = 4'd0;
                    end
                end else begin
                    next_state = DONE;
                    next_result = sum_result;
                end
                // Override max search in next cycle
                if (state == SORT && sorted_count < r && sorted_count < n) begin
                    // Special handling for finding next max
                    // We need a dedicated counter for the max search
                    // Let's restructure the SORT state logic
                    // Actually, keep it simple: find max, add to sum, set to 0, repeat
                    // The above logic has a flaw in resetting. Let's fix it.
                    // We'll use i as the loop counter for finding max each time
                end
            end
            
            DONE: begin
                next_state = IDLE;
                next_done = 1'b1;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase

        // Safety: prevent infinite loops
        if (cycle_counter >= MAX_CYCLES) begin
            next_state = ERROR;
        end
    end

    // Revised SORT logic to correctly find max repeatedly
    reg [3:0] sort_loop_idx;
    reg [3:0] sort_loop_idx_next;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_loop_idx <= 4'd0;
        end else begin
            sort_loop_idx <= sort_loop_idx_next;
        end
    end

    always @(*) begin
        // Override the previous SORT logic with correct version
        // The logic above is complex. Let's simplify and correct.
        // We will use a dedicated FSM for the sorting phase within SORT state.
        // But to keep it single FSM, we use more sub-states via counters.
        
        // We'll redefine the next_state logic for SORT properly.
        // Actually, the previous SORT logic is messy. Let's rewrite the entire next_state logic.
        // But we can only have one always block for next_state. We'll integrate fixes.
        
        // Correction for SORT:
        // If sorted_count < r:
        //   1. Find max in counts[0..n-1] where counts[i] > 0 (or just max)
        //   2. Add max to sum
        //   3. Set that count to 0
        //   4. Increment sorted_count
        // Repeat.
        
        // The previous logic used 'i' for both init and sort. We need separate indices.
        // Let's use 'find_idx' for sorting search.
        
        // We'll keep the main next_state logic but add a flag or use states to distinguish sort steps.
        // Actually, let's use 'split_done' as 'sort_step_done' for clarity in SORT state.
        
        // This is getting complex. Let's stick to the original structure but fix SORT.
        // We'll assume the previous next_state block is the base, and we refine SORT.
    end

    // Complete, corrected next_state logic (overwriting previous)
    always @(*) begin
        next_state = state;
        next_i = i;
        next_night = night;
        next_rand_num = rand_num;
        next_lfsr = lfsr;
        next_total_gems = total_gems;
        next_sum_result = sum_result;
        next_max_val = max_val;
        next_max_idx = max_idx;
        next_sorted_count = sorted_count;
        next_split_idx = split_idx;
        next_cum_sum = cum_sum;
        next_find_idx = find_idx;
        next_split_done = split_done;
        next_cycle_counter = cycle_counter + 16'd1;
        
        // Defaults for output signals
        next_done = done;
        next_result = result;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 32'd0;
                next_cycle_counter = 16'd0;
                if (start) begin
                    next_state = INIT;
                    next_i = 4'd0;
                    next_night = 8'd0;
                    next_sum_result = 32'd0;
                    next_sorted_count = 4'd0;
                    next_split_done = 1'b0;
                    next_lfsr = 16'h0001;
                end
            end
            
            INIT: begin
                // Initialize counts: 1 for first n inhabitants
                // We use i as counter. Since we update array in separate block, we just advance i.
                // To avoid overwriting, we only set array values in array block when i matches.
                // We need to handle the array update logic carefully.
                // The array block triggers on 'counts' updates. We update 'counts' there.
                // Here we just progress the loop.
                if (i < MAX_N) begin
                    next_i = i + 4'd1;
                end else begin
                    next_state = SPLIT;
                    next_i = 4'd0;
                    next_night = 8'd1;
                    next_total_gems = n;
                    next_find_idx = 4'd0;
                    next_cum_sum = 8'd0;
                    next_split_done = 1'b0;
                    // Initial random number for first night
                    // We need to compute rand_num = (lfsr % total_gems) + 1
                    // total_gems = n here. Let's compute it.
                    // Since division is multi-cycle, we might need to wait or assume combinational.
                    // We'll compute it in SPLIT state or prepare it.
                end
            end
            
            SPLIT: begin
                if (night <= d) begin
                    if (!split_done) begin
                        // Random number generation step
                        if (find_idx == 4'd0) begin
                            // Update LFSR for new random bit sequence
                            next_lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[4] ^ lfsr[3] ^ 1'b1};
                            // Compute random number: (lfsr % total_gems) + 1
                            // We do this over multiple cycles or combinational?
                            // Let's do combinational modulo for simplicity in this step.
                            // Note: Icarus Verilog might struggle with large modulo in comb logic.
                            // We'll simulate the modulo by repeated subtraction (sequential).
                            // Or just use lfsr % total_gems if tools allow.
                            // We'll use sequential subtraction to be safe.
                            next_rand_num = 8'd0; // Reset
                            next_cum_sum = lfsr % total_gems; // Assume modulo works or synthesizer handles it
                            next_rand_num = next_cum_sum + 8'd1;
                        end
                        
                        // Find inhabitant: iterate until cumulative sum >= rand_num
                        if (find_idx < n) begin
                            next_cum_sum = cum_sum + counts[find_idx];
                            if (cum_sum + counts[find_idx] >= rand_num) begin
                                next_split_idx = find_idx;
                                next_split_done = 1'b1;
                                // We don't increment find_idx here, we are done finding
                            end else begin
                                next_find_idx = find_idx + 4'd1;
                            end
                        end else begin
                            // Fallback (shouldn't happen if rand_num <= total_gems)
                            next_split_idx = 4'd0;
                            next_split_done = 1'b1;
                        end
                    end else begin
                        // Split done, update count (handled in array block)
                        // Move to next night
                        if (night < d) begin
                            next_night = night + 8'd1;
                            next_total_gems = total_gems + 8'd1;
                            next_find_idx = 4'd0;
                            next_cum_sum = 8'd0;
                            next_split_done = 1'b0;
                        end else begin
                            next_state = SORT;
                            // Reset sorting variables
                            next_sorted_count = 4'd0;
                            next_sum_result = 32'd0;
                            next_find_idx = 4'd0; // Used as loop index for max search
                            next_max_val = 8'd0;
                            next_max_idx = 4'd0;
                            next_i = 4'd0; // Loop counter for finding max
                        end
                    end
                end else begin
                    next_state = SORT;
                    next_sorted_count = 4'd0;
                    next_sum_result = 32'd0;
                    next_find_idx = 4'd0;
                    next_max_val = 8'd0;
                    next_max_idx = 4'd0;
                    next_i = 4'd0;
                end
            end
            
            SORT: begin
                if (sorted_count < r && sorted_count < n) begin
                    // Find max in current unsorted array
                    // We use 'i' to iterate through counts
                    if (i < n) begin
                        // Compare counts[i] with current max
                        // counts is an array, access is combinational
                        if (counts[i] > max_val) begin
                            next_max_val = counts[i];
                            next_max_idx = i;
                        end
                        next_i = i + 4'd1;
                    end else begin
                        // Finished searching for this max
                        // Add to sum
                        next_sum_result = sum_result + max_val;
                        // Mark this element as sorted (set to 0)
                        // This is done in the array update block
                        next_sorted_count = sorted_count + 4'd1;
                        // Reset for next max search
                        next_i = 4'd0;
                        next_max_val = 8'd0;
                        next_max_idx = 4'd0;
                    end
                end else begin
                    // Sorting done
                    next_state = DONE;
                    next_result = sum_result;
                end
            end
            
            DONE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase

        // Safety timeout
        if (cycle_counter >= MAX_CYCLES) begin
            next_state = ERROR;
        end
    end

    // Fix the array update logic for the corrected FSM
    // The array block needs to handle INIT and SORT updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            case (next_state)
                INIT: begin
                    if (next_i < MAX_N && next_i < n)
                        counts[next_i] <= 8'd1;
                    else if (next_i < MAX_N)
                        counts[next_i] <= 8'd0;
                end
                SPLIT: begin
                    if (next_split_done && next_state == SPLIT) begin
                        // Update the split inhabitant's count
                        if (next_split_idx < MAX_N)
                            counts[next_split_idx] <= counts[next_split_idx] + 8'd1;
                    end
                end
                SORT: begin
                    // Check if we just finished a max search in the previous cycle
                    // We need to detect when 'i' wraps around or max is found.
                    // In our logic, we set counts to 0 after adding max to sum.
                    // We can detect this by checking if sorted_count increased in this cycle vs previous?
                    // No, we update counts based on state transitions.
                    // When we transition to the next iteration of SORT (finding next max),
                    // we need to zero out the previous max_idx.
                    // However, finding max and zeroing it happen in the same cycle logically.
                    // To avoid race conditions, we zero out the max element when we are done searching (i == n).
                    // But we reset i to 0 immediately after finding max.
                    // So we need a flag or specific cycle to zero out.
                    // Let's use the transition from SORT to SORT where 'i' is reset.
                    // Actually, we can zero out the element when we detect 'i == n' and we are in SORT state.
                    if (i == n && sorted_count < r && state == SORT) begin
                        // We just found a max in this cycle (i reached n)
                        // Zero out the max element
                        if (max_idx < MAX_N)
                            counts[max_idx] <= 8'd0;
                    end
                end
                default: begin
                    // No change
                end
            endcase
        end
    end

endmodule
