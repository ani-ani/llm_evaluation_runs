module decimal_to_binary(
    input clk,
    input rst_n,
    input start,
    input [15:0] decimal_in,
    output reg [79:0] binary_str,
    output reg [3:0] length,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] quotient;
    reg [15:0] quotient_next;
    reg [3:0] count;
    reg [3:0] count_next;
    reg [79:0] shift_reg;
    reg [79:0] shift_reg_next;
    reg [3:0] length_reg;
    reg [3:0] length_reg_next;
    reg done_reg;
    reg done_reg_next;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            quotient <= 16'b0;
            count <= 4'b0;
            shift_reg <= 80'b0;
            length_reg <= 4'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            quotient <= quotient_next;
            count <= count_next;
            shift_reg <= shift_reg_next;
            length_reg <= length_reg_next;
            done_reg <= done_reg_next;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        quotient_next = quotient;
        count_next = count;
        shift_reg_next = shift_reg;
        length_reg_next = length_reg;
        done_reg_next = done_reg;

        case (state)
            IDLE: begin
                done_reg_next = 1'b0;
                if (start) begin
                    // Initialize for calculation
                    // Special handling for 0 to ensure length=1
                    if (decimal_in == 16'd0) begin
                        shift_reg_next = {8'h30, 72'b0}; // '0' followed by zeros
                        length_reg_next = 4'd1;
                        next_state = DONE;
                    end else begin
                        quotient_next = decimal_in;
                        count_next = 4'd0;
                        shift_reg_next = 80'b0;
                        length_reg_next = 4'd0;
                        next_state = CALCULATE;
                    end
                end
            end

            CALCULATE: begin
                // Algorithm: Repeated division by 2
                // Since we need LSB first stored in register, and we want MSB-first output,
                // we will accumulate bits in the shift register as we generate them.
                // However, the standard algorithm generates LSB first.
                // If we shift left and insert at LSB, we get reverse order (which we need for display).
                // 18 -> 10010. Remainders: 0, 1, 0, 0, 1. 
                // If we store [0] then [1] etc in a shift register:
                // Cycle 1: Reg = ...0
                // Cycle 2: Reg = ...10
                // This gives '01' which is wrong for '10'.
                // We need to append to the right (MSB side) or shift left.
                // Let's shift left and insert new bit at position 0.
                // Reg[0] = remainder. 
                // 18: Rem=0 -> Reg=0. Count=1.
                // Quot=9. Rem=1 -> Reg=10. Count=2.
                // This results in LSB being at Reg[0] and MSB at Reg[count-1].
                // When we convert to ASCII, we need to read Reg[count-1:0] and place into string.
                // The string is 80 bits. '10010' needs to be '10010' + padding.
                // If Reg = 000...010010, then Reg[count-1:0] is the valid part.
                // Reg[count-1] is MSB.
                // We want MSB at binary_str[79:72].
                // So we need to align Reg to the top of binary_str.
                // Actually, let's build the string directly.
                // The requirement says "Store bits in shift register during calculation".
                // Let's use a shift register that fills from MSB to LSB.
                // To do this, we need to generate bits in reverse order or use a counter.
                // With the given algorithm (division), we get LSB first.
                // To fill binary_str[79:72] first, we would need to know the total length first.
                // But we discover length as we go.
                // Alternative: Store LSB first in the shift register, then reverse in DONE state.
                // Or: Shift left, insert remainder. Result is reverse order of bits.
                // 18: Div 2 -> 9 rem 0. Shift reg [0] = 0. 
                // 9: Div 2 -> 4 rem 1. Shift reg [1:0] = 10.
                // 4: Div 2 -> 2 rem 0. Shift reg [2:0] = 010.
                // 2: Div 2 -> 1 rem 0. Shift reg [3:0] = 0010.
                // 1: Div 2 -> 0 rem 1. Shift reg [4:0] = 10010.
                // This is '10010' (MSB is bit 4, LSB is bit 0).
                // Wait, if we do shift_left and insert at 0: 
                // Reg = Reg << 1. Reg[0] = rem.
                // 18 (10010):
                // 1. Div: 9 rem 0. Reg = 0.
                // 2. Div: 4 rem 1. Reg = 10 (binary). (Bit 1=1, Bit 0=0).
                // 3. Div: 2 rem 0. Reg = 010. (Bit 2=0, Bit 1=1, Bit 0=0).
                // 4. Div: 1 rem 0. Reg = 0010.
                // 5. Div: 0 rem 1. Reg = 10010.
                // Result is correct '10010' for the valid part.
                // But this is stored in Reg[4:0] with MSB at 4.
                // For ASCII conversion: We need to place '1' (bit 4) into binary_str[79:72].
                // We can do this in the DONE state.
                // We need to handle the maximum length (16).
                // Reg size needs to be 16 bits minimum. 

                if (quotient != 16'd0) begin
                    // Division by 2
                    quotient_next = quotient >> 1;
                    
                    // Shift left to make room for new bit (effectively building MSB at high index)
                    // Wait, standard shift left: MSB falls off, LSB becomes 0.
                    // If we want to append, we shift left then OR with remainder.
                    // Let's use a 16-bit temp register for the calculation logic description,
                    // but we are updating shift_reg_next directly.
                    // The 'shift_reg' will hold the bits in the order generated.
                    // Note: The generated bits are LSB first.
                    // If we Shift Left and Insert at 0:
                    // Cycle 1 (rem 0): Reg = 0.
                    // Cycle 2 (rem 1): Reg = 10. (MSB is 1).
                    // This order is actually MSB first if we look at the bits from high to low.
                    // But typically we want to fill from the left of the string.
                    // Let's stick to: Shift Left, Insert at 0.
                    // This builds the value "correctly" numerically if we consider the register value.
                    // But we need to output as a string.
                    // Example 18 -> 10010.
                    // Bits generated: 0, 1, 0, 0, 1.
                    // Reg: 0 -> 10 -> 010 -> 0010 -> 10010.
                    // This looks like the correct binary representation.
                    // We just need to convert these bits to ASCII.
                    // The MSB is at bit index 'count' (after increment).
                    // Let's refine: we need a temp reg for calculation.
                    // Let's say we have a reg [15:0] temp_bits.
                    // Actually, we can just use shift_reg for storage, but it's 80 bits.
                    // Let's use a separate 16-bit register for the bits, or use shift_reg properly.
                    // Let's use shift_reg as a temporary buffer for bits, then copy to output in DONE.
                    // But we need to pad with zeros.
                    // Let's use a 16-bit internal shift register 'bit_buffer'.
                    // Since I cannot declare new regs inside always block, I must declare them outside.
                    // Wait, I can declare local variables for logic, but I need to update the stored values.
                    // Let's stick to the existing registers.
                    // Let's use 'shift_reg[15:0]' to store the bits temporarily.
                    // And 'count' to store current length.
                    // Let's update the logic to use shift_reg[15:0] for the binary value.
                    // Actually, 'quotient' is 16 bits. 'count' is 4 bits.
                    // Let's add a 'bit_buffer' reg [15:0] to the module IO if needed, or use 'shift_reg'.
                    // I will use 'shift_reg[15:0]' as the bit accumulator.
                    // Then in DONE, I will expand it to binary_str.

                    // Correct Logic for 'Shift Left, Insert at 0':
                    // We need to generate bits LSB first. 
                    // 18: 10010. Remainders: 0, 1, 0, 0, 1 (LSB to MSB).
                    // If we shift left and insert at 0:
                    // 1. rem=0. Buffer = 0. 
                    // 2. rem=1. Buffer = Buffer << 1 | 1 = 10. (Wait, this puts 1 in bit 1, 0 in bit 0).
                    //    This is '10', which is 2, not '10'.
                    //    Ah, '10' (binary) is 2. '10' (string) is two.
                    //    If we want string '10010', we need to store bits 0..4.
                    //    Let's trace 18.
                    //    Start: 18. 
                    //    Iter 1: 18/2 = 9 rem 0. 
                    //    Iter 2: 9/2 = 4 rem 1. 
                    //    Iter 3: 4/2 = 2 rem 0. 
                    //    Iter 4: 2/2 = 1 rem 0. 
                    //    Iter 5: 1/2 = 0 rem 1. 
                    //    Remainders (LSB first): 0, 1, 0, 0, 1. 
                    //    We want to store this in a register such that reading [4:0] gives 10010.
                    //    Bit 4 (MSB) should be 1. Bit 0 (LSB) should be 0.
                    //    Remainder sequence: R0=0, R1=1, R2=0, R3=0, R4=1.
                    //    Value = R4*16 + R3*8 + R2*4 + R1*2 + R0*1 = 16 + 2 = 18. Correct.
                    //    So we need to assign R0 to bit 0, R1 to bit 1...
                    //    But we generate R0, then R1...
                    //    If we write R0 to bit 0, then R1 to bit 1...
                    //    Buffer[0] = R0. Buffer[1] = R1.
                    //    We need to shift the buffer left by 1 every time we get a new bit?
                    //    No, that would push old bits to higher indices.
                    //    We need to shift existing bits left when we add a NEW bit to the LEFT.
                    //    But we don't know the MSB until the end.
                    //    Wait. If we just want to store the value, we can do: Buffer = (Buffer >> 1) | (Rem << (count)).
                    //    But count increases.
    `               //    Let's use a simpler approach: Buffer = Buffer >> 1; Buffer[count] = Rem. 
                    //    But count starts at 0.
                    //    Let's trace with Buffer = 0.
                    //    1. Rem=0. Buffer[0] = 0. Buffer = 0. Count=1.
                    //    2. Rem=1. Buffer[1] = 1. Buffer = 10b. Count=2.
                    //    3. Rem=0. Buffer[2] = 0. Buffer = 010b. Count=3.
                    //    4. Rem=0. Buffer[3] = 0. Buffer = 0010b. Count=4.
                    //    5. Rem=1. Buffer[4] = 1. Buffer = 10010b. Count=5.
                    //    This works!
                    //    So we need to assign to Buffer[count].
                    //    Verilog allows: Buffer[count] = Rem.
                    //    But we need to handle the shifting of 'quotient' and 'count'.
                    //    Let's use 'shift_reg[15:0]' as the Buffer.
                    
                    // Let's implement the bit assignment:
                    // shift_reg_next[count] = quotient[0];
                    // But shift_reg_next needs to preserve previous bits.
                    // Since we index by 'count', we can just assign the bit.
                    // However, in Verilog, if we write 'shift_reg_next[count] = ...',
                    // we must ensure other bits are preserved. 
                    // We are doing 'shift_reg_next = shift_reg' at the top.
                    // So we can do: shift_reg_next[count] = quotient[0];
                    // And count_next = count + 1;
                    
                    shift_reg_next[count] = quotient[0];
                    count_next = count + 1;
                    quotient_next = quotient >> 1;
                    
                    // Check termination condition? 
                    // 16 iterations max. Or stop when quotient is 0.
                    // If quotient becomes 0, next cycle we shouldn't do anything.
                    // But we need to latch the last bit (which was quotient[0] before it became 0).
                    // The loop condition 'quotient != 0' handles this.
                    // When quotient is 1, we enter. quotient_next becomes 0.
                    // We store bit 1. Next cycle, quotient is 0, so we exit CALCULATE.
                    // Wait, if we enter with quotient=1:
                    // shift_reg[count] = 1.
                    // count++.
                    // quotient = 0.
                    // Next cycle we are in CALCULATE but quotient is 0.
                    // We should transition to DONE.
                    // So we need to check if NEXT quotient will be 0.
                    // Actually, checking quotient != 0 is enough.
                    // The state transition happens at the end of the cycle.
                    // We just updated quotient_next.
                    // If quotient == 1, we do the update. quotient_next is 0.
                    // We stay in CALCULATE? No, the check is for the *current* cycle.
                    // We need to transition out when we are done.
                    // When quotient becomes 0, we are done.
                    // So next_state check should be based on quotient_next.
                    // Or simpler: Stay in CALCULATE if count < 16 AND quotient != 0.
                    // Actually, if quotient is 1, we must process it.
                    // After processing 1, quotient becomes 0. 
                    // So we process all bits until quotient is 0.
                    // Exception: Input 0. Handled in IDLE.
                    
                    if (quotient == 16'd1) begin
                        // This is the last bit. After this, quotient becomes 0.
                        // We process it now.
                        // Next state should be CALCULATE (to finish the op) or DONE?
                        // If we set quotient_next to 0, next cycle we check quotient.
                        // If we stay in CALCULATE, next cycle quotient is 0.
                        // We need to go to DONE.
                        // Let's explicitly check if we are done.
                        // If quotient <= 1, next state is DONE? 
                        // No, because we need to process the bit 1.
                        // Let's stick to the loop.
                        // We process as long as quotient != 0.
                        // We update quotient. If new quotient is 0, we finish.
                        // So we need to look ahead.
                    end
                    
                    if (quotient_next == 16'd0) begin
                        next_state = DONE;
                    end
                end else begin
                    // Should not enter here if state transition is correct, 
                    // but safe to have default.
                    next_state = DONE;
                end
            end

            DONE: begin
                // Convert bits to ASCII string
                // We have stored bits in shift_reg[15:0] (indices 0 to count-1).
                // count holds the length.
                // We need to generate binary_str.
                // Binary str is 10 chars (80 bits). Left aligned.
                // So bits 0..count-1 go to positions (80-8*count)..(79).
                // Example: count=4. Pos 80-32=48 to 79. 
                // Shift 0..3 to 48..55.
                // Actually, we need to generate the string.
                // We can use a loop or explicit assignment.
                // Since count is small (max 16), we can unroll or use a for loop.
                // Synthesizable for loop is tricky if not unrolled, but we can do it.
                // Let's use a generate-style loop or manual assignment for safety.
                // Since we are in an always block, we can't use 'genvar'.
                // We can use a standard 'for' loop if the synthesis tool supports it, 
                // or unroll manually.
                // Let's use a standard loop. Most modern tools handle it.
                
                for (integer i = 0; i < 10; i = i + 1) begin
                    if (i < length_reg) begin
                        // MSB is at shift_reg[length_reg-1]
                        // Index in shift_reg: length_reg - 1 - i
                        // (Since we want first char to be MSB)
                        if (shift_reg[length_reg - 1 - i] == 1'b1) begin
                            binary_str[(79 - 8*i) -: 8] = 8'h31; // '1'
                        end else begin
                            binary_str[(79 - 8*i) -: 8] = 8'h30; // '0'
                        end
                    end else begin
                        // Padding (right side) -> zeros
                        // Wait, "padded with zeros on right"
                        // And "Left-aligned".
                        // Example: 8 -> '1000000000'.
                        // This means MSB is at the start.
                        // Padding is at the end.
                        // My loop variable i goes 0 to 9.
                        // i=0 -> MSB. i=9 -> LSB.
                        // If length is 4, we fill i=0,1,2,3.
                        // i=4..9 should be '0'.
                        // Wait, '1000000000' has '1000' then '000000'.
                        // The string is 10 chars. Left aligned.
                        // If we have '1000' (len 4), we put '1000' at the start and zeros at the end.
                        // My loop logic:
                        // i=0 (first char): shift_reg[3] -> '1'.
                        // i=1: shift_reg[2] -> '0'.
                        // i=2: shift_reg[1] -> '0'.
                        // i=3: shift_reg[0] -> '0'.
                        // i=4: Padding -> '0'.
                        // i=5: Padding -> '0'...
                        // This results in '1000000000'. Correct.
                        binary_str[(79 - 8*i) -: 8] = 8'h30;
                    end
                end
                
                length_reg_next = length_reg; // Keep length
                done_reg_next = 1'b1;
                
                // Wait for start to go low to return to IDLE?
                // Usually done stays high until reset or start new cycle.
                // But we should go back to IDLE when start is deasserted.
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_str <= 80'b0;
            length <= 4'b0;
            done <= 1'b0;
        end else begin
            // The combinational logic updates the 'next' signals.
            // We need to make sure the outputs are updated correctly.
            // The 'binary_str' and 'length' are registers.
            // We can assign them from the internal regs.
            // However, the conversion to ASCII happens in DONE state.
            // It updates 'binary_str' (which is the output reg).
            // Wait, I used 'binary_str' directly in the loop.
            // That is fine.
            // I need to be careful about the 'output reg' vs 'internal reg' distinction.
            // The prompt says "output reg".
            // So I can write to 'binary_str' directly.
            // But 'binary_str' needs to be updated only when DONE logic runs.
            // The combinational block updates 'binary_str' (which is the output reg).
            // This is a latched output if we don't assign it in all branches.
            // Better to make 'binary_str' update only on state change or Done.
            // Let's separate output logic.
            
            // Refined: The combinational block determines the 'next' values.
            // But for arrays like binary_str, it's safer to use a dedicated internal reg.
            // Let's add 'binary_str_next' or just update binary_str in the sequential block.
            // Actually, since 'binary_str' is an output reg, we can drive it from the sequential block.
            // Let's change the combinational block to calculate 'next_binary_str' and 'next_length'.
            // Then assign them in the sequential block.
        end
    end

    // Re-structuring for clarity and correctness to avoid inferred latches or multi-driver issues.
    // I will stick to the provided 'output reg' and update them inside the sequential block.
    // The combinational logic will compute the 'next' state and values.
    
    // Corrected Combinational Logic for next values
    always @(*) begin
        next_state = state;
        quotient_next = quotient;
        count_next = count;
        shift_reg_next = shift_reg;
        length_reg_next = length_reg;
        done_reg_next = done_reg;
        
        // Initialize binary_str_next to avoid latch inference, though it's an output.
        // We will handle output updates in sequential logic.

        case (state)
            IDLE: begin
                done_reg_next = 1'b0;
                if (start) begin
                    if (decimal_in == 16'd0) begin
                        // Handle 0 specifically
                        shift_reg_next = 80'b0; // Bits are 0
                        length_reg_next = 4'd1;
                        next_state = DONE;
                    end else begin
                        quotient_next = decimal_in;
                        count_next = 4'd0;
                        shift_reg_next = 80'b0;
                        length_reg_next = 4'd0;
                        next_state = CALCULATE;
                    end
                end
            end

            CALCULATE: begin
                if (quotient != 16'd0) begin
                    // Store LSB of quotient into shift_reg at position 'count'
                    // shift_reg_next is currently equal to shift_reg (from previous block assignment or default)
                    // We need to update shift_reg_next[count].
                    // Since we are updating specific bits, we need to be careful.
                    // If we assign shift_reg_next[count] = ..., we must ensure other bits are preserved.
                    // The default 'shift_reg_next = shift_reg' handles this.
                    shift_reg_next[count] = quotient[0];
                    count_next = count + 1;
                    quotient_next = quotient >> 1;
                    
                    // If the next quotient is 0, we are done after this cycle.
                    if (quotient == 16'd1) begin
                         next_state = DONE;
                    end
                    // Note: We continue in CALCULATE. If quotient becomes 0 next, we'll exit.
                    // Wait, if quotient is 1, we enter, update, quotient becomes 0.
                    // We should transition to DONE.
                    // The check 'quotient == 1' works.
                end else begin
                     next_state = DONE;
                end
            end

            DONE: begin
                // Latch the results. The combinational logic for ASCII conversion\                // is better placed here or in the sequential block.
                // But we need to compute the string.
                // Let's compute string here using a loop.
                // We can update 'binary_str' directly? No, it's comb logic in @(*).
                // We need to store it in a temporary or update the output reg.
                // Let's rely on the sequential block to update the output based on state.
                // We will set a flag 'update_output'.
                // Or simply: keep 'binary_str' as an output reg, and update it in the sequential block
                // when state==DONE.
                // To do that, the combinational block doesn't need to touch binary_str.
                // The DONE state just stays there.
                
                // Wait, we need to ensure we don't leave CALCULATE loop.
                // If quotient is 1, we set next_state = DONE.
                // What if quotient is 0 entering CALCULATE? (Should not happen due to IDLE logic).
                
                // For the '16 cycles' requirement. 
                // 16 bits max. 16 iterations. 
                // We need to finish. 
                
                done_reg_next = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Sequential block for registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            quotient <= 16'b0;
            count <= 4'b0;
            shift_reg <= 80'b0;
            length_reg <= 4'b0;
            done_reg <= 1'b0;
            binary_str <= 80'h30303030303030303030; // ASCII '0' * 10
            length <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            quotient <= quotient_next;
            count <= count_next;
            shift_reg <= shift_reg_next;
            length_reg <= length_reg_next;
            done_reg <= done_reg_next;

            // Output logic updates
            // Only update outputs when entering or in DONE state to hold values stable.
            // Or just update them when the conversion is valid.
            if (state == DONE && next_state == DONE) begin
                // We are finishing calculation. Convert bits to ASCII.
                // We have 'count' bits in 'shift_reg[15:0]'.
                // 'shift_reg' actually holds bits in indices 0 to count-1.
                // MSB is at index 'count-1'.
                
                length <= count;
                done <= 1'b1;
                
                // Generate string
                for (integer i = 0; i < 10; i = i + 1) begin
                    if (i < count) begin
                        // i=0 is MSB. Index in shift_reg = count - 1 - i
                        if (shift_reg[count - 1 - i] == 1'b1) begin
                            binary_str[(79 - 8*i) -: 8] <= 8'h31;
                        end else begin
                            binary_str[(79 - 8*i) -: 8] <= 8'h30;
                        end
                    end else begin
                        // Padding right with zeros
                        binary_str[(79 - 8*i) -: 8] <= 8'h30;
                    end
                end
            end else if (state == CALCULATE && next_state == DONE) begin
                // This handles the case where we transition to DONE in the same clock edge.
                // We need to capture the last bit.
                // The comb logic updated shift_reg_next and count_next.
                // We should use those values for conversion.
                // But in sequential block, 'shift_reg' is updated from 'shift_reg_next' at the edge.
                // So 'shift_reg' holds the new value.
                // 'count' holds the new value.
                // So we can just use 'shift_reg' and 'count'.
                
                length <= count_next;
                done <= 1'b1;
                
                for (integer i = 0; i < 10; i = i + 1) begin
                    if (i < count_next) begin
                        if (shift_reg_next[count_next - 1 - i] == 1'b1) begin
                            binary_str[(79 - 8*i) -: 8] <= 8'h31;
                        end else begin
                            binary_str[(79 - 8*i) -: 8] <= 8'h30;
                        end
                    end else begin
                        binary_str[(79 - 8*i) -: 8] <= 8'h30;
                    end
                end
            end else if (state == IDLE && next_state == DONE) begin
                 // Input was 0 case
                 length <= 4'd1;
                 done <= 1'b1;
                 binary_str <= 80'h30303030303030303030; // All '0'. But input 0 is '0' (len 1).
                 // The requirement: "Output format: Left-aligned... padded with zeros on right"
                 // Example 0: '0'.
                 // My loop above would produce '0' followed by '00...' if we just iterate.
                 // Wait, 0 is special. It has length 1. So only the first char is '0', rest are padding.
                 // My logic: i=0 < 1 -> shift_reg[0] is 0 -> '0'.
                 // i=1 >= 1 -> Padding -> '0'.
                 // This produces '0000000000'.
                 // Wait. The example "8 -> 1000000000" suggests the '1' is at the LEFT.
                 // And padding is at the RIGHT.
                 // So for '0', length=1. It should be '0' + padding.
                 // So '0000000000'.
                 // But usually '0' is just '0'.
                 // "Output format: Left-aligned in 10-character field, padded with zeros on right"
                 // This implies the field is 10 chars. So '0' is '0000000000'.
                 // But the example 8 is '1000000000'.
                 // Wait, '1000000000' is 10 chars.
                 // 8 -> binary 1000. Length 4. String '1000' + 6 zeros = '1000000000'.
                 // So yes, full 10 chars.
                 // So 0 -> '0000000000'.
                 // However, the prompt says "Example: 8 -> '1000000000' (length=4)".
                 // And "Edge case: Input 0 (binary: 0, length: 1)". 
                 // It doesn't explicitly give the string for 0.
                 // If it's '0' length 1, it might mean just '0'. 
                 // But "10-character field" strongly suggests 10 chars.
                 // Let's assume 10 chars. If they want exactly '0', they will need to slice it.
                 // I'll stick to the "10-character field" rule. 
                 // Actually, looking at the examples, they all have 10 chars in the output string.
                 // So 0 should be 10 chars.
                 // So '0000000000' is correct.
                 // But wait, length=1. 
                 // If I use the logic from above: 
                 // i=0 -> i<1 -> shift_reg[0] -> '0'.
                 // i=1..9 -> padding -> '0'.
                 // Result: '0000000000'.
                 // Okay.
                 // But wait, the prompt says "Example: 8 -> '1000000000' (length=4)". 
                 // This is 10 chars.
                 // So for 0, I will generate '0000000000'.
                 // Wait, if length is 1, and it's left aligned.
                 // It is '0' followed by zeros.
                 // So '0000000000'.
                 // Okay.
                 
                 // Reset Logic: The sequential block already handles reset.
            end else if (state == IDLE) begin
                // Reset outputs in IDLE? Or hold? 
                // Usually we hold until new start.
                // But the module is 'done' when finished.
                // If we go back to IDLE (start low), done should go low.
                if (!start) begin
                    done <= 1'b0;
                end
            end
        end
    end

endmodule
