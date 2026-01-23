module min_phone_calls (
    input clk,
    input rst_n,
    input start,
    input [4:0] detector_index,
    input [15:0] position,
    input [31:0] call_count,
    input [4:0] num_detectors,
    input data_valid,
    output reg [31:0] min_calls,
    output reg done,
    output reg error
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_DATA = 3'b001;
    localparam SORT_CHECK = 3'b010;
    localparam PROCESS_DATA = 3'b011;
    localparam COMPUTE_RESULT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Storage for detector data (32 entries max)
    reg [15:0] pos_mem [0:31];
    reg [31:0] count_mem [0:31];

    // Internal counters and registers
    reg [4:0] idx; // General purpose index
    reg [4:0] max_idx; // Number of valid detectors loaded
    
    // Computation registers
    reg [31:0] cumulative_max;
    reg [31:0] accumulated_sum;
    reg [31:0] prev_pos;
    reg [31:0] prev_count;
    
    // Temporary calculation registers for combinational logic
    reg [31:0] temp_sum;
    reg [31:0] temp_max;
    reg [31:0] diff;
    reg [31:0] overlap;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_DATA;
                else
                    next_state = IDLE;
            end
            
            LOAD_DATA: begin
                // Wait until we have loaded all detectors or data_valid goes low
                // Logic handled in sequential block to count loaded data
                if (idx >= num_detectors && !data_valid)
                    next_state = SORT_CHECK;
                else
                    next_state = LOAD_DATA;
            end
            
            SORT_CHECK: begin
                if (error)
                    next_state = DONE; // Go to done if error found
                else if (idx > max_idx) // Finished checking
                    next_state = PROCESS_DATA;
                else
                    next_state = SORT_CHECK;
            end
            
            PROCESS_DATA: begin
                if (idx >= max_idx)
                    next_state = COMPUTE_RESULT;
                else
                    next_state = PROCESS_DATA;
            end
            
            COMPUTE_RESULT: begin
                next_state = DONE;
            end
            
            DONE: begin
                // Stay in DONE until next start
                if (start)
                    next_state = LOAD_DATA;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic (State transitions and outputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_calls <= 32'b0;
            done <= 1'b0;
            error <= 1'b0;
            idx <= 5'b0;
            max_idx <= 5'b0;
            cumulative_max <= 32'b0;
            accumulated_sum <= 32'b0;
            prev_pos <= 32'b0;
            prev_count <= 32'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    idx <= 5'b0;
                    max_idx <= 5'b0;
                end

                LOAD_DATA: begin
                    // Capture data if valid and index matches current expected index
                    // We assume sequential loading based on detector_index input stream
                    // However, to be robust, we check data_valid and increment idx
                    if (data_valid && idx < 31) begin // Safety cap at 31, max is 32
                        // Store based on the input index or internal counter? 
                        // Requirements say 'detector_index' is input. 
                        // Usually for streaming data, index increments or we just use a write pointer.
                        // Let's use the input detector_index to know where to write, but track completion by counting.
                        pos_mem[detector_index] <= position;
                        count_mem[detector_index] <= call_count;
                        
                        // If we are using a counter to track how many we've seen
                        // The problem implies data arrives one by one.
                        // Let's increment an internal counter when data_valid is high.
                        // But wait, the interface gives 'detector_index'. 
                        // If the sender drives detector_index sequentially, we can just use it.
                        // Let's assume data_valid pulses for each detector.
                        // Increment 'max_idx' (count of loaded items) when data_valid is high.
                        if (idx < num_detectors) begin
                             idx <= idx + 1;
                        end
                    end
                    
                    // If we finished loading all required detectors based on num_detectors input
                    // Or if we rely on counting data_valid pulses.
                    // The problem says: "increment detector_index internally". 
                    // Let's stick to a counter 'idx' that tracks how many we stored.
                    if (data_valid && idx < num_detectors) begin
                        max_idx <= num_detectors; // We know max count from input
                        // Actually, we should wait until we have loaded num_detectors count.
                    end
                    
                    // Correction: The requirement says "increment detector_index internally".
                    // This usually implies we generate the index or ignore the input index.
                    // Let's ignore the input 'detector_index' for internal logic and use a counter `idx`.
                    if (data_valid && idx < num_detectors) begin
                        pos_mem[idx] <= position;
                        count_mem[idx] <= call_count;
                        idx <= idx + 1;
                    end
                    max_idx <= num_detectors; // Store the total count
                end

                SORT_CHECK: begin
                    // Verify strictly increasing positions
                    if (idx < max_idx) begin // Check from index 0 to max_idx-1
                        // We need to compare pos_mem[idx] < pos_mem[idx+1]
                        // So we need to iterate idx from 0 to max_idx - 2.
                        // Let's reset idx to 0 before entering this state (in LOAD_DATA transition)
                        if (idx < max_idx - 1) begin
                            if (pos_mem[idx] >= pos_mem[idx+1]) begin
                                error <= 1'b1;
                            end
                            idx <= idx + 1;
                        end else begin
                            idx <= idx + 1; // Finish iteration
                        end
                    end
                    // If error was set, we will transition to DONE
                end

                PROCESS_DATA: begin
                    // Process detector at index 'idx'
                    // Logic:
                    // 1. Update cumulative_max = max(cumulative_max, C_i)
                    // 2. If idx > 0: Calculate overlap = max(0, (prev_pos + prev_count) - pos_mem[idx])
                    //    Subtract overlap from count_mem[idx]. If result < 0, overlap = count_mem[idx].
                    //    Add (count_mem[idx] - overlap) to accumulated_sum.
                    //    Note: In problem description, it was sum(min(C_i, Gap)).
                    //    The most direct interpretation for hardware:
                    //    If (prev_pos + prev_count) > pos_mem[idx]:
                    //       overlap = (prev_pos + prev_count) - pos_mem[idx]
                    //       effective = count_mem[idx] - overlap (if > 0)
                    //    Else: effective = count_mem[idx]
                    
                    if (idx < max_idx) begin
                        // Update cumulative_max
                        if (count_mem[idx] > cumulative_max) begin
                            cumulative_max <= count_mem[idx];
                        end

                        // Calculate sum contribution
                        if (idx > 0) begin
                            // Check for overlap
                            // Need to handle 32-bit positions? Input is 16-bit. Let's extend to 32 for safety.
                            // prev_pos is 32-bit, pos_mem is 16-bit. Extend pos_mem.
                            if ( (prev_pos + prev_count) > {16'b0, pos_mem[idx]} ) begin
                                // Overlap exists
                                diff <= (prev_pos + prev_count) - {16'b0, pos_mem[idx]};
                                // We cannot do the subtraction and add in the same cycle without intermediate reg or logic
                                // Let's use a combinational block or just do it sequentially carefully.
                                // Actually, let's compute effective count now.
                                if ( (prev_pos + prev_count) - {16'b0, pos_mem[idx]} >= count_mem[idx] ) begin
                                    // Completely overlapped, adds 0
                                    // accumulated_sum <= accumulated_sum; 
                                end else begin
                                    accumulated_sum <= accumulated_sum + (count_mem[idx] - ((prev_pos + prev_count) - {16'b0, pos_mem[idx]}));
                                end
                            end else begin
                                // No overlap
                                accumulated_sum <= accumulated_sum + count_mem[idx];
                            end
                            
                            // Update previous trackers for NEXT iteration
                            // If no overlap (or partial), the new effective start/end might be relevant if we were tracking active intervals.
                            // But the problem asks for sum of non-overlapping lengths.
                            // The previous interval (prev_pos, prev_count) defines the 'blocked' area.
                            // We only care about the NEXT overlap check.
                            // Usually, for calculating overlap with the NEXT item, we need to know the "reach" of the current set of accumulated intervals.
                            // If we just sum min(C_i, Gap), we only need the previous item's reach.
                            // But what if intervals overlap multiple times? The formula max(max(C_i), sum(min(C_i, Gap))) is derived from disjoint intervals logic.
                            // Let's re-verify: sum(min(C_i, Gap)) implies we take C_i, subtract overlap with PREVIOUS (accumulated group).
                            // The "previous" item in the sum formula should represent the furthest reach of the accumulated sum so far.
                            // So we must update 'prev_pos' and 'prev_count' to be the effective end of the CURRENT interval.
                            // Current interval ends at max(prev_pos + prev_count, pos_mem[idx] + count_mem[idx])? 
                            // No, usually we compare with the current detector's position.
                            // Let's stick to the specific formula derived: max(max_C, sum of min(C_i, Gaps)).
                            // To calculate Gap_i = P_i - (P_{i-1} + C_{i-1}), we strictly use the immediate previous item.
                            // So we just update prev_pos and prev_count to the current item's raw data (P_i, C_i).
                            // Wait, if P_2 overlaps P_1, then Gap_2 is 0. P_3 might overlap P_2.
                            // If P_3 > P_2 + C_2, then Gap_3 = P_3 - (P_2 + C_2).
                            // We strictly use the raw previous values.
                        end else begin
                            // idx == 0 (First item)
                            // In sum(min(C_i, Gap)), the first item usually has infinite gap? Or full C_0?
                            // Typically, sum formula includes C_0. 
                            // Let's add the full first count.
                            accumulated_sum <= count_mem[0];
                        end

                        // Prepare for next iteration
                        prev_pos <= {16'b0, pos_mem[idx]};
                        prev_count <= count_mem[idx];

                        idx <= idx + 1;
                    end
                end

                COMPUTE_RESULT: begin
                    // Final answer: max(cumulative_max, accumulated_sum)
                    if (cumulative_max > accumulated_sum) begin
                        min_calls <= cumulative_max;
                    end else begin
                        min_calls <= accumulated_sum;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Reset for next run happens implicitly by going to IDLE logic or handling here.
                        // Since we are in IDLE logic in the next cycle, we just need to ensure clean slate.
                        done <= 1'b0;
                        error <= 1'b0;
                        idx <= 5'b0;
                    end
                end
            endcase
        end
    end

    // Fix for LOAD_DATA and PROCESS_DATA sequential logic:
    // The logic above in LOAD_DATA has a conflict with the requirement "increment detector_index internally".
    // It implies we might not use the input detector_index. 
    // Also, the PROCESS_DATA logic for sum(min(C_i, Gap)) needs to be precise.
    // Let's refine the sequential block for clarity and correctness.

    // Re-implementing the sequential block to ensure correctness based on the refined understanding
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_calls <= 32'b0;
            done <= 1'b0;
            error <= 1'b0;
            idx <= 5'b0;
            max_idx <= 5'b0;
            cumulative_max <= 32'b0;
            accumulated_sum <= 32'b0;
            prev_pos <= 32'b0;
            prev_count <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= LOAD_DATA;
                        idx <= 5'b0;
                    end
                end

                LOAD_DATA: begin
                    // Assume data_valid pulses for each detector sequentially.
                    // Ignore detector_index input for internal counting (per instructions to increment internally).
                    if (data_valid && idx < 31) begin
                        pos_mem[idx] <= position;
                        count_mem[idx] <= call_count;
                        idx <= idx + 1;
                    end
                    
                    // Transition check: We need to know when data loading is done.
                    // The input 'num_detectors' tells us how many to expect.
                    // If we have counted 'num_detectors' valid inputs, move to SORT_CHECK.
                    // Since we increment 'idx' on data_valid, we compare idx with num_detectors.
                    if (idx == num_detectors && !data_valid) begin
                        state <= SORT_CHECK;
                        idx <= 5'b0; // Reset for sort check loop
                        max_idx <= num_detectors;
                    end
                    // Safety: timeout if data stops early? (Not required, but good practice. Skipped here).
                end

                SORT_CHECK: begin
                    // Check indices 0 to max_idx - 2 against 1 to max_idx - 1
                    if (idx < max_idx - 1) begin
                        // Check if pos_mem[idx] < pos_mem[idx+1]
                        if (pos_mem[idx] >= pos_mem[idx+1]) begin
                            error <= 1'b1;
                            // Immediately go to done? Or finish check? 
                            // Let's set error and transition to DONE next cycle.
                            // To do that, we can't transition here inside always block easily without duplicate logic.
                            // Let's rely on the combinational next_state logic to see 'error' and go to DONE.
                        end
                        idx <= idx + 1;
                    end else begin
                        // Finished checking
                        // If error was set, next_state logic will pick DONE.
                        // If not, it picks PROCESS_DATA.
                        // We need to ensure idx is reset for PROCESS_DATA.
                        if (next_state == PROCESS_DATA) begin
                             idx <= 5'b0;
                        end
                    end
                end

                PROCESS_DATA: begin
                    // Process detector at index 'idx'
                    // We process indices 0 to max_idx - 1
                    if (idx < max_idx) begin
                        // 1. Update cumulative_max
                        if (count_mem[idx] > cumulative_max) begin
                            cumulative_max <= count_mem[idx];
                        end

                        // 2. Sum Logic (sum of min(C_i, Gap))
                        // Gap is defined as P_i - (P_{i-1} + C_{i-1}).
                        // For i=0, we treat it as full contribution (Gap = C_0 effectively, or just add C_0).
                        if (idx == 0) begin
                            accumulated_sum <= count_mem[0];
                            // Update prev trackers
                            prev_pos <= {16'b0, pos_mem[0]};
                            prev_count <= count_mem[0];
                        end else begin
                            // Calculate Gap
                            // Effective Gap = pos_mem[idx] - (prev_pos + prev_count)
                            // Note: positions are 16-bit, but prev_pos/prev_count are 32-bit.
                            // We need to extend pos_mem[idx] to 32 bit for subtraction.
                            
                            // Let's calculate potential overlap and contribution
                            // We need to do this combinationally or in a staged manner.
                            // Since it's sequential, we can calculate step-by-step.
                            // However, we can do math in one cycle if we define the intermediate values.
                            
                            // Calculate: Reach = prev_pos + prev_count
                            // If (pos_mem[idx] < Reach): Overlap = Reach - pos_mem[idx]
                            // Contribution = count_mem[idx] - Overlap (if > 0)
                            // Else: Contribution = count_mem[idx]
                            
                            // Let's define intermediate terms in combinational logic or sequential logic
                            // To keep it clean in sequential block:
                            
                            if ({16'b0, pos_mem[idx]} < (prev_pos + prev_count)) begin
                                // Overlap
                                if ( ({16'b0, pos_mem[idx]} + count_mem[idx]) < (prev_pos + prev_count) ) begin
                                    // Fully overlapped
                                    // Add 0 to accumulated_sum
                                end else begin
                                    // Partially overlapped
                                    accumulated_sum <= accumulated_sum + (({16'b0, pos_mem[idx]} + count_mem[idx]) - (prev_pos + prev_count));
                                end
                            end else begin
                                // No overlap
                                accumulated_sum <= accumulated_sum + count_mem[idx];
                            end
                            
                            // Update prev trackers for next cycle
                            prev_pos <= {16'b0, pos_mem[idx]};
                            prev_count <= count_mem[idx];
                        end

                        idx <= idx + 1;
                    end else begin
                        // Done processing all
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    // Final answer
                    if (cumulative_max > accumulated_sum) begin
                        min_calls <= cumulative_max;
                    end else begin
                        min_calls <= accumulated_sum;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Reset outputs/indices for next run immediately or wait for IDLE transition.
                        // The state machine stays in DONE until start goes low and then high? 
                        // Or just restarts. Let's assume we restart on 'start'.
                        // We need to clear internal regs.
                        state <= IDLE; // Loop back to IDLE to reset logic
                    end
                end
            endcase
        end
    end

endmodule
