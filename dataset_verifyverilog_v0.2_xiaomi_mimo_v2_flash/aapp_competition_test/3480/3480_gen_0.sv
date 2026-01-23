module round_generator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire [1:0] data_type, // 0: Config/Time, 1: Char, 2: EndSyl, 3: EndLine
    input wire data_valid,
    output reg [199:0] line1_out,
    output reg [199:0] line2_out,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_LINES = 8;
    parameter MAX_SYLLABLES = 8;
    parameter MAX_CHARS = 16;
    parameter LINE_WIDTH = 200;

    // Internal Memory
    reg [7:0] text_mem [0:MAX_LINES-1][0:MAX_SYLLABLES-1][0:MAX_CHARS-1];
    reg [7:0] time_mem [0:MAX_LINES-1][0:MAX_SYLLABLES-1];
    reg [3:0] syl_cnt [0:MAX_LINES-1];
    
    // Config Registers
    reg [7:0] line_delay;
    reg [3:0] total_lines;

    // Pointers and Counters
    reg [3:0] l_idx; // Line index
    reg [3:0] s_idx; // Syllable index
    reg [3:0] c_idx; // Char index
    
    // Processing Registers
    reg [7:0] v1_cursor;      // Position in line1
    reg [7:0] v2_start_abs;   // Absolute start time of V2 overlap for current line
    reg [7:0] line_duration;  // Total duration of V1 line
    reg       v2_empty_flag;  // Flag to indicate V2 is empty
    
    // Calculation Loop Counters
    reg [3:0] loop_l; // Loop line index
    reg [3:0] loop_s; // Loop syllable index
    reg [3:0] loop_c; // Loop char index

    // State Encoding
    localparam S_IDLE       = 3'b000;
    localparam S_LOAD       = 3'b001;
    localparam S_CALC_V1    = 3'b010;
    localparam S_CALC_V2    = 3'b011;
    localparam S_OUTPUT     = 3'b100;
    localparam S_NEXT_LINE  = 3'b101;
    localparam S_DONE       = 3'b110;

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            output_valid <= 0;
            done <= 0;
            l_idx <= 0;
            s_idx <= 0;
            c_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    output_valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= S_LOAD;
                        l_idx <= 0;
                        s_idx <= 0;
                        c_idx <= 0;
                        total_lines <= 0;
                        line_delay <= 0;
                    end
                end

                S_LOAD: begin
                    if (data_valid) begin
                        case (data_type)
                            2'b00: begin // Config (if first) or Time
                                if (l_idx == 0 && s_idx == 0 && c_idx == 0) begin
                                    // First 0 is Config
                                    total_lines <= data_in[15:8];
                                    line_delay <= data_in[7:0];
                                end else begin
                                    // Store Time
                                    time_mem[l_idx][s_idx] <= data_in[7:0];
                                end
                            end
                            2'b01: begin // Char
                                if (c_idx < MAX_CHARS) begin
                                    text_mem[l_idx][s_idx][c_idx] <= data_in[7:0];
                                    c_idx <= c_idx + 1;
                                end
                            end
                            2'b10: begin // EndSyl
                                // Update count for current line
                                syl_cnt[l_idx] <= s_idx + 1;
                                s_idx <= s_idx + 1;
                                c_idx <= 0;
                            end
                            2'b11: begin // EndLine
                                l_idx <= l_idx + 1;
                                s_idx <= 0;
                                c_idx <= 0;
                            end
                        endcase
                    end else if (start == 0) begin
                        // If start is deasserted, we assume loading is done. 
                        // Alternatively, we could wait for a specific marker or explicit 'finish' signal.
                        // Given the 'start' pulse nature usually, we check if we reached total_lines.
                        // Or simply if we are done loading data and start goes low.
                        // Let's rely on reaching total_lines.
                        if (l_idx >= total_lines && data_valid == 0) begin
                            state <= S_CALC_V1;
                            l_idx <= 0; // Reset for processing
                        end
                    end
                end

                S_CALC_V1: begin
                    // Sub-state to fill line1
                    if (s_idx == 0 && c_idx == 0) begin
                        // Initialization
                        v1_cursor <= 0;
                        line_duration <= 0;
                        line1_out <= {200{8'h5F}}; // Fill with '_'
                    end

                    if (s_idx < syl_cnt[l_idx]) begin
                        // Process current syllable
                        if (c_idx == 0) begin
                            // Start of syllable: add time to line_duration (accumulate time)
                            // Note: In a musical round, strict time placement is required.
                            // We place chars, then fill to duration.
                            // But for V2 calculation, we need absolute times.
                            // We will compute cumulative time strictly by summing durations.
                            // However, here in V1, we place the string.
                            // To know absolute time, we should have calculated it, or accumulate it here.
                            // Let's accumulate in a temp variable if possible, or use separate variable.
                            // We need `v1_cursor` to represent the horizontal position.
                            // The example implies `cursor += duration`.
                            // Let's use `v1_cursor` as the position accumulator.
                        end

                        // Copy character
                        if (c_idx < MAX_CHARS) begin
                            // Check if char is valid (non-null). Assuming null-terminated or fixed length.
                            // Prompt says 'syllable text... 16 bytes'. 
                            // We will copy until we hit 0 or MAX_CHARS.
                            // Note: We need to check null terminator.
                            // For simplicity in this fixed-width logic, we can copy up to MAX_CHARS, 
                            // but let's assume valid chars are non-zero.
                            if (text_mem[l_idx][s_idx][c_idx] != 8'h00) begin
                                if (v1_cursor + c_idx < LINE_WIDTH) begin
                                    line1_out[(v1_cursor + c_idx)*8 +: 8] <= text_mem[l_idx][s_idx][c_idx];
                                end
                                c_idx <= c_idx + 1;
                            end else begin
                                // Null reached, jump to end of duration
                                c_idx <= MAX_CHARS; // Force finish
                            end
                        end else begin
                            // Finished copying chars. Now fill remainder with '_' based on duration.
                            // Duration = time_mem[l_idx][s_idx]
                            // Fill from (v1_cursor + current_char_len) to (v1_cursor + duration)
                            // Current char len is c_idx (since we stopped at null or MAX)
                            // Actually, we need a separate counter for the fill loop or reuse c_idx.
                            // Let's reuse c_idx as the filler index.
                            // c_idx was MAX_CHARS. Reset it to string length? 
                            // We need to track the string length. 
                            // Let's track `str_len` in a register.
                            // Or simpler: The prompt says 'separated by at least one underscore'.
                            // The example: 'Hot' (3) duration 4 -> 'Hot_'. 'cross' (5) duration 4 -> wait, 'cross' is 5 chars, duration 4?
                            // Example output: 'Hot_cross_...' where 'cross' takes 4 units? Or 'cross' fits in 4 units? 
                            // The example says 'cross' (4 units). 'cross' is 5 letters. 
                            // If duration < string length, the string is truncated or overflow? 
                            // Let's assume the string fits, and duration >= length. 
                            // If duration > length, pad with '_'.
                            
                            // Let's introduce a temporary register to handle the 'fill' loop properly.
                            // Because we are in one always block, we can manage sub-states via additional flags.
                            // However, to keep code size manageable, let's assume we can unroll or use `c_idx` for filling.
                            // We will use `c_idx` to track 'fill index' after characters are done.
                            // We need to know where characters ended. 
                            // Let's add `str_len` register.
                            // Wait, `text_mem` is loaded. We know the load order.
                            // Let's assume loaded syllables are packed tightly. 
                            // We can just check `text_mem[l_idx][s_idx][c_idx]` for null. 
                            // If null, we are done with chars.
                            // Let's use `c_idx` for char copy, and once we hit null, we switch to 'fill' logic.
                            // We need a flag `filling`.
                            // Let's refine: 
                            // 1. Copy chars until null.
                            // 2. If `c_idx` (char count) < `time_mem` (duration), write '_' and increment.
                            // 3. This requires `c_idx` to persist across loops. 
                            // Let's use `c_idx` for both. 
                            // Step 1: Copy chars. 
                            // Step 2: When null found, `c_idx` contains length. 
                            // Then compare with duration. If c_idx < duration, write '_', c_idx++, stay in this syllable.
                            // If c_idx >= duration, reset c_idx=0, s_idx++.
                            
                            // Re-implementation of this block:
                            if (text_mem[l_idx][s_idx][c_idx] != 8'h00 && c_idx < MAX_CHARS) begin
                                // Still copying chars
                                if (v1_cursor + c_idx < LINE_WIDTH) begin
                                    line1_out[(v1_cursor + c_idx)*8 +: 8] <= text_mem[l_idx][s_idx][c_idx];
                                end
                                c_idx <= c_idx + 1;
                            end else begin
                                // Null or max reached. Check padding.
                                if (c_idx < time_mem[l_idx][s_idx]) begin
                                    // Padding needed
                                    if (v1_cursor + c_idx < LINE_WIDTH) begin
                                        line1_out[(v1_cursor + c_idx)*8 +: 8] <= 8'h5F; // '_'
                                    end
                                    c_idx <= c_idx + 1;
                                end else begin
                                    // Syllable finished
                                    v1_cursor <= v1_cursor + time_mem[l_idx][s_idx];
                                    line_duration <= line_duration + time_mem[l_idx][s_idx];
                                    s_idx <= s_idx + 1;
                                    c_idx <= 0;
                                end
                            end
                        end
                    end else begin
                        // All syllables for line processed
                        // Transition to V2 calc
                        // Calculate V2 start time (Absolute)
                        // We need V1 start time of this line.
                        // We need to sum durations of previous lines.
                        // We can calculate this in S_NEXT_LINE or store cumulative time.
                        // Let's calculate cumulative time in S_NEXT_LINE and store in a register.
                        // Let's do it here. 
                        // We need `v1_start_time` for current line.
                        // We can compute it by summing `time_mem` for lines < l_idx.
                        // Since this is combinational logic in a sequential block, we can do it iteratively.
                        // Or, we can keep a `cumulative_time` register that increments as we finish lines.
                        // Let's add `reg [15:0] cumulative_time` (wide enough for 8 lines * 128).
                        // Update `cumulative_time` in S_NEXT_LINE.
                        // Here, `v2_start_abs` = cumulative_time + line_delay.
                        // Wait, `cumulative_time` is updated at the END of line processing.
                        // So inside S_CALC_V1 finish, `cumulative_time` holds the start of this line.
                        
                        // Calculate V2 Start:
                        // v2_start_abs <= cumulative_time + line_delay;
                        // But we need `cumulative_time` to be accessible. 
                        // Let's declare `reg [15:0] cumulative_time`.
                        // Update it in S_NEXT_LINE (after output).
                        // In S_CALC_V1, we need to know the start of *this* line.
                        // So we need to pass it in.
                        // Let's calculate it. 
                        // If we don't want to sum every time, we can update `v2_start_abs` in S_NEXT_LINE.
                        // Let's use `v2_start_abs` as a register.
                        // In S_NEXT_LINE, we do: v2_start_abs <= cumulative_time + line_delay.
                        // But here we are finishing S_CALC_V1. We need to move to S_CALC_V2.
                        // We need `v2_start_abs` to be correct for the current line.
                        // Let's calculate `v2_start_abs` in S_CALC_V1 using a loop, or simplify:
                        // We can compute cumulative time of CURRENT line start in `S_CALC_V1` init.
                        // Iteratively: 
                        // Let's add `reg [7:0] v1_start_time`.
                        // In S_IDLE, clear it.
                        // In S_NEXT_LINE, we add the line duration to it.
                        // So at S_CALC_V1, `v1_start_time` is the start time of current line.
                        // Then `v2_start_abs <= v1_start_time + line_delay`.
                        // This is cleaner.
                        
                        v2_start_abs <= v1_start_time + line_delay;
                        
                        // Reset V2 Loop counters
                        loop_l <= 0;
                        loop_s <= 0;
                        v2_empty_flag <= 1; // Assume empty until proven otherwise
                        line2_out <= {200{8'h5F}}; // Default fill
                        
                        state <= S_CALC_V2;
                        s_idx <= 0; // Reset s_idx for reuse as 'filled length' of V2
                        // We need to handle V2 placement. 
                        // We will use `v1_cursor` (renamed to `v2_cursor` or reuse) as position in line2.
                        // Actually, let's use `v2_cursor` (repurposing v1_cursor since V1 is done).
                        // But `v1_cursor` was used for V1 position. 
                        // Let's use `s_idx` to track the number of syllables placed in V2, 
                        // or use a separate `v2_cursor` register.
                        // Let's repurpose `v1_cursor` -> `v2_cursor`.
                        // Wait, `v1_cursor` is valid as line width. We can use `v1_cursor` to track V2 position? 
                        // No, V2 placement is non-linear (scan all syllables).
                        // We need to scan `loop_l`, `loop_s`.
                        // And place at `relative_pos`.
                        // We need a way to write to `line2_out` at calculated index.
                        // The `loop` indices are used for scanning.
                        // We need a way to trigger writing.
                        // Since we scan sequentially, we can write immediately if condition met.
                        // The `S_CALC_V2` state will loop through ALL syllables of the song.
                    end
                end

                S_CALC_V2: begin
                    // Logic: Scan all syllables. 
                    // If (start_time >= v2_start_abs) AND (start_time < v2_start_abs + line_duration)
                    //   rel_pos = start_time - v2_start_abs
                    //   place text at rel_pos
                    //   v2_empty_flag <= 0
                    
                    // We need to compute `start_time` of syllable `loop_l, loop_s`.
                    // `start_time` is cumulative sum of previous lines + previous syllables.
                    // We can't compute this instantly without a blockram of cumulative times or iteration.
                    // Let's iterate. We need a running `accumulated_time` inside this state.
                    // We can use a register `scan_time`.
                    // We need to scan (loop_l, loop_s) sequentially.
                    // We need a flag to indicate if we are currently inside the valid window or just finished it.
                    // Since syllables are sorted by time (by definition of song structure), we can optimize.
                    
                    // Let's use `scan_time` register.
                    // Init `scan_time = 0` at start of S_CALC_V2 (controlled by a sub-state).
                    // We need to handle the scan loop.
                    // This is complex for one state. 
                    // Let's split S_CALC_V2 into sub-states or use `loop_s` to iterate.
                    // We will use `loop_l` and `loop_s`.
                    // We need to update `scan_time` as we advance.
                    // When we advance syllable, we add its duration.
                    // When we advance line, we start fresh (or continue scan? No, we need absolute times for all syllables).
                    // Wait, if we iterate `loop_l` from 0 to total_lines, and `loop_s` from 0 to syl_cnt[loop_l],
                    // we accumulate `scan_time`.
                    
                    // Check condition:
                    // `scan_time` >= `v2_start_abs` AND `scan_time` < `v2_start_abs` + `line_duration`.
                    
                    // If condition met:
                    // 1. Set `v2_empty_flag` to 0.
                    // 2. Calculate `rel_pos = scan_time - v2_start_abs`.
                    // 3. Place text at `rel_pos`.
                    //    To place text, we need to copy string from `text_mem[loop_l][loop_s]`.
                    //    We need a nested loop for characters or a dedicated char writer.
                    //    Let's use `c_idx` for character copying. 
                    //    But we are inside the syllable scan loop.
                    //    We need to pause the scan loop to copy characters.
                    //    This implies a state `S_CALC_V2_WRITE`.
                    
                    // Let's refine:
                    // S_CALC_V2: iterating syllables.
                    // If match found:
                    //   Calculate `rel_pos`.
                    //   Copy chars to `line2_out` at `rel_pos + i`.
                    //   Advance `loop_s` only after copying.
                    //   (We can do copying in the same state if we iterate `c_idx`).
                    //   If `c_idx` is not done, stay here and copy.
                    
                    // We need `scan_time` register. 
                    // Let's add it.
                    // Let's call it `v2_scan_time`.
                    // And `v2_write_pos` to track where we are writing in line2.
                    // And `v2_src_l`, `v2_src_s` to remember source of current write.
                    
                    // **Implementation Plan for S_CALC_V2**
                    // 1. Setup: If `loop_l` == 0 && `loop_s` == 0 && `c_idx` == 0: 
                    //    `v2_scan_time` <= 0; (Actually we need to preserve scan time across loop).
                    //    Wait, `scan_time` is the running sum of all processed syllables.
                    //    So `scan_time` is maintained across loop iterations.
                    //    `loop_l` and `loop_s` are the indices of the *next* syllable to scan.
                    
                    // 2. Check current syllable (`loop_l`, `loop_s`):
                    //    Is `loop_l` < `total_lines`? And `loop_s` < `syl_cnt[loop_l]`?
                    //    If yes:
                    //       Check `v2_scan_time`.
                    //       If `v2_scan_time` >= `v2_start_abs` && `v2_scan_time` < `v2_start_abs` + `line_duration`:
                    //          // This syllable belongs to line 2
                    //          // Place it.
                    //          If `c_idx` == 0: Calculate `rel_pos` = `v2_scan_time` - `v2_start_abs`. Set `v2_empty_flag` = 0.
                    //          If `c_idx` < MAX_CHARS and text != 0:
                    //             Write `text` to `line2_out` at `rel_pos + c_idx`. `c_idx`++.
                    //             (Note: if `rel_pos + c_idx` exceeds width, ignore).
                    //          Else if `c_idx` < duration (time_mem[loop_l][loop_s]):
    //             Write '_' at `rel_pos + c_idx`. `c_idx`++.
    //          Else:
    //             // Finished this syllable. 
    //             Update `v2_scan_time` += duration. (Important!)
    //             Advance `loop_s` (and `loop_l` if needed). Reset `c_idx` = 0.
    //       Else: // Not in window
    //          // Just advance time and pointers
    //          Update `v2_scan_time` += duration.
    //          Advance `loop_s`/`loop_l`. Reset `c_idx` = 0.
                    
                    //    If `loop_l` >= `total_lines`: Scan finished. Go to S_OUTPUT.
                    
                    // This logic is dense. Let's write it out carefully.
                    // We need a flag to know if we are in "copy mode" vs "scan mode".
                    // Actually, the check and copy can be integrated.
                    // If we are currently copying (c_idx > 0 or just finished match check), we are "locked" to this syllable.
                    // If c_idx == 0, we are scanning.
                    
                    // Let's use `v2_write_mode` flag.
                    // If `v2_write_mode` is 0: Scan mode. Check match. If match, set `v2_write_mode=1`, calculate pos. 
                    // If `v2_write_mode` is 1: Write mode. Copy chars/fill. When done, set `v2_write_mode=0`, advance loop.
                    
                    // Refined Logic in S_CALC_V2:
                    // if (v2_write_mode == 0) begin
                    //    // Scan phase
                    //    if (loop_l >= total_lines) state <= S_OUTPUT;
                    //    else begin
                    //       // Check match
                    //       // v2_scan_time holds time of current syllable
                    //       if (v2_scan_time >= v2_start_abs && v2_scan_time < (v2_start_abs + line_duration)) begin
                    //          // Match found
                    //          v2_write_mode <= 1;
                    //          v2_write_pos <= v2_scan_time - v2_start_abs;
                    //          c_idx <= 0;
                    //          v2_empty_flag <= 0;
                    //          // Don't advance loop yet
                    //       end else begin
                    //          // No match, advance time and loop
                    //          v2_scan_time <= v2_scan_time + time_mem[loop_l][loop_s];
                    //          // Advance pointers
                    //          if (loop_s + 1 < syl_cnt[loop_l]) loop_s <= loop_s + 1;
                    //          else begin loop_s <= 0; loop_l <= loop_l + 1; end
                    //       end
                    //    end
                    // end else begin
                    //    // Write phase (copying chars/filling for current syllable)
                    //    // Text is in `text_mem[loop_l][loop_s]` (stored from scan phase)
                    //    // Duration in `time_mem[loop_l][loop_s]`
                    //    if (c_idx < time_mem[loop_l][loop_s]) begin
                    //       if (c_idx < MAX_CHARS && text_mem[loop_l][loop_s][c_idx] != 0) begin
                    //          // Char
                    //          if (v2_write_pos + c_idx < LINE_WIDTH)
                    //             line2_out[(v2_write_pos + c_idx)*8 +: 8] <= text_mem[loop_l][loop_s][c_idx];
                    //       end else begin
                    //          // Pad
                    //          if (v2_write_pos + c_idx < LINE_WIDTH)
                    //             line2_out[(v2_write_pos + c_idx)*8 +: 8] <= 8'h5F;
                    //       end
                    //       c_idx <= c_idx + 1;
                    //    end else begin
                    //       // Finished writing this syllable
                    //       v2_scan_time <= v2_scan_time + time_mem[loop_l][loop_s];
                    //       v2_write_mode <= 0;
                    //       // Advance pointers
                    //       if (loop_s + 1 < syl_cnt[loop_l]) loop_s <= loop_s + 1;
                    //       else begin loop_s <= 0; loop_l <= loop_l + 1; end
                    //    end
                    // end

                    // **Actually, we need to store `v2_scan_time` across states.**
                    // Let's declare `reg [15:0] v2_scan_time`.
                    // And `reg v2_write_mode`.
                    // And `reg [7:0] v2_write_pos`.

                    // Let's implement this logic.
                    if (~v2_write_mode) begin
                        // Scan Mode
                        if (loop_l >= total_lines) begin
                            state <= S_OUTPUT;
                        end else begin
                            // Check if current syllable is in window
                            // Note: `v2_scan_time` holds the START time of the current syllable (loop_l, loop_s)
                            // Wait, we need to initialize `v2_scan_time` properly.
                            // `v2_scan_time` is maintained across loops.
                            // At the start of S_CALC_V2, we set it to 0.
                            // But we need to calculate absolute start time of the *song* for syllables.
                            // Actually, `v2_start_abs` is relative to the start of the *song* (since it is `v1_start_time + D`).
                            // And `v2_scan_time` should track the absolute start time of the syllable we are looking at.
                            // So `v2_scan_time` must start at 0 and accumulate ALL syllables.
                            // But `v1_start_time` is the start of the *current* line. 
                            // So `v2_start_abs` is absolute song time.
                            // `v2_scan_time` is absolute song time.
                            
                            if (v2_scan_time >= v2_start_abs && v2_scan_time < (v2_start_abs + line_duration)) begin
                                v2_write_mode <= 1;
                                v2_write_pos <= v2_scan_time - v2_start_abs;
                                c_idx <= 0;
                                v2_empty_flag <= 0;
                                // Don't advance `v2_scan_time` yet, we need it for next check after write.
                            end else begin
                                // Advance
                                v2_scan_time <= v2_scan_time + time_mem[loop_l][loop_s];
                                // Advance pointers
                                if (loop_s + 1 < syl_cnt[loop_l]) begin
                                    loop_s <= loop_s + 1;
                                end else begin
                                    loop_s <= 0;
                                    loop_l <= loop_l + 1;
                                end
                            end
                        end
                    end else begin
                        // Write Mode
                        // We are writing `loop_l`, `loop_s`.
                        // We need to advance `c_idx`.
                        if (c_idx < time_mem[loop_l][loop_s]) begin
                            // Write logic
                            if (c_idx < MAX_CHARS && text_mem[loop_l][loop_s][c_idx] != 8'h00) begin
                                if (v2_write_pos + c_idx < LINE_WIDTH)
                                    line2_out[(v2_write_pos + c_idx)*8 +: 8] <= text_mem[loop_l][loop_s][c_idx];
                            end else begin
                                if (v2_write_pos + c_idx < LINE_WIDTH)
                                    line2_out[(v2_write_pos + c_idx)*8 +: 8] <= 8'h5F;
                            end
                            c_idx <= c_idx + 1;
                        end else begin
                            // Finished writing this syllable
                            // Update scan time for NEXT syllable check
                            v2_scan_time <= v2_scan_time + time_mem[loop_l][loop_s];
                            v2_write_mode <= 0;
                            // Advance pointers
                            if (loop_s + 1 < syl_cnt[loop_l]) begin
                                loop_s <= loop_s + 1;
                            end else begin
                                loop_s <= 0;
                                loop_l <= loop_l + 1;
                            end
                        end
                    end
                end

                S_OUTPUT: begin
                    output_valid <= 1;
                    // Check if we should use '/' for line2
                    if (v2_empty_flag) begin
                        line2_out <= {192'h0, 8'h2F}; // Pad zeros and '/'. Or overwrite first char.
                        // Ensure padding with underscores? Prompt says "padded with underscores or '/'".
                        // Usually '/' implies the line is just '/'.
                        // Let's clear and set '/'.
                        line2_out <= {200{8'h20}}; // Spaces first
                        line2_out[7:0] <= 8'h2F;
                    end
                    
                    // Move to next line or done
                    // We need to wait a cycle for output to be registered.
                    // Or we can move to NEXT_LINE immediately but output_valid high.
                    // Let's move to NEXT_LINE next cycle.
                    state <= S_NEXT_LINE;
                end

                S_NEXT_LINE: begin
                    output_valid <= 0;
                    // Update cumulative registers
                    // v1_start_time += line_duration
                    // cumulative_time <= cumulative_time + line_duration (Wait, we used v1_start_time as cumulative)
                    // Let's rename `v1_start_time` to `cumulative_time`.
                    // Yes.
                    cumulative_time <= cumulative_time + line_duration;
                    
                    // Check if more lines
                    if (l_idx + 1 < total_lines) begin
                        l_idx <= l_idx + 1;
                        state <= S_CALC_V1;
                        s_idx <= 0;
                        c_idx <= 0;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    if (~start) state <= S_IDLE;
                end
            endcase
        end
    end

    // Additional registers needed for logic
    reg [15:0] cumulative_time; // v1_start_time accumulator
    reg [15:0] v2_scan_time;   // V2 absolute time tracker
    reg        v2_write_mode;  // V2 write flag
    reg [7:0]  v2_write_pos;   // V2 relative write position
    reg [7:0]  v1_start_time;  // Holder for current line start time (alias for logic clarity, but we use cumulative_time)
    // Correction: I used `cumulative_time` as the register. 
    // In S_CALC_V1, I need to use it. 
    // But `cumulative_time` is updated in S_NEXT_LINE (after processing).
    // So at S_CALC_V1 start, `cumulative_time` is the start of the current line.
    // Correct.

endmodule