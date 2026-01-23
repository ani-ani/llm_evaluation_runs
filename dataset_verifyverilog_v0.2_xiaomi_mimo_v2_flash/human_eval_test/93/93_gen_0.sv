module message_encoder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] message_in,
    input wire [7:0] valid_length,
    output reg [127:0] message_out,
    output reg done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        PROCESSING = 2'b01,
        DONE = 2'b10
    } state_t;
    
    reg [1:0] current_state, next_state;
    reg [3:0] count, next_count; // Counts 0 to 15 (16 positions)
    reg [127:0] next_message_out;
    reg next_done;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 4'd0;
            message_out <= 128'h0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            count <= next_count;
            message_out <= next_message_out;
            done <= next_done;
        end
    end

    // Next state logic and Output logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_count = count;
        next_message_out = message_out;
        next_done = done;

        case (current_state)
            IDLE: begin
                next_done = 1'b0;
                next_count = 4'd0;
                next_message_out = message_out; // Keep previous result
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Process current character
                // Extract current byte from message_in based on count
                // message_in[127:0] where index 0 is LSB, corresponding to first char if we map byte i to [7+8*i : 8*i]
                // Or let's assume message_in[7:0] is char 0, message_in[15:8] is char 1, etc.
                // Standard Verilog concatenation: {char15, ..., char0} where char0 is LSB
                // Input format: message_in[127:0] is 16 characters.
                // Let's assume index 0 (LSB) is the first character of the string.
                
                // Fetch byte
                // Logic for extracting byte i: message_in[8*i +: 8]
                // If i=0: [7:0]. If i=1: [15:8].
                logic [7:0] char_in;
                char_in = message_in[8*count +: 8];
                
                // Transformation Logic
                logic [7:0] char_out;
                char_out = char_in; // Default
                
                // Check if letter
                if ((char_in >= 8'h41 && char_in <= 8'h5A) || (char_in >= 8'h61 && char_in <= 8'h7A)) begin
                    // Swap case: XOR with 0x20
                    logic [7:0] swapped;
                    swapped = char_in ^ 8'h20;
                    
                    // Check if vowel (using swapped value to check standard casing easily)
                    // Vowels: A(0x41), E(0x45), I(0x49), O(0x4F), U(0x55)
                    // Lower: a(0x61), e(0x65), i(0x69), o(0x6F), u(0x75)
                    logic is_vowel;
                    is_vowel = 1'b0;
                    case (swapped)
                        8'h41, 8'h45, 8'h49, 8'h4F, 8'h55: is_vowel = 1'b1;
                        8'h61, 8'h65, 8'h69, 8'h6F, 8'h75: is_vowel = 1'b1;
                        default: is_vowel = 1'b0;
                    endcase

                    if (is_vowel) begin
                        // Add 2 to get 2 positions ahead
                        // If input was 'A', swapped is 'A'. Output 'C' (0x41 + 2 = 0x43).
                        // If input was 'a', swapped is 'A'. Output 'c' (0x41 + 2 = 0x43, then set bit 5 for lowercase).
                        // Wait, specification says: 
                        // A/a -> C/c. 
                        // Logic: Swap first? Yes. Then shift. 
                        // Example 'a': Input 'a' (0x61). Swap -> 'A' (0x41). Add 2 -> 'C' (0x43).
                        // Result 'c' (0x63). 
                        // So: Swap, Add 2, Swap back? 
                        // Or: Swap, Add 2. 
                        // If swapped was 'A' (0x41), result 'C' (0x43). If we want lowercase output, we need bit 5 set.
                        // The example says: a->C. Wait, the description says: "Replace with letter 2 positions ahead... A/a -> C/c".
                        // If input 'a': 
                        // 1. Swap to 'A'.
                        // 2. Vowel rule: Replace with letter 2 ahead -> 'C'.
                        // 3. Result 'c'?
                        // Let's look at the example again: "a→C". Wait, usually 'a' (97) -> 'c' (99). 'A' (65) -> 'C' (67).
                        // The prompt says: "A/a → C/c". 
                        // AND "Swap case... Replace vowels...".
                        // If we follow strictly: Swap case first. 'a' -> 'A'. Vowel -> 'C'. 
                        // But the prompt says "a→C" in the replacement list. 
                        // Let's check the text: "Replace vowels with the letter 2 positions ahead in alphabet (a→C, e→G, i→K, o→Q, u→Y, and uppercase equivalents)"
        // This text implies input 'a' results in output 'C', not 'c'.
        // However, the subsequent bullet says: "Non-vowel consonants remain as swapped case letters".
        // This implies the process is: Swap, then Vowel Check.
        // If we swap 'a' to 'A', check vowel (yes), add 2 -> 'C'.
        // If we swap 'A' to 'a', check vowel (yes), add 2 -> 'c'? No, 'a' + 2 = 'c'.
        // Wait, if 'A' -> 'a', then 'a' + 2 = 'c'.
        // If 'a' -> 'A', then 'A' + 2 = 'C'.
        // So the output case depends on input case? 
        // Prompt: "Swap case... Replace vowels...".
        // Let's assume strictly: 
        // 1. Swap case of input. Let this be X.
        // 2. If X is vowel, transform X+2. 
        // 3. If input was originally lowercase, make result lowercase.
        // 
        // Let's look at the example: "a→C". Input 'a' (0x61).
        // 'a' is lower. 
        // Swap -> 'A'.
        // 'A' is vowel. 
        // 'A' + 2 = 'C' (0x43).
        // Is the output 'C' or 'c'? The text "a→C" suggests 'C'.
        // But "uppercase equivalents" suggests if input was uppercase, result is uppercase.
        // Let's verify "A/a → C/c". 
        // If input 'A': Swap -> 'a'. Add 2 -> 'c'.
        // If input 'a': Swap -> 'A'. Add 2 -> 'C'.
        // So the output case mirrors the input case.
                        
                        // Logic Implementation:
                        // 1. Determine input case (bit 5). 0 = Upper, 1 = Lower.
                        logic input_is_lower;
                        input_is_lower = char_in[5]; // 1 for lowercase
                        
                        // 2. Get the base vowel code from 'swapped' (which is uppercase if we clear bit 5, or just use it as index)
                        // 'A' is 0x41. 'a' is 0x61. 
                        // Let's add 2 to the swapped value.
                        logic [7:0] transformed;
                        transformed = swapped + 8'h02;
                        
                        // 3. Apply original case to transformed value.
                        // If input was lower, set bit 5 of transformed.
                        // If input was upper, clear bit 5.
                        // transformed[5] = input_is_lower;
                        char_out = {transformed[7:6], input_is_lower, transformed[4:0]};
                    end else begin
                        // Consonant: Keep swapped case letter
                        char_out = swapped;
                    end
                end else begin
                    // Not a letter: leave unchanged
                    char_out = char_in;
                end

                // Update output register for this position
                next_message_out[8*count +: 8] = char_out;

                // Increment counter
                if (count < 4'd15) begin
                    next_count = count + 1'b1;
                    next_state = PROCESSING; // Stay in processing
                end else begin
                    // Finished 16 characters (or once we hit 15->16? 
                    // Spec says "Process all 16 positions sequentially".
                    // Latency 17 cycles. Start=1, cycle 0. 
                    // Cycle 0: IDLE -> PROCESSING. 
                    // Cycle 1: Process 0.
                    // ... Cycle 16: Process 15.
                    // Cycle 17: DONE.
                    // So we need to process count 0 to 15.
                    // If count is 15, next state is DONE.
                    next_state = DONE;
                end
            end

            DONE: begin
                // Assert done, stay here until reset or start goes low? 
                // Usually done stays high until next start or reset.
                next_done = 1'b1;
                if (!start) begin
                    // Wait for start to go low to reset logic or wait for next start
                    // But state transition usually happens on start.
                    // Let's assume we stay in DONE until reset.
                    // To allow re-triggering, maybe we should check !start first?
                    // "Result valid 17 clock cycles after start asserted"
                    // If start is pulsed, done goes high at cycle 17.
                    // If start is held high, done stays high.
                    // Let's transition to IDLE when start goes low to prepare for next run?
                    // Or stay DONE until reset.
                    // Let's go to IDLE when start is low to allow re-triggering.
                    if (!start) begin
                        next_state = IDLE;
                        next_done = 1'b0;
                    end
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule

// Helper module not required, logic is inside.
