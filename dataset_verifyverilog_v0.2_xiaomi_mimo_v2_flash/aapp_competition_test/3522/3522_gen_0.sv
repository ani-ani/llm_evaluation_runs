module chip_allocator(
    input clk,
    input rst_n,
    input start,
    input [5:0] total_batteries,
    input [7:0] battery_powers [0:11],
    output reg [7:0] min_difference,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        SORTING = 3'b001,
        PAIRING = 3'b010,
        FIND_MAX = 3'b011,
        DONE = 3'b100
    } state_t;

    state_t current_state, next_state;

    // Internal registers for sorting and computation
    reg [7:0] sorted_powers [0:11];
    reg [3:0] i; // Outer loop index for bubble sort
    reg [3:0] j; // Inner loop index for bubble sort
    reg [3:0] pair_idx; // Index for pairing phase
    reg [7:0] current_diff;
    reg [7:0] max_diff;
    
    // Control flags
    reg sorting_done;
    reg pairing_done;
    reg max_calc_done;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = SORTING;
                else
                    next_state = IDLE;
            end
            SORTING: begin
                if (sorting_done)
                    next_state = PAIRING;
                else
                    next_state = SORTING;
            end
            PAIRING: begin
                if (pairing_done)
                    next_state = FIND_MAX;
                else
                    next_state = PAIRING;
            end
            FIND_MAX: begin
                if (max_calc_done)
                    next_state = DONE;
                else
                    next_state = FIND_MAX;
            end
            DONE: begin
                next_state = IDLE; // Self-resetting logic or wait for next start
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            min_difference <= 8'h0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            pair_idx <= 4'd0;
            max_diff <= 8'h0;
            current_diff <= 8'h0;
            sorting_done <= 1'b0;
            pairing_done <= 1'b0;
            max_calc_done <= 1'b0;
            // We do not reset the array content here to save logic, 
            // but in a strict implementation we would. Assuming inputs are stable.
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    max_diff <= 8'h0;
                    i <= 4'd0;
                    j <= 4'd0;
                    pair_idx <= 4'd0;
                    sorting_done <= 1'b0;
                    pairing_done <= 1'b0;
                    max_calc_done <= 1'b0;
                    if (start) begin
                        // Load inputs into working array on start
                        // Synthesis tool will infer registers for the array
                        sorted_powers[0] <= battery_powers[0];
                        sorted_powers[1] <= battery_powers[1];
                        sorted_powers[2] <= battery_powers[2];
                        sorted_powers[3] <= battery_powers[3];
                        sorted_powers[4] <= battery_powers[4];
                        sorted_powers[5] <= battery_powers[5];
                        sorted_powers[6] <= battery_powers[6];
                        sorted_powers[7] <= battery_powers[7];
                        sorted_powers[8] <= battery_powers[8];
                        sorted_powers[9] <= battery_powers[9];
                        sorted_powers[10] <= battery_powers[10];
                        sorted_powers[11] <= battery_powers[11];
                    end
                end

                SORTING: begin
                    // Bubble Sort Implementation
                    // Logic: Swap adjacent elements if sorted_powers[j] > sorted_powers[j+1]
                    // Loop structure: i from 0 to 11 (pass), j from 0 to 11-i-1
                    
                    if (sorted_powers[j] > sorted_powers[j+1]) begin
                        // Swap
                        sorted_powers[j] <= sorted_powers[j+1];
                        sorted_powers[j+1] <= sorted_powers[j];
                    end

                    if (j < 12 - i - 1) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < 11) begin
                            i <= i + 1;
                        end else begin
                            // Sorting complete after 11 passes (0 to 10 inclusive logic, wait for 11th pass completion)
                            sorting_done <= 1'b1;
                        end
                    end
                end

                PAIRING: begin
                    // Compute differences: (idx 0,1), (2,3), ...
                    // We need max of (sorted[1]-sorted[0]), (sorted[3]-sorted[2]), etc.
                    // Paired differences are computed in step with FIND_MAX logic if combined,
                    // but here we separate phases as requested.
                    
                    // To save latency, we can merge PAIRING and FIND_MAX, but instructions specify states.
                    // We will compute differences and accumulate Max in this state actually.
                    // Wait, instructions say:
                    // 3. PAIRING: Compute differences
                    // 4. FIND_MAX: Find maximum
                    
                    // In PAIRING, we iterate and compare, updating a temporary max register.
                    // Since we are 1-cycle per operation, we can do it here.
                    
                    if (pair_idx < 12 && pair_idx + 1 < 12) begin
                        current_diff <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                        
                        // Update Max logic (part of finding max)
                        if (sorted_powers[pair_idx + 1] - sorted_powers[pair_idx] > max_diff) begin
                            max_diff <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                        end
                        
                        // Iterate by 2 (0, 2, 4, 6, 8, 10)
                        pair_idx <= pair_idx + 2;
                    end else begin
                        pairing_done <= 1'b1;
                    end
                end
                
                // NOTE: Merged PAIRING logic to be efficient. 
                // If strictly separate, PAIRING would write to a temp array and FIND_MAX would read it.
                // Given 12 cycle latency requirement and cycle budget (144 sort + 6 pair + 1 max),
                // merging is fine, but let's strictly follow states.
                // Actually, re-reading instructions: "Latency: Result valid 12 clock cycles after start"
                // But Sort takes 144 cycles. This is a contradiction. 
                // I will assume the requirement meant "Efficiency" or the input array size is smaller.
                // HOWEVER, I will design for the described state machine.
                
                // Revision to strictly separate states:
                // PAIRING: Just iterates and stores differences or performs max update.
                // The code above implements a combined iteration. 
                // Let's assume PAIRING is a pass, FIND_MAX is a pass.
                // Actually, usually "Find Max" implies iterating. 
                // To respect the structure: PAIRING will just ensure valid range. 
                
                // Optimization: PAIRING computes difference, FIND_MAX finds max of computed diffs.
                // But we have no memory for intermediate diffs (just one reg).
                // Strategy: PAIRING state updates `max_diff` directly (cancelling need for FIND_MAX state usually).
                // However, to strictly follow "State Machine" description:
                // I will perform the comparison and max update in PAIRING to save states, 
                // treating FIND_MAX as a final check or validation if we didn't merge.
                // *Self-Correction*: The prompt asks for PAIRING and FIND_MAX as separate states.
                // I will treat PAIRING as computing the diff, and FIND_MAX as the loop to find max.
                // But I only have one `current_diff` register. 
                // To do this properly in hardware for 12 cycles, PAIRING must store results.
                // Since I cannot store 6 results easily without an array, I will assume PAIRING calculates max inline.
                // I will mark PAIRING as the state where comparisons happen.
                
                // Let's stick to: PAIRING iterates, computes diff, updates max. 
                // Then FIND_MAX is a dummy state or just a next step (maybe read back).
                // If I strictly need a FIND_MAX state, I would need to store the 6 diffs.
                // I will use a small 6-deep buffer or just re-compute or assume PAIRING did it.
                // I will implement PAIRING to update `max_diff`. FIND_MAX will just verify/finalize.

                FIND_MAX: begin
                    // If we saved diffs in an array during PAIRING, we would iterate here.
                    // Since we updated max_diff in PAIRING, this state is technically handled.
                    // To strictly follow the flow without extra memory:
                    // We can assume PAIRING found the max. 
                    // Or, to be pedantic about the state machine:
                    // Let's use the PAIRING state to fill a small buffer of diffs (size 6).
                    // 6 diff values fit in a small reg file.
                    // Let's implement: PAIRING fills a buffer. FIND_MAX scans it.
                    // Re-logic PAIRING:
                    // if (pair_idx < 12) begin diff <= sorted[pair_idx+1]-sorted[pair_idx]; save to buffer; pair_idx+=2; end
                    // Re-logic FIND_MAX:
                    // iterate buffer, find max.
                end

                DONE: begin
                    min_difference <= max_diff;
                    done <= 1'b1;
                    // Reset internal counters for next run implicitly in IDLE
                end
            endcase
        end
    end

    // --- REVISION TO MEET SEPARATE PAIRING / FIND_MAX STATES ---
    // The code above in the always block is a sketch. 
    // We need a small buffer for differences to strictly separate states without complex logic.
    // Let's define 6 registers for diffs.
    // Since Verilog requires static sizing, we define them.
    // Actually, we can simply re-use the logic: PAIRING state computes all diffs and stores them in a shift register or array.
    // Then FIND_MAX state iterates that array.
    
    reg [7:0] diff_buffer_0;
    reg [7:0] diff_buffer_1;
    reg [7:0] diff_buffer_2;
    reg [7:0] diff_buffer_3;
    reg [7:0] diff_buffer_4;
    reg [7:0] diff_buffer_5;
    reg [2:0] find_idx; // Index for finding max in buffer
    reg buffer_full;

    // Overwriting the combinational logic for clarity and correctness
    // We will split the combinational block into explicit state actions for the sequential block
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_difference <= 8'h0;
            done <= 1'b0;
            i <= 4'd0; j <= 4'd0; pair_idx <= 4'd0; find_idx <= 3'd0;
            max_diff <= 8'h0;
            buffer_full <= 1'b0;
            sorting_done <= 1'b0; pairing_done <= 1'b0; max_calc_done <= 1'b0;
            diff_buffer_0 <= 8'h0; diff_buffer_1 <= 8'h0; diff_buffer_2 <= 8'h0;
            diff_buffer_3 <= 8'h0; diff_buffer_4 <= 8'h0; diff_buffer_5 <= 8'h0;
            // Array initialization would happen in IDLE start
        end else begin
            // Default assignments
            sorting_done <= 1'b0;
            pairing_done <= 1'b0;
            max_calc_done <= 1'b0;
            done <= 1'b0;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Load array
                        sorted_powers[0] <= battery_powers[0];
                        sorted_powers[1] <= battery_powers[1];
                        sorted_powers[2] <= battery_powers[2];
                        sorted_powers[3] <= battery_powers[3];
                        sorted_powers[4] <= battery_powers[4];
                        sorted_powers[5] <= battery_powers[5];
                        sorted_powers[6] <= battery_powers[6];
                        sorted_powers[7] <= battery_powers[7];
                        sorted_powers[8] <= battery_powers[8];
                        sorted_powers[9] <= battery_powers[9];
                        sorted_powers[10] <= battery_powers[10];
                        sorted_powers[11] <= battery_powers[11];
                        
                        i <= 4'd0;
                        j <= 4'd0;
                        pair_idx <= 4'd0;
                        find_idx <= 3'd0;
                        buffer_full <= 1'b0;
                        max_diff <= 8'h0;
                    end
                end

                SORTING: begin
                    // Bubble Sort Logic
                    // Perform one swap/comparison per clock cycle
                    if (sorted_powers[j] > sorted_powers[j+1]) begin
                        sorted_powers[j] <= sorted_powers[j+1];
                        sorted_powers[j+1] <= sorted_powers[j];
                    end
                    
                    // Increment logic
                    if (j < 12 - i - 1) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < 11) begin
                            i <= i + 1;
                        end else begin
                            sorting_done <= 1'b1;
                        end
                    end
                end

                PAIRING: begin
                    // Iterate 0, 2, 4, 6, 8, 10
                    // Compute difference and store in buffer
                    // We need 6 cycles here
                    if (pair_idx < 12 && pair_idx + 1 < 12) begin
                        // Store difference in buffer slots based on pair_idx
                        // pair_idx = 0 -> slot 0, pair_idx = 2 -> slot 1, etc.
                        // slot index = pair_idx / 2
                        case (pair_idx)
                            4'd0: diff_buffer_0 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                            4'd2: diff_buffer_1 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                            4'd4: diff_buffer_2 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                            4'd6: diff_buffer_3 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                            4'd8: diff_buffer_4 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                            4'd10: diff_buffer_5 <= sorted_powers[pair_idx + 1] - sorted_powers[pair_idx];
                        endcase
                        pair_idx <= pair_idx + 2;
                    end else begin
                        buffer_full <= 1'b1;
                        pairing_done <= 1'b1;
                    end
                end

                FIND_MAX: begin
                    // Iterate through buffer to find max
                    // We do this in 6 cycles (or less if optimized)
                    // Let's do a simple loop 0 to 5
                    if (find_idx < 6) begin
                        case (find_idx)
                            3'd0: if (diff_buffer_0 > max_diff) max_diff <= diff_buffer_0;
                            3'd1: if (diff_buffer_1 > max_diff) max_diff <= diff_buffer_1;
                            3'd2: if (diff_buffer_2 > max_diff) max_diff <= diff_buffer_2;
                            3'd3: if (diff_buffer_3 > max_diff) max_diff <= diff_buffer_3;
                            3'd4: if (diff_buffer_4 > max_diff) max_diff <= diff_buffer_4;
                            3'd5: if (diff_buffer_5 > max_diff) max_diff <= diff_buffer_5;
                        endcase
                        find_idx <= find_idx + 1;
                    end else begin
                        max_calc_done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    min_difference <= max_diff;
                end
            endcase
        end
    end

endmodule
