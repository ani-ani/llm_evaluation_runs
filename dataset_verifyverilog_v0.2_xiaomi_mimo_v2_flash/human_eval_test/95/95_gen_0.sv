module check_dict_case (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_entries,
    input [63:0] key_0,
    input [63:0] key_1,
    input [63:0] key_2,
    input [63:0] key_3,
    input [63:0] key_4,
    input [63:0] key_5,
    input [63:0] key_6,
    input [63:0] key_7,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE         = 3'b000;
    localparam CHECK_EMPTY  = 3'b001;
    localparam PROCESS_KEYS = 3'b010;
    localparam VALIDATE_CASE= 3'b011;
    localparam DONE         = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [7:0] valid_entries_reg;  // Store mask
    reg [2:0] entry_idx;          // Current entry index (0-7)
    reg [2:0] char_idx;           // Current character index (0-7)
    
    // Case Tracking: 0=Unknown, 1=Lower, 2=Upper
    reg [1:0] current_case;
    reg [1:0] detected_case;
    
    reg error_flag;               // Set high on invalid char or mixed case
    reg is_empty;                 // Set high if no valid entries
    reg [63:0] current_key;       // Latched key for current entry
    reg entry_valid_flag;         // Flag if current entry is valid
    
    // Key selection logic (combinational)
    wire [63:0] selected_key;
    assign selected_key = (key_0) & {64{valid_entries_reg[0] & (entry_idx == 3'd0)}} | 
                          (key_1) & {64{valid_entries_reg[1] & (entry_idx == 3'd1)}} |
                          (key_2) & {64{valid_entries_reg[2] & (entry_idx == 3'd2)}} |
                          (key_3) & {64{valid_entries_reg[3] & (entry_idx == 3'd3)}} |
                          (key_4) & {64{valid_entries_reg[4] & (entry_idx == 3'd4)}} |
                          (key_5) & {64{valid_entries_reg[5] & (entry_idx == 3'd5)}} |
                          (key_6) & {64{valid_entries_reg[6] & (entry_idx == 3'd6)}} |
                          (key_7) & {64{valid_entries_reg[7] & (entry_idx == 3'd7)}};

    // Sequential Logic for State and Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            entry_idx <= 3'b0;
            char_idx <= 3'b0;
            current_case <= 2'b0;
            detected_case <= 2'b0;
            error_flag <= 1'b0;
            is_empty <= 1'b0;
            valid_entries_reg <= 8'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        valid_entries_reg <= valid_entries;
                        entry_idx <= 3'b0;
                        char_idx <= 3'b0;
                        current_case <= 2'b0;
                        detected_case <= 2'b0;
                        error_flag <= 1'b0;
                        is_empty <= 1'b0;
                        done <= 1'b0;
                        result <= 1'b0;
                    end
                end

                CHECK_EMPTY: begin
                    // Check if mask is all zero
                    if (valid_entries_reg == 8'b0) begin
                        is_empty <= 1'b1;
                    end else begin
                        is_empty <= 1'b0;
                        // Initialize for processing
                        entry_idx <= 3'b0;
                        char_idx <= 3'b0;
                        // Find first valid entry to latch key immediately or in next state
                        // We rely on PROCESS_KEYS logic to find first valid
                    end
                end

                PROCESS_KEYS: begin
                    // Character iteration logic
                    // Check current character of current_key
                    if (entry_valid_flag) begin
                        // Check character at char_idx (MSB first in char 0)
                        // Byte index is [63:56] for char 0, [55:48] for char 1, ..., [7:0] for char 7
                        // Shift right by (7-char_idx)*8
                        // Actually, let's just map char_idx to byte lane
                        // char 0 -> [63:56], char 1 -> [55:48], char 2 -> [47:40], char 3 -> [39:32]
                        // char 4 -> [31:24], char 5 -> [23:16], char 6 -> [15:8], char 7 -> [7:0]
                        
                        // Let's use a helper wire for the byte to avoid complex shifting in combinational logic inside the block
                        // We handle the byte extraction in the combinational block below or here.
                        // Doing combinational check below is cleaner.
                    end
                    
                    // Increment logic handled in combinational block or here? 
                    // Let's use combinational block for control signals.
                    // But we need to update char/entry index here.
                    
                    if (entry_valid_flag) begin
                        // If valid, check char, update flags, then increment
                        // We need to check the byte. 
                        // Let's perform check here via a combinational `if` on the byte value.
                        // But `current_key` is registered. We need the specific byte.
                        
                        // To avoid timing loops, we update indices based on current state and flags.
                        // The byte value check must happen within this cycle to update error_flag.
                        
                        // Let's assume the combinational logic updates `char_error`.
                        // Here we just manage flow.
                        
                        // Increment Char
                        if (char_idx < 7) begin
                            char_idx <= char_idx + 1;
                        end else begin
                            // End of key, move to next entry
                            char_idx <= 0;
                            // Find next valid entry
                            entry_idx <= entry_idx + 1;
                            // Check if we need to latch the new key? 
                            // `selected_key` is combinational based on entry_idx.
                            // We latch `current_key` when we start a valid entry.
                        end
                    end else begin
                        // Skip invalid entry
                        entry_idx <= entry_idx + 1;
                        if (entry_idx == 7) begin
                            // Done iterating entries
                            // This transition happens in Next State logic
current_case <= current_case; // keep value
                        end
                    end
                    
                    // Track Case Logic (Update detected_case)
                    // We do this in the combinational block triggering state transitions, 
                    // but we need to register the detected case type if it's the first one.
                    if (entry_valid_flag && !error_flag && (current_case == 2'b0)) begin
                        // If this is the first valid character of the first valid key (or subsequent keys if no case set yet?)
                        // Logic: We set `detected_case` once we hit the first alpha char of the first valid key.
                        // Or we can set `detected_case` in VALIDATE_CASE? No, we check during process.
                        
                        // Let's refine: 
                        // 1. Read byte.
                        // 2. If byte is alpha, determine Lower/Upper.
                        // 3. If `current_case` (stored case) is 0 (Unknown), store this as `current_case`.
                        // 4. If `current_case` is not 0, compare. If mismatch, error.
                        
                        // We need to latch `current_case`.
                        // Wait, `current_case` is the registered "Golden" case.
                        // We need to load it.
                        // If current_case == 0 && byte is alpha, load it.
                        // If current_case != 0 && byte is alpha, compare.
                    end
                end

                VALIDATE_CASE: begin
                    // Dummy state for final cleanup or waiting for last cycle
                end

                DONE: begin
                    done <= 1'b1;
                    // Update result if not already done (though result is set in VALIDATE_CASE->DONE transition)
                    if (!is_empty && !error_flag) result <= 1'b1;
                    else result <= 1'b0;
                end
            endcase
        end
    end

    // Combinational Logic for State Transition, Byte Checking, and Flag Updates
    // This block performs the actual byte inspection in PROCESS_KEYS state
    
    reg [7:0] current_byte;
    reg char_is_lower;
    reg char_is_upper;
    reg char_is_invalid;
    reg [1:0] char_case_type; // 1=Lower, 2=Upper, 0=Invalid/Non-alpha
    
    always @(*) begin
        // Default next state
        next_state = state;
        
        // Extract byte based on char_idx
        // char 0 -> bits 63-56
        // char 1 -> bits 55-48 ...
        case (char_idx)
            3'd0: current_byte = current_key[63:56];
            3'd1: current_byte = current_key[55:48];
            3'd2: current_byte = current_key[47:40];
            3'd3: current_byte = current_key[39:32];
            3'd4: current_byte = current_key[31:24];
            3'd5: current_byte = current_key[23:16];
            3'd6: current_byte = current_key[15:8];
            3'd7: current_byte = current_key[7:0];
            default: current_byte = 8'h00;
        endcase

        // Determine char properties
        char_is_lower = (current_byte >= 8'h61 && current_byte <= 8'h7A);
        char_is_upper = (current_byte >= 8'h41 && current_byte <= 8'h5A);
        char_is_invalid = !char_is_lower && !char_is_upper;
        
        if (char_is_lower) char_case_type = 2'd1;
        else if (char_is_upper) char_case_type = 2'd2;
        else char_case_type = 2'd0;

        // Determine if current entry is valid based on mask
        entry_valid_flag = valid_entries_reg[entry_idx];

        case (state)
            IDLE: begin
                if (start) next_state = CHECK_EMPTY;
            end

            CHECK_EMPTY: begin
                // We check emptiness here. Note: The combinational check of valid_entries_reg happens
                // in the same cycle as transition from IDLE->CHECK_EMPTY? 
                // No, we need to wait for next cycle to know state.
                // However, the spec says "On start, begin processing".
                // We'll transition to PROCESS_KEYS in the next cycle if not empty.
                next_state = PROCESS_KEYS;
                // But we need to update `is_empty` register in CHECK_EMPTY state.
                // So we stay here for 1 cycle to register the empty status.
            end

            PROCESS_KEYS: begin
                // Stop condition: We have processed all entries.
                // If entry_idx > 7 (meaning we incremented past 7) -> Done checking.
                if (entry_idx > 7) begin
                    next_state = DONE;
                end else if (entry_valid_flag) begin
                    // Check current char
                    // If char is invalid -> Error
                    if (char_is_invalid) begin
                        // 0x00 is padding? The spec says "Any key is shorter than 8 characters (indicated by 0x00 padding)".
                        // Does 0x00 in middle count as invalid? Usually yes for "all 8 characters".
                        // But spec says: "Keys contain non-alphabetic characters" -> False.
                        // "Any key is shorter than 8 characters (indicated by 0x00 padding)" -> False.
                        // So any non-alpha is false.
                        // If char is 0x00, it is non-alpha, so False.
                        // Exception: What if it's padding at end of string? We need exactly 8 chars.
                        // So 0x00 anywhere is invalid.
                        // Wait, spec: "Key shorter than 8 characters". If the key is "AB", padd", is it valid? No.
                        // The spec implies fixed 8 chars. So strictly check all 8.
                        // So 0x00 is invalid.
                        next_state = DONE; // Fast fail
                    end else begin
                        // Valid alpha char
                        if (current_case == 2'b0) begin
                            // First char encountered, set case
                            // We need to register this. 
                            // But we are in combinational block.
                            // We rely on the Sequential block to latch `current_case` if we stay in PROCESS_KEYS?
                            // No, we need to decide next state.
                            // If we are at last char of last valid entry -> DONE
                            if (char_idx == 7 && entry_idx == 7) next_state = DONE;
                            else if (char_idx == 7) next_state = PROCESS_KEYS; // Continue to next entry (handled by seq logic increment)
                            else next_state = PROCESS_KEYS; // Continue char
                            
                            // We must signal to sequential logic to latch the case.
                            // We can use `char_case_type`.
                            // But `current_case` is updated in sequential block only when we transition.
                            // Actually, we should update `current_case` immediately when we find the first alpha.
                            // Since this is the first cycle we see it.
                        end else begin
                            // Case already set, compare
                            if (char_case_type != current_case) begin
                                // Mismatch -> Error
                                next_state = DONE;
                            end else begin
                                // Match -> Continue
                                if (char_idx == 7 && entry_idx == 7) next_state = DONE;
                                else if (char_idx == 7) next_state = PROCESS_KEYS;
                                else next_state = PROCESS_KEYS;
                            end
                        end
                    end
                end else begin
                    // Entry invalid, skip it
                    if (entry_idx > 7) next_state = DONE;
                    else next_state = PROCESS_KEYS;
                end
            end

            DONE: begin
                next_state = DONE; // Stay in done
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Since the sequential block updates registers on posedge, and we need to update current_case
    // based on the first character check, we need to handle the "First Case" update.
    // The logic above in PROCESS_KEYS checks the byte.
    // We need to distinguish: Is this the very first valid character of the whole dictionary?
    // We can check if `current_case` is 0.
    
    // However, the sequential block updates `current_case` inside `case(state)`.
    // Let's add logic inside the sequential block to handle loading `current_case`.
    // But `current_case` is a register.
    // We need to modify the PROCESS_KEYS section in the sequential block.
    
    // Revising the Sequential Logic specific to PROCESS_KEYS:
    // We need to perform the byte check there to latch flags correctly.
    // Let's move the byte check logic into the Sequential block's PROCESS_KEYS section, 
    // because it updates `error_flag` and `current_case` which are registers.

    // --- Correction to Sequential Logic for PROCESS_KEYS ---
    // (Replacing the empty PROCESS_KEYS section in the first always block)
    
    // We will override the PROCESS_KEYS part of the first always block using an inner always block if this were SystemVerilog,
    // but plain Verilog needs rewrite. Let's rewrite the full sequential logic block cleanly.
    
    // -- REWRITTEN SEQUENTIAL LOGIC --
    // (This part replaces the previous always block for clarity and correctness)
    
endmodule

// Re-implementation of the module with fully integrated logic to avoid confusion with partial code blocks

module check_dict_case_final (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_entries,
    input [63:0] key_0,
    input [63:0] key_1,
    input [63:0] key_2,
    input [63:0] key_3,
    input [63:0] key_4,
    input [63:0] key_5,
    input [63:0] key_6,
    input [63:0] key_7,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE         = 3'b000;
    localparam CHECK_EMPTY  = 3'b001;
    localparam PROCESS_KEYS = 3'b010;
    localparam DONE         = 3'b101;

    reg [2:0] state;
    reg [7:0] valid_entries_reg;
    reg [2:0] entry_idx;
    reg [2:0] char_idx;
    reg [1:0] expected_case; // 0=Unknown, 1=Lower, 2=Upper
    reg error_flag;
    reg is_empty_flag;
    reg [63:0] current_key_data;
    reg is_entry_valid;

    // Combinational Key Selector
    wire [63:0] keys [7:0];
    assign keys[0] = key_0;
    assign keys[1] = key_1;
    assign keys[2] = key_2;
    assign keys[3] = key_3;
    assign keys[4] = key_4;
    assign keys[5] = key_5;
    assign keys[6] = key_6;
    assign keys[7] = key_7;

    // Combinational Byte Extraction
    wire [7:0] current_byte;
    assign current_byte = (char_idx == 3'd0) ? current_key_data[63:56] :
                          (char_idx == 3'd1) ? current_key_data[55:48] :
                          (char_idx == 3'd2) ? current_key_data[47:40] :
                          (char_idx == 3'd3) ? current_key_data[39:32] :
                          (char_idx == 3'd4) ? current_key_data[31:24] :
                          (char_idx == 3'd5) ? current_key_data[23:16] :
                          (char_idx == 3'd6) ? current_key_data[15:8]  : current_key_data[7:0];

    // Combinational Character Type
    wire is_lower, is_upper, is_invalid;
    assign is_lower = (current_byte >= 8'h61 && current_byte <= 8'h7A);
    assign is_upper = (current_byte >= 8'h41 && current_byte <= 8'h5A);
    assign is_invalid = !is_lower && !is_upper;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            valid_entries_reg <= 8'b0;
            entry_idx <= 3'b0;
            char_idx <= 3'b0;
            expected_case <= 2'b0;
            error_flag <= 1'b0;
            is_empty_flag <= 1'b0;
            current_key_data <= 64'b0;
            is_entry_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        valid_entries_reg <= valid_entries;
                        entry_idx <= 3'b0;
                        char_idx <= 3'b0;
                        expected_case <= 2'b0;
                        error_flag <= 1'b0;
                        is_empty_flag <= 1'b0;
                        state <= CHECK_EMPTY;
                    end
                end

                CHECK_EMPTY: begin
                    if (valid_entries_reg == 8'b0) begin
                        is_empty_flag <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Prepare for processing
                        // Find first valid entry to latch key
                        // We need to load the key for the first valid entry index (which is 0 if valid_entries[0] is 1)
                        // If entry 0 is invalid, we need to find the first one.
                        // However, the loop logic in PROCESS_KEYS will handle skipping.
                        // Just reset indices and proceed.
                        entry_idx <= 3'b0;
                        char_idx <= 3'b0;
                        // We need to load `current_key_data` based on the first valid entry.
                        // Since this is combinational lookup, we can load it now if we know it's valid.
                        // But the loop might start at 0, which might be invalid.
                        // Let's load the key at entry_idx 0. The PROCESS_KEYS logic will handle validity.
                        // We need to latch the key specifically.
                        // Actually, let's just proceed to PROCESS_KEYS. 
                        // We must ensure `current_key_data` is loaded for the first processed entry.
                        state <= PROCESS_KEYS;
                    end
                end

                PROCESS_KEYS: begin
                    // 1. Check if we are done with all entries (entry_idx > 7)
                    if (entry_idx > 7) begin
                        state <= DONE;
                    end else begin
                        // 2. Check validity of current entry
                        is_entry_valid <= valid_entries_reg[entry_idx];
                        
                        // We need to latch the key for this entry.
                        // Since we are in PROCESS_KEYS, we should ensure `current_key_data` holds the key for `entry_idx`.
                        // But registers are updated at end of cycle. 
                        // To get key for entry_idx N, we should have loaded it in the cycle we moved to entry_idx N.
                        // Ideally, we load `current_key_data` right after we increment `entry_idx` or in the state transition.
                        
                        // Let's refine loading of `current_key_data`:
                        // It must be combinational from inputs, then registered if we stick to the entry.
                        // However, we are iterating characters. We need to keep the key constant for 8 cycles.
                        
                        // Strategy: Load `current_key_data` when `char_idx` is 0 (start of key check).
                        if (char_idx == 0) begin
                            // Latch key for this entry
                            case (entry_idx)
                                0: current_key_data <= keys[0];
                                1: current_key_data <= keys[1];
                                2: current_key_data <= keys[2];
                                3: current_key_data <= keys[3];
                                4: current_key_data <= keys[4];
                                5: current_key_data <= keys[5];
                                6: current_key_data <= keys[6];
                                7: current_key_data <= keys[7];
                            endcase
                        end

                        // 3. Process logic if valid
                        if (valid_entries_reg[entry_idx]) begin
                            // Check current character (current_byte is combinational of current_key_data)
                            
                            // Check Invalid
                            if (is_invalid) begin
                                error_flag <= 1'b1;
                                state <= DONE;
                            end else begin
                                // Valid Alpha Character
                                // Determine current char type
                                if (expected_case == 2'b0) begin
                                    // First case detected
                                    if (is_lower) expected_case <= 2'd1;
                                    else if (is_upper) expected_case <= 2'd2;
                                end else begin
                                    // Compare with existing case
                                    if ((is_lower && expected_case != 2'd1) || (is_upper && expected_case != 2'd2)) begin
                                        error_flag <= 1'b1;
                                        state <= DONE;
                                    end
                                end

                                // Increment Indices
                                if (char_idx < 7) begin
                                    char_idx <= char_idx + 1;
                                end else begin
                                    // End of key
                                    char_idx <= 0;
                                    // Move to next entry
                                    if (entry_idx < 7) begin
                                        entry_idx <= entry_idx + 1;
                                    end else begin
                                        // End of all keys
                                        state <= DONE;
                                    end
                                end
                            end
                        end else begin
                            // Entry invalid, skip to next
                            char_idx <= 0;
                            if (entry_idx < 7) entry_idx <= entry_idx + 1;
                            else state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!is_empty_flag && !error_flag) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

// To strictly follow the instruction to return *one* module named 'check_dict_case', 
// we provide the clean, compact version below.

module check_dict_case (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_entries,
    input [63:0] key_0,
    input [63:0] key_1,
    input [63:0] key_2,
    input [63:0] key_3,
    input [63:0] key_4,
    input [63:0] key_5,
    input [63:0] key_6,
    input [63:0] key_7,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE         = 3'b000;
    localparam CHECK_EMPTY  = 3'b001;
    localparam PROCESS_KEYS = 3'b010;
    localparam DONE         = 3'b101;

    reg [2:0] state;
    reg [7:0] mask;
    reg [2:0] e_idx;
    reg [2:0] c_idx;
    reg [1:0] case_type;
    reg err;
    reg [63:0] key_buf;

    // Key selection
    wire [63:0] k [7:0];
    assign k[0] = key_0; assign k[1] = key_1; assign k[2] = key_2; assign k[3] = key_3;
    assign k[4] = key_4; assign k[5] = key_5; assign k[6] = key_6; assign k[7] = key_7;

    // Byte extraction based on char index
    wire [7:0] byte_val;
    assign byte_val = (c_idx == 0) ? key_buf[63:56] : (c_idx == 1) ? key_buf[55:48] :
                      (c_idx == 2) ? key_buf[47:40] : (c_idx == 3) ? key_buf[39:32] :
                      (c_idx == 4) ? key_buf[31:24] : (c_idx == 5) ? key_buf[23:16] :
                      (c_idx == 6) ? key_buf[15:8]  : key_buf[7:0];

    wire is_low = (byte_val >= 8'h61 && byte_val <= 8'h7A);
    wire is_up  = (byte_val >= 8'h41 && byte_val <= 8'h5A);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        mask <= valid_entries;
                        e_idx <= 3'b0;
                        c_idx <= 3'b0;
                        case_type <= 2'b0;
                        err <= 1'b0;
                        state <= CHECK_EMPTY;
                    end
                end

                CHECK_EMPTY: begin
                    if (mask == 8'b0) begin
                        state <= DONE;
                    end else begin
                        state <= PROCESS_KEYS;
                        // Latch first key if entry 0 is valid, otherwise logic in PROCESS_KEYS handles it
                        if (mask[0]) key_buf <= k[0];
                    end
                end

                PROCESS_KEYS: begin
                    // If entry invalid, skip
                    if (!mask[e_idx]) begin
                        e_idx <= e_idx + 1;
                        c_idx <= 0;
                        // Latch next valid key if moving to next entry
                        // (Optimistic latch, might be unused if next is also invalid, but safe)
                        // If we are done with entries (e_idx goes to 8), we will catch below
                        if (e_idx < 7 && mask[e_idx + 1]) key_buf <= k[e_idx + 1];
                    end else begin
                        // Check Character
                        if (byte_val == 8'h00 || (!is_low && !is_up)) begin
                            err <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Case Check
                            if (case_type == 2'b0) begin
                                // Set case
                                case_type <= is_low ? 2'd1 : 2'd2;
                            end else begin
                                // Compare case
                                if ((is_low && case_type != 2'd1) || (is_up && case_type != 2'd2)) begin
                                    err <= 1'b1;
                                    state <= DONE;
                                end
                            end
                            
                            // Next Char
                            if (c_idx < 7) begin
                                c_idx <= c_idx + 1;
                            end else begin
                                // End of key
                                c_idx <= 0;
                                // Next Entry
                                if (e_idx < 7) begin
                                    e_idx <= e_idx + 1;
                                    if (mask[e_idx + 1]) key_buf <= k[e_idx + 1];
                                end else begin
                                    state <= DONE;
                                end
                            end
                        end
                    end
                    // Catch case where we skipped to end (e_idx = 8)
                    if (e_idx > 7) state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= !err && (mask != 8'b0);
                end
            endcase
        end
    end
endmodule