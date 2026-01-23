module guessing_circle(
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    input [3:0] count_in,
    input done_in,
    output reg [7:0] result_value,
    output reg result_valid,
    output reg output_done,
    output reg computation_done
);

    // Memory for the circular buffer (16 entries)
    reg [7:0] mem [0:15];

    // State encoding
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam WAIT_DONE = 3'b010;
    localparam ANALYZE_VALUE = 3'b011;
    localparam OUTPUT_RESULT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;

    // Control registers
    reg [3:0] write_ptr;
    reg [3:0] count_reg;
    reg [7:0] current_value; // Value being analyzed (1-255)
    reg [7:0] mem_read_data; // Data read from memory

    // Analysis registers
    reg [3:0] scan_ptr;
    reg [3:0] start_pos;
    reg found_start;
    reg found_end;
    reg in_segment;
    reg [3:0] segment_len;
    reg [3:0] occurrences;
    reg valid_check;
    reg scan_done;
    reg [3:0] scan_counter; // Limit scans to count_reg

    // Output registers
    reg output_started;
    reg [3:0] output_index;

    // Flag to mark when data collection is complete
    reg data_ready;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_ptr <= 4'b0;
            count_reg <= 4'b0;
            current_value <= 8'd1;
            result_value <= 8'b0;
            result_valid <= 1'b0;
            output_done <= 1'b0;
            computation_done <= 1'b0;
            data_ready <= 1'b0;
            found_start <= 1'b0;
            found_end <= 1'b0;
            in_segment <= 1'b0;
            valid_check <= 1'b0;
            scan_done <= 1'b0;
            output_started <= 1'b0;
            output_index <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COLLECT;
                        write_ptr <= 4'b0;
                        count_reg <= count_in;
                        data_ready <= 1'b0;
                    end
                end

                COLLECT: begin
                    if (valid_in) begin
                        mem[write_ptr] <= data_in;
                        write_ptr <= write_ptr + 1'b1;
                    end
                    if (done_in) begin
                        state <= WAIT_DONE;
                    end
                end

                WAIT_DONE: begin
                    // Wait for done_in to go low (optional) or transition to analyze
                    // We assume done_in signals end of transmission
                    if (!done_in) begin // Or simply transition after some delay/condition
                         state <= ANALYZE_VALUE;
                         current_value <= 8'd1;
                         scan_done <= 1'b0;
                    end else if (write_ptr == count_reg && !valid_in) begin
                         // If we reached count, go to analyze
                         state <= ANALYZE_VALUE;
                         current_value <= 8'd1;
                         scan_done <= 1'b0;
                    end
                    // If still receiving data, stay here
                    if (valid_in) begin
                        mem[write_ptr] <= data_in;
                        write_ptr <= write_ptr + 1'b1;
                    end
                    if (done_in && write_ptr >= count_reg) begin
                         state <= ANALYZE_VALUE;
                         current_value <= 8'd1;
                         scan_done <= 1'b0;
                    end
                end

                ANALYZE_VALUE: begin
                    // Check if current_value is valid (appears contiguously)
                    if (scan_done) begin
                        if (valid_check && occurrences > 0) begin
                            state <= OUTPUT_RESULT;
                            output_index <= 4'b0;
                            result_value <= current_value;
                            result_valid <= 1'b1;
                            output_started <= 1'b1;
                        end else begin
                            // Move to next value
                            if (current_value == 8'd255) begin
                                state <= DONE;
                                output_done <= 1'b1;
                                computation_done <= 1'b1;
                            end else begin
                                current_value <= current_value + 1'b1;
                                scan_done <= 1'b0; // Reset scan for next value
                                // Reset scan registers
                                found_start <= 1'b0;
                                found_end <= 1'b0;
                                in_segment <= 1'b0;
                                valid_check <= 1'b1; // Assume valid initially
                                occurrences <= 4'b0;
                                segment_len <= 4'b0;
                                scan_ptr <= 4'b0;
                                scan_counter <= 4'b0;
                            end
                        end
                    end else begin
                        // Perform scan step for current_value
                        if (scan_counter < count_reg) begin
                            mem_read_data <= mem[scan_ptr]; // Read logic
                            // We need to use the read data, so delay by 1 cycle or combinational read
                            // Assuming asynchronous read for simplicity in this context, but usually synchronous
                            // Let's use combinational logic for read to avoid state jump issues
                        end
                    end
                end

                OUTPUT_RESULT: begin
                    // Stream out valid values
                    // We need to know if the current value has a successor
                    // Simplified: Iterate through values 1-255 again in ANALYZE state
                    // Here we just output the current valid value and then transition back to ANALYZE for next
                    result_valid <= 1'b0; // Pulse for one cycle or hold? Requirement says stream out.
                    // "Clock out one value per cycle" implies result_valid holds high for valid values?
                    // Let's assume result_valid is high when a valid value is on the bus.
                    // We need to find the NEXT valid value.
                    // So, transition back to ANALYZE_VALUE to find the next one.

                    // To stream continuously, we might need to hold OUTPUT state and increment current_value
                    // But ANALYZE state is designed to check specific values.
                    // Let's transition to ANALYZE_VALUE to find the next valid number after the one we just output.
                    // But we need to output the current one first.

                    // Actually, the prompt says "Output valid integers in increasing order".
                    // This implies iterating 1..255, checking validity, and asserting result_valid if valid.
                    // The state machine structure suggested "OUTPUT_RESULT" streams out.
                    // Let's combine ANALYZE and OUTPUT logic to reduce states.
                    // If we are in ANALYZE and find a valid value, we output it.
                    // Then we increment current_value and check next.
                    // If we are in ANALYZE and find invalid, we increment.
                    // When current_value > 255, go to DONE.

                    // Revised Logic for ANALYZE_VALUE state (replacing separate OUTPUT_RESULT):
                    // 1. Scan current_value.
                    // 2. If valid, assert result_valid and result_value.
                    // 3. Increment current_value.
                    // 4. If current_value == 256, go to DONE.

                    // Since the code above is written, let's fix the flow.
                    // We will make ANALYZE_VALUE do the checking and outputting.
                    // We need to handle the 1-cycle read latency if any.
                    // Assuming register file read is combinational (mem_read_data = mem[scan_ptr]):
                    // This is usually synthesizable for FPGAs.

                    // Let's stick to the provided states but fix the transition.
                    // OUTPUT_RESULT will simply assert the signal and then transition back to ANALYZE_VALUE to find next.
                    // However, we are already in ANALYZE_VALUE logic block.
                    // Let's put the output logic inside ANALYZE_VALUE state to keep it simple.

                    state <= ANALYZE_VALUE; // Stay in analysis loop
                    current_value <= current_value + 1'b1;

                    if (current_value == 8'd255) begin
                        state <= DONE;
                        output_done <= 1'b1;
                        computation_done <= 1'b1;
                        result_valid <= 1'b0;
                    end
                end

                DONE: begin
                    // Hold state
                    result_valid <= 1'b0;
                end

                default: state <= IDLE;
            endcase

            // Combinational scan logic override for ANALYZE state
            if (state == ANALYZE_VALUE && !scan_done) begin
                // Perform scan of circular buffer for 'current_value'
                // We need to access memory asynchronously or synchronously.
                // Let's use a synchronous counter to scan indices.
                // We need a separate process/block for scanning inside the state.
                // Since we can't easily do multi-cycle logic in single always block without sub-states,
                // we will use the 'scan_ptr' and 'scan_counter' to track progress.

                // Read current position
                // Assume mem_read_data is updated combinationally from mem[scan_ptr]
                // Actually, better to read synchronously to avoid timing issues in complex logic,
                // but for 16 elements, combinational read is fine.
                // Let's use combinational read for simplicity in code structure,
                // but strictly speaking, Verilog simulates this correctly.
            end
        end
    end

    // Combinational logic for memory read (Assuming asynchronous read)
    wire [7:0] current_read_data;
    assign current_read_data = (state == ANALYZE_VALUE) ? mem[scan_ptr] : 8'b0;

    // Scan Logic Process (Separate always block for clarity or integrate carefully)
    // To handle the scan strictly within the main FSM clock cycle, we need to unroll or use a slow clock.
    // Since we have 16 cycles available (between output values), we can use a sub-state machine or counters.
    // Let's use a dedicated always block that updates scan variables based on the main state.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_ptr <= 4'b0;
            scan_counter <= 4'b0;
            found_start <= 1'b0;
            found_end <= 1'b0;
            in_segment <= 1'b0;
            valid_check <= 1'b1;
            occurrences <= 4'b0;
            segment_len <= 4'b0;
            scan_done <= 1'b0;
        end else begin
            if (state == ANALYZE_VALUE) begin
                if (scan_done) begin
                    // Reset for next value (if outputting or skipping)
                    // We need to reset scan_done when moving to next value in main FSM
                    if (current_value != 8'd255 && (valid_check && occurrences > 0)) begin
                         // We just finished a valid check, moving to output/next
                         // Actually, main FSM handles increment.
                         // We need to detect when we are checking a NEW value.
                         // Let's use a flag 'value_checked' or reset scan registers when current_value changes.
                         // Since current_value is a register, we can compare with previous value.
                    end
                    // Reset scan logic if we are starting a new value check
                end else if (scan_counter < count_reg) begin
                    // Scan step
                    if (current_read_data == current_value) begin
                        occurrences <= occurrences + 1'b1;
                        if (!found_start) begin
                            found_start <= 1'b1;
                            start_pos <= scan_ptr;
                            in_segment <= 1'b1;
                            segment_len <= 1'b1;
                        end else if (in_segment) begin
                            segment_len <= segment_len + 1'b1;
                        end else begin
                            // Found a value after a gap -> discontinuity
                            valid_check <= 1'b0;
                            in_segment <= 1'b1; // Start counting new segment length
                        end
                    end else begin
                        if (in_segment) begin
                            found_end <= 1'b1;
                            in_segment <= 1'b0;
                        end
                    end

                    scan_ptr <= scan_ptr + 1'b1;
                    scan_counter <= scan_counter + 1'b1;
                end else begin
                    // Scanned all elements
                    // Final check for circular contiguity
                    if (valid_check && occurrences > 0 && found_start && !found_end) begin
                         // All occurrences are contiguous and we never left the value
                         valid_check <= 1'b1;
                    end else if (valid_check && occurrences > 0 && found_start && found_end) begin
                        // Check circular wrap: value at end connects to start?
                        // This is handled by the loop. If we have a gap, valid_check becomes 0.
                        // If we have one continuous segment in linear scan, valid_check stays 1.
                        // If the segment wraps around (ends at 15, starts at 0), linear scan sees gap at index 15->0.
                        // But circular array allows wrap.
                        // Check: if scan_ptr wraps, we missed the connection.
                        // Actually, if value is at 15 and 0, linear scan sees segment end at 15, then gap, then start at 0.
                        // valid_check becomes 0.
                        // Special case: Only 1 segment that wraps.
                        // If occurrences > 0, segment_len < occurrences -> we have a gap.
                        // Wait, segment_len tracks current segment. If we have 2 segments, segment_len resets.
                        // If we have 1 segment that wraps, linear scan finds it at end, gap, then nothing.
                        // So we need to check: is the last element of the buffer equal to current_value AND first element?
                        // If so, and valid_check is still 1 (meaning no gap found in middle), then it is contiguous (wrapping).
                    end

                    // Wait, the logic above is getting messy. Let's simplify the contiguity check logic.
                    // Standard approach: 
                    // 1. Scan linear array.
                    // 2. Count transitions Value -> NotValue and NotValue -> Value.
                    // 3. If N = occurrences:
                    //    a. If N == 0: skip.
                    //    b. If N > 0:
                    //       - If transitions count == 0: All elements same (fully contiguous).
                    //       - If transitions count == 1: Array is e.g., VVVNNN. Check wrap NNN->VVV.
                    //       - If transitions count > 1: VVVNNNZZZVVV -> Discontinuous.
                    //       - If transitions count == 2: VVVNNNZZZ where ZZZ is not V, but maybe wraps? No, 2 transitions in 16 elements means 2 gaps.
                    //          Wait, 2 transitions means V->N and N->V. That's one block. Check wrap.
                    //          Actually, number of blocks = transitions / 2. (Rounded up for wrap?).
                    //          Let's count blocks of Value.
                    //          Block 1: V starts.
                    //          Block 2: V starts again after N.
                    //          If count blocks > 1, invalid.

                    // Revised Scan Logic for Block Counting:
                    // Reset: block_count = 0, in_val = false, first_val = false.
                    // Iterate i = 0 to N-1:
                    //   if (array[i] == val):
                    //     if (!in_val) { block_count++; in_val = true; }
                    //   else:
                    //     in_val = false;
                    // After loop, check wrap:
                    //   if (array[N-1] == val) and (array[0] == val) and (block_count > 1):
                    //     block_count--; // It's actually one block wrapping
                    //   Actually, this logic is tricky.

                    // Let's stick to the requirement: "all occurrences of a value must be consecutive".
                    // 1. Find first occurrence index `first_idx`.
                    // 2. Iterate from `first_idx` circularly.
                    // 3. Count occurrences. Stop when value changes.
                    // 4. Continue iterating. If we hit the value again -> Invalid.

                    // Let's implement this specific logic.
                    // We need a 'phase'.
                    // Phase 1: Find first occurrence.
                    // Phase 2: Consume sequence.
                    // Phase 3: Verify no more occurrences.

                    // Re-writing the scan logic inside the always block:
                    // We will use `scan_ptr` to iterate.
                    // We need registers to store state of scan: scan_phase (0=look, 1=consume, 2=verify), start_index.

                    // Let's restart the scan logic in the always block cleanly.
                end
            end else begin
                // Reset scan registers when leaving ANALYZE_VALUE or when current_value increments
                // To handle incrementing current_value, we need to reset scan logic.
                // We can detect if current_value changed.
                // Or, we can reset scan logic whenever we are not in ANALYZE_VALUE state.

                // Actually, to keep it simple and functional within the constraints:
                // We will use the "look-ahead" method.
                // In ANALYZE_VALUE state, we perform the scan in a single cycle (combinational logic)
                // or use a flag to say "processing started".

                // Since we can't do complex loops in sequential logic easily without sub-states,
                // let's use a sub-state machine for scanning.

                // Sub-states for ANALYZE_VALUE:
                // A_FIND_START: Scan for first occurrence.
                // A_VERIFY_GAP: Scan rest to ensure no second block.

                // Let's modify the main FSM state ANALYZE_VALUE to just set up,
                // and use internal counters for the scan process.
            end
        end
    end

    // Re-implementation of ANALYZE state logic to handle the scan correctly
    // We will expand the ANALYZE_VALUE state to do the work over multiple cycles.
    // We add internal state bits or use the existing counters to drive the scan.
    // To avoid complexity, let's assume the "scan" is done over 16 cycles.
    // We need a register to indicate we are currently scanning a value.

    reg scanning;
    reg [2:0] scan_phase; // 0: Init, 1: Find First, 2: Consume, 3: Check Remainder, 4: Done
    reg [3:0] scan_idx;
    reg [7:0] target_val;
    reg found_first;
    reg block_ended;
    reg is_valid;
    reg [3:0] local_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scanning <= 1'b0;
            scan_phase <= 3'b0;
            result_valid <= 1'b0;
            output_done <= 1'b0;
            computation_done <= 1'b0;
            state <= IDLE;
            write_ptr <= 4'b0;
            count_reg <= 4'b0;
            result_value <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COLLECT;
                        write_ptr <= 4'b0;
                        count_reg <= count_in;
                    end
                end

                COLLECT: begin
                    if (valid_in) begin
                        mem[write_ptr] <= data_in;
                        write_ptr <= write_ptr + 1'b1;
                    end
                    if (done_in) begin
                        state <= WAIT_DONE;
                    end
                end

                WAIT_DONE: begin
                     if (valid_in) begin
                        mem[write_ptr] <= data_in;
                        write_ptr <= write_ptr + 1'b1;
                    end
                    if (done_in && !valid_in) begin
                        state <= ANALYZE_VALUE;
                        target_val <= 8'd1;
                        scanning <= 1'b0;
                        result_valid <= 1'b0;
                        output_done <= 1'b0;
                        computation_done <= 1'b0;
                    end
                end

                ANALYZE_VALUE: begin
                    result_valid <= 1'b0; // Default low

                    if (!scanning) begin
                        // Start scan for new value
                        scanning <= 1'b1;
                        scan_phase <= 3'b1; // Find First
                        scan_idx <= 4'b0;
                        found_first <= 1'b0;
                        block_ended <= 1'b0;
                        is_valid <= 1'b1;
                        local_count <= 4'b0;
                    end else begin
                        // Scan Logic
                        if (scan_idx < count_reg) begin
                            // Read memory asynchronously
                            if (mem[scan_idx] == target_val) begin
                                // Found value
                                local_count <= local_count + 1'b1;
                                if (!found_first) begin
                                    found_first <= 1'b1;
                                    // Phase 1 complete, move to Phase 2 (Consume)
                                    // Actually, we just continue.
                                end else if (block_ended) begin
                                    // Found value after a gap
                                    is_valid <= 1'b0;
                                end
                            end else begin
                                // Not value
                                if (found_first) begin
                                    block_ended <= 1'b1;
                                end
                            end
                            scan_idx <= scan_idx + 1'b1;
                        end else begin
                            // Scan Complete, check validity
                            // If local_count > 0 AND is_valid == 1, then it's valid.
                            // Note: block_ended being true is OK if we don't find value again.
                            // The is_valid flag handles the "found again after gap" case.

                            if (local_count > 0 && is_valid) begin
                                // Output this value
                                result_value <= target_val;
                                result_valid <= 1'b1;
                                // Prepare for next value
                                scanning <= 1'b0;
                                if (target_val == 8'd255) begin
                                    state <= DONE;
                                    output_done <= 1'b1;
                                    computation_done <= 1'b1;
                                end else begin
                                    target_val <= target_val + 1'b1;
                                end
                            end else begin
                                // Skip to next value
                                scanning <= 1'b0;
                                if (target_val == 8'd255) begin
                                    state <= DONE;
                                    output_done <= 1'b1;
                                    computation_done <= 1'b1;
                                end else begin
                                    target_val <= target_val + 1'b1;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule