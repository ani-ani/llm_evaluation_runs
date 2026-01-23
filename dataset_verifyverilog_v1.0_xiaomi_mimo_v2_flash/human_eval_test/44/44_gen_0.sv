module change_base(
    input clk,
    input rst_n,
    input start,
    input [11:0] x,
    input [2:0] base,
    output reg [127:0] result_str,
    output reg [3:0] str_len,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] DIVIDE    = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] REVERSE   = 3'd3;
    localparam [2:0] PAD       = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [11:0] current_x;
    reg [3:0] digit_buffer [0:11];  // Stores raw digits (0-6)
    reg [3:0] digit_ptr;             // Points to next digit slot (stack top + 1)
    reg [3:0] output_ptr;            // Points to current byte being written
    reg [3:0] temp_quotient;
    reg [3:0] sub_count;
    reg [3:0] temp_str_len;
    
    // Loop counters
    integer i;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? DIVIDE : IDLE;
            DIVIDE:     next_state = CHECK;
            CHECK:      next_state = (current_x == 12'd0) ? REVERSE : DIVIDE;
            REVERSE:    next_state = (output_ptr == digit_ptr) ? PAD : REVERSE;
            PAD:        next_state = (output_ptr == 4'd15) ? FINISH : PAD;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_str <= 128'd0;
            str_len <= 4'd0;
            current_x <= 12'd0;
            digit_ptr <= 4'd0;
            output_ptr <= 4'd0;
            sub_count <= 4'd0;
            // Initialize digit_buffer to 0
            for (i = 0; i < 12; i = i + 1) begin
                digit_buffer[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_x <= x;
                        digit_ptr <= 4'd0;
                        output_ptr <= 4'd0;
                        sub_count <= 4'd0;
                        temp_str_len <= 4'd0;
                    end
                end

                DIVIDE: begin
                    // Perform one subtraction
                    if (current_x >= {8'd0, base}) begin
                        current_x <= current_x - {8'd0, base};
                        sub_count <= sub_count + 4'd1;
                    end
                end

                CHECK: begin
                    // Determine if division is complete for this digit
                    // Remainder is in current_x (if we subtracted) or 0 if x < base initially
                    if (current_x >= {8'd0, base}) begin
                        // Still need to subtract more
                        // Keep current_x as is (it was decremented in DIVIDE state)
                        // Reset sub_count for next digit
                        sub_count <= 4'd0;
                    end else begin
                        // Division complete for this digit
                        // Quotient is sub_count
                        // Remainder is current_x
                        if (digit_ptr < 4'd12) begin
                            digit_buffer[digit_ptr] <= current_x[3:0];
                            digit_ptr <= digit_ptr + 4'd1;
                        end
                        
                        // Setup for next division step
                        current_x <= {8'd0, sub_count};
                        sub_count <= 4'd0;
                        
                        // If quotient is 0, we are done with division phase
                        if (sub_count == 4'd0) begin
                            // Ensure current_x is actually 0 (it should be)
                            current_x <= 12'd0;
                        end
                    end
                end

                REVERSE: begin
                    // Copy digits from buffer to result_str bytes
                    // Byte 15 is MSB (first char), Byte 0 is LSB (last char)
                    // We want LSB of number at lower memory address (byte 0)
                    // So we map buffer[0] -> byte 0, buffer[1] -> byte 1, etc.
                    // Actually, spec says: result_str[127:120] = first char, result_str[7:0] = last char.
                    // This means index 0 of buffer (LSB digit) goes to the LAST valid byte.
                    // Wait, let's clarify: "Least significant byte (result_str[7:0]) corresponds to the last character of the string"
                    // String "22" -> Bytes: [MSB...][LSB].
                    // result_str[127:120] = '2', result_str[119:112] = '2'.
                    // So buffer[0] (value 2) -> goes to highest index byte (127:120) if we push to stack?
                    // Let's trace: 8 (base 3) -> 22.
                    // 8 / 3 = 2 rem 2. buffer[0] = 2.
                    // 2 / 3 = 0 rem 2. buffer[1] = 2.
                    // String "22". MSB is '2', LSB is '2'.
                    // buffer[0] is first remainder (LSB of number?) No, repeated division gives LSB first.
                    // 8 (1000) -> 8/3=2 rem 2 (LSB of result). 2/3=0 rem 2 (MSB of result).
                    // So buffer[0] = 2 (LSB), buffer[1] = 2 (MSB).
                    // String "22" (left aligned). MSB char '2' should be at higher address.
                    // output_ptr starts at 0.
                    // If we copy buffer[1] to byte 15, and buffer[0] to byte 14?
                    // No, let's simply use output_ptr to index the result byte.
                    // We will fill result_str starting from byte 15 downwards.
                    // Index: digit_ptr - 1 - output_ptr.
                    
                    // Logic: output_ptr 0 -> byte 15. output_ptr 1 -> byte 14, etc.
                    // Value to write: digit_buffer[digit_ptr - 1 - output_ptr]
                    // ASCII: + 8'h30
                    result_str[127 -: 8] <= result_str[119:0]; // Shift left? No, direct assignment better.
                    // Better: calculate index dynamically.
                    // Since we can't easily index dynamic arrays in always block with variable indices easily in synthesis without deep logic,
                    // we map output_ptr directly.
                    // Let's map output_ptr 0 -> byte 0 (LSB). But spec says byte 0 is last char.
                    // So output_ptr 0 -> byte 0. output_ptr 1 -> byte 1.
                    // Final string: valid bytes are output_ptr 0 to digit_ptr-1.
                    // Pad rest with 0x20.
                    // This means the string is stored LSB-first in memory.
                    // Wait, spec: "result_str[127:120] = 0x32, result_str[119:112] = 0x32"
                    // This implies MSB of string is at MSB of register.
                    // So we should fill from MSB down to 0.
                    // output_ptr 0 -> byte 15. output_ptr 1 -> byte 14.
                    // Index = 15 - output_ptr.
                    // Value: digit_buffer[output_ptr] (since buffer[0] is LSB of number, we want it at the end of string? No, standard representation is MSB first).
                    // 8 -> "22". buffer[0]=2 (LSB), buffer[1]=2 (MSB).
                    // String "22". MSB is '2'.
                    // We need to read buffer in reverse order for string generation.
                    // Index = digit_ptr - 1 - output_ptr.
                    
                    // Check bounds
                    if (output_ptr < digit_ptr) begin
                        // We need to access digit_buffer[digit_ptr - 1 - output_ptr]
                        // This requires an intermediate calculation for index
                        // Since digit_ptr is small, we can use a case statement or simple logic.
                        // Let's use a helper variable for the read index.
                        // For now, just copy logic.
                        // We will compute the value in combinational logic or just index carefully.
                        // To avoid complex indexing in sequential block, let's use a combinational block to read the digit.
                        // Or, since max 12 digits, we can unroll or use a loop to set the byte.
                        // Let's use a combinational wire for the current digit to copy.
                        // But we are in sequential block.
                        // Let's implement the logic inside the state machine.
                        
                        // We need to map (digit_ptr - 1 - output_ptr) to byte (15 - output_ptr)
                        // Actually, easier: Fill from MSB.
                        // output_ptr 0: Target Byte 15. Source Index: digit_ptr-1.
                        // output_ptr 1: Target Byte 14. Source Index: digit_ptr-2.
                        
                        // Since we can't index arbitrary array in always block easily with variable indices in Icarus without generate/unroll,
                        // we will use a combinational block to prepare the byte.
                        // Or, simply unroll the logic for 12 positions using if/else.
                        
                        // Wait, let's cheat slightly. We can construct the string in a register and then assign.
                        // Or, we can use a for-loop to build the string in the REVERSE state.
                        // But we need to handle variable digit count.
                        
                        // Let's use a combinational block to select the digit.
                        // But we need to trigger the shift/assign in sequential block.
                        // Let's rely on the fact that we can generate the index logic.
                        // Actually, Icarus Verilog supports arrays in always blocks if indexed by constants.
                        // If indexed by variables, it might be tricky depending on version.
                        // Let's use a case statement based on digit_ptr and output_ptr if possible, or just assume it works.
                        // A safer way for synthesis: unroll the copy for the max number of digits.
                        // Since output_ptr increments, we can just shift result_str and append the new char.
                        // But spec says left-aligned. "22" -> [2][2][ ][ ]...
                        // If we shift left and append LSB, we get "2 " then "22"? No.
                        // If we shift left and append MSB, we get "2" then "22". 
                        // We need to output MSB first.
                        // So we need to read buffer from (digit_ptr-1) down to 0.
                        // output_ptr 0: read buffer[digit_ptr-1].
                        // output_ptr 1: read buffer[digit_ptr-2].
                        
                        // Let's declare a temporary register to hold the selected digit value for this cycle.
                        // But we need to compute it combinationally.
                        // Let's add a combinational block before the always block.
                    end
                    
                    // For Icarus compatibility and simplicity, let's use a simple approach:
                    // We will shift result_str left by 8 bits and OR in the new character.
                    // But we need to handle padding correctly.
                    // Let's fill result_str starting from byte 15 downwards.
                    // We need a combinational wire to select the digit from buffer.
                    // Since buffer is 12x4, we can't index it easily with variable in always block in standard Verilog 2001 without generate.
                    // Let's use a case statement for the index.
                end

                PAD: begin
                    // Pad remaining bytes with 0x20
                    // Shift left or assign specific bytes.
                    // We are filling from MSB (127) downwards.
                    // output_ptr tracks how many bytes we've written.
                    // We need to fill bytes 15-output_ptr down to 0 with spaces.
                    // This is tricky to do incrementally.
                    // Better: In REVERSE, fill valid bytes. In PAD, fill the rest.
                    // Since we are shifting or assigning, let's just fill the remaining bytes directly.
                    // We can use a loop or direct assignment.
                    // Since output_ptr is variable, we can use a for-loop inside the state.
                    // But we need to know which bytes to fill.
                    // Bytes filled so far: 15 to (15 - output_ptr + 1).
                    // Bytes to fill: (15 - output_ptr) down to 0.
                    // Let's just assign 0x20 to all bytes where index >= (16 - output_ptr).
                    // Wait, output_ptr counts from 0. If output_ptr=2, bytes 15, 14 filled. Bytes 13..0 to fill.
                    // We can't easily write to a range based on variable in always block without generate.
                    // Let's use a for-loop in the always block. Icarus usually supports for-loops for assignment.
                    // Or, simply don't shift. Just assign byte by byte in REVERSE and PAD.
                    // Let's rewrite REVERSE and PAD to be cleaner.
                end

                FINISH: begin
                    done <= 1'b1;
                    str_len <= temp_str_len; // This was not set in CHECK? Wait, we need to set str_len.
                    // In CHECK, when we exit, digit_ptr is the length.
                    // We should assign str_len at the end of REVERSE or start of PAD.
                end
            endcase
        end
    end
    
    // Combinational Logic for Digit Selection (needed for Icarus array access)
    reg [3:0] selected_digit;
    always @(*) begin
        // Calculate source index: digit_ptr - 1 - output_ptr
        // This is a variable index into the array.
        // To be safe and synthesizable in Icarus, we use a lookup logic.
        // Since max 12, we can do this:
        selected_digit = 4'd0;
        if (output_ptr < digit_ptr) begin
            case (digit_ptr - 1 - output_ptr)
                4'd0:  selected_digit = digit_buffer[0];
                4'd1:  selected_digit = digit_buffer[1];
                4'd2:  selected_digit = digit_buffer[2];
                4'd3:  selected_digit = digit_buffer[3];
                4'd4:  selected_digit = digit_buffer[4];
                4'd5:  selected_digit = digit_buffer[5];
                4'd6:  selected_digit = digit_buffer[6];
                4'd7:  selected_digit = digit_buffer[7];
                4'd8:  selected_digit = digit_buffer[8];
                4'd9:  selected_digit = digit_buffer[9];
                4'd10: selected_digit = digit_buffer[10];
                4'd11: selected_digit = digit_buffer[11];
                default: selected_digit = 4'd0;
            endcase
        end
    end

    // Secondary always block for REVERSE and PAD logic to keep main FSM clean
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_str <= 128'd0;
        end else begin
            if (state == IDLE && start) begin
                // Clear result_str on start
                result_str <= 128'd0;
            end
            
            if (state == REVERSE) begin
                // output_ptr is the byte index we are writing (0 to 15)
                // We are writing to byte (15 - output_ptr) in result_str?
                // No, let's map output_ptr to byte index directly.
                // output_ptr 0 -> byte 15 (MSB of string)
                // output_ptr 1 -> byte 14
                // Byte index = 15 - output_ptr.
                // Value = selected_digit + 0x30
                
                if (output_ptr < digit_ptr) begin
                    // Direct bit slicing assignment for 8-bit byte
                    // result_str[ (15 - output_ptr)*8 + 7 : (15 - output_ptr)*8 ]
                    // We need to compute these indices.
                    // Since we can't do variable slice indices easily in always block without generate,
                    // we will use a shift register approach or just hardcode the logic for 16 bytes.
                    // Actually, modern synthesis tools and Icarus support variable slices if the width is constant.
                    // result_str[127:0].
                    // Byte i is [8*i+7 : 8*i].
                    // Here i = 15 - output_ptr.
                    // Let's try: result_str[ (15 - output_ptr) * 8 + 7 -: 8 ] <= ...
                    // This is valid SystemVerilog. Icarus might support it if it's not too complex.
                    
                    // To be safe, let's use a for-loop in the combinational block? No, assignment.
                    // Let's just write it. If Icarus complains, it's a limitation we have to work around.
                    // But the prompt asks for "For Icarus Verilog compatibility, avoid complex array operations".
                    // This includes dynamic bit slicing.
                    
                    // Alternative: Shift register.
                    // result_str <= {result_str[119:0], new_byte};
                    // This appends to the LSB. 
                    // If we read buffer in reverse (MSB first), we get "22".
                    // buffer[1] -> '2'. result_str = {8'd0, 8'h32}.
                    // buffer[0] -> '2'. result_str = {8'h32, 8'h32}.
                    // This gives MSB at high bits (left aligned). Correct.
                    // So we need to read buffer in reverse order.
                    // output_ptr 0: read buffer[digit_ptr - 1]
                    // output_ptr 1: read buffer[digit_ptr - 2]
                    // ...
                    // output_ptr digit_ptr-1: read buffer[0]
                    
                    // Since we have the combinational block `selected_digit`, we can use it.
                    // But `selected_digit` calculates digit_ptr - 1 - output_ptr.
                    // So for output_ptr 0, it reads digit_ptr-1. Correct.
                    
                    result_str[127:0] <= {result_str[119:0], (8'h30 + selected_digit)};
                    
                    // Increment output_ptr in main FSM or here?
                    // Let's do it in main FSM to keep state transitions clean.
                    // Wait, if we shift, we need to increment output_ptr in this block to match the shift?
                    // No, output_ptr is incremented in the main FSM.
                    // But we are using output_ptr to index `selected_digit`.
                    // If output_ptr increments in next cycle, `selected_digit` updates.
                    // This is fine.
                end
            end
            
            if (state == PAD) begin
                // Pad remaining bytes with 0x20
                // We shifted in REVERSE. Now we need to shift in spaces until full (16 bytes).
                // Total bytes needed: 16.
                // We shifted `output_ptr` bytes so far.
                // We need to shift 16 - output_ptr more bytes.
                // But output_ptr is incremented in the main FSM.
                // We can just check if we are done.
                // Since we are in PAD state, output_ptr has reached digit_ptr.
                // We need to fill up to 15.
                // We can use output_ptr to count pad steps too.
                // In PAD state, output_ptr is digit_ptr. 
                // We need to shift (16 - digit_ptr) times.
                // We can use `temp_str_len` to store digit_ptr.
                // Let's track pad count separately or reuse output_ptr.
                // Let's reuse output_ptr. In PAD state, output_ptr increments from digit_ptr to 16.
                
                result_str[127:0] <= {result_str[119:0], 8'h20};
            end
            
            if (state == FINISH) begin
                str_len <= digit_ptr;
            end
        end
    end
    
    // Handle counter updates (output_ptr)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_ptr <= 4'd0;
        end else begin
            if (state == IDLE && start) output_ptr <= 4'd0;
            else if (state == REVERSE && output_ptr < digit_ptr) output_ptr <= output_ptr + 4'd1;
            else if (state == PAD && output_ptr < 4'd15) output_ptr <= output_ptr + 4'd1;
        end
    end

endmodule