module mirror_word_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] char_data [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPARE   = 3'd1;
    localparam [2:0] VALIDATE  = 3'd2;
    localparam [2:0] RESULT    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] index;           // Current index for comparison/validation
    reg [7:0] char_left;       // Left character for comparison
    reg [7:0] char_right;      // Right character for comparison
    reg [7:0] current_char;    // Current character for validation
    reg is_valid_char;         // Flag for character validity
    reg is_palindrome;         // Flag for palindrome check
    reg [5:0] cycle_count;     // Prevent infinite loops
    localparam [5:0] MAX_CYCLES = 6'd32;

    // Internal wire for character validity check (combinational)
    wire valid_check;
    assign valid_check = (
        current_char == 8'd65 ||   // 'A'
        current_char == 8'd72 ||   // 'H'
        current_char == 8'd73 ||   // 'I'
        current_char == 8'd77 ||   // 'M'
        current_char == 8'd79 ||   // 'O'
        current_char == 8'd84 ||   // 'T'
        current_char == 8'd85 ||   // 'U'
        current_char == 8'd86 ||   // 'V'
        current_char == 8'd87 ||   // 'W'
        current_char == 8'd88 ||   // 'X'
        current_char == 8'd89      // 'Y'
    );

    // Sequential logic for state transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            char_left <= 8'd0;
            char_right <= 8'd0;
            current_char <= 8'd0;
            is_valid_char <= 1'b0;
            is_palindrome <= 1'b1;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            
            // Default values for combinational logic can be handled here or in combinational block
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    is_palindrome <= 1'b1; // Start assuming it is a palindrome
                    if (start) begin
                        index <= 4'd0;
                        // Initial setup for first comparison if length > 0
                        if (len > 4'd0) begin
                            char_left <= char_data[0];
                            char_right <= char_data[len - 1];
                            current_char <= char_data[0]; // Start validation at index 0
                        end else begin
                            // Edge case: len 0 (though spec says 1-16, handle gracefully)
                            current_char <= 8'd0;
                        end
                    end
                end
                COMPARE: begin
                    // Check if characters match
                    if (char_left != char_right) begin
                        is_palindrome <= 1'b0;
                    end
                    // Increment index
                    index <= index + 4'd1;
                    // Setup next pair if we haven't reached the middle
                    // Logic handled in combinational block next_state logic for correct indexing
                end
                VALIDATE: begin
                    // Update validity flag. If we ever see an invalid char, result stays 0.
                    // Since we need to check ALL valid chars, we only clear if invalid is found.
                    if (!valid_check) begin
                        is_valid_char <= 1'b0;
                    end
                    index <= index + 4'd1;
                    // Setup next char for validation
                    // Logic handled in combinational block
                end
                RESULT: begin
                    // Determine final result based on flags
                    if (is_palindrome && is_valid_char) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase

            // Cycle counter for safety
            if (start) begin
                cycle_count <= 6'd0;
            end else if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 6'd1;
            end
        end
    end

    // Combinational logic for next state and data setup
    always @(*) begin
        next_state = state; // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (len == 4'd1) begin
                        // Special case: single char, skip compare, go straight to validate
                        next_state = VALIDATE;
                        index = 4'd0;
                        current_char = char_data[0];
                    end else if (len > 4'd0) begin
                        next_state = COMPARE;
                        index = 4'd0;
                        char_left = char_data[0];
                        char_right = char_data[len - 1];
                    end else begin
                        // len is 0 (edge case)
                        next_state = FINISH;
                    end
                end
            end

            COMPARE: begin
                // We just performed comparison for index 'index'
                // We need to compare up to (len/2) - 1
                // If (index + 1) >= (len >> 1), we are done with compare phase
                // However, since 'index' was incremented in sequential logic for the CURRENT state,
                // we check condition based on the incremented value.
                
                // Check if we have reached the middle for comparison
                // Note: logic depends on previous index (index - 1 after increment)
                // Let's look at the incremented index. If we just did 'i', the next loop will do 'i+1'.
                // Stop when i >= (len >> 1).
                
                // Correct logic:
                // Current 'index' (in this block, it's already incremented) represents the NEXT index to process.
                // Actually, wait. The sequential block increments index at the END of COMPARE state.
                // So when we enter COMPARE state, 'index' is the index we are ABOUT to compare.
                
                // Let's re-evaluate:
                // IDLE sets index=0. Enters COMPARE. Sequential block sees COMPARE and increments index to 1.
                // Wait, standard FSM design: Sequential block updates registers. Combinational block determines next state.
                // Let's assume the code in the sequential block is correct.
                // In IDLE: index=0. Char_left=0, Char_right=len-1.
                // Enter COMPARE state.
                // Sequential block (COMPARE): Checks char_left vs char_right. Increments index to 1.
                // Combinational block (COMPARE): Checks if (index) >= (len >> 1). Since index is now 1.
                
                // If len=4, indices 0,1. len>>1=2. 0<2, 1<2. Stop when index>=2.
                // If len=5, indices 0,1. len>>1=2. 0<2, 1<2. Stop when index>=2.
                
                // Logic for next comparison setup:
                // If index < (len >> 1), we need to fetch next chars.
                if (index < (len >> 1)) begin
                    char_left = char_data[index];
                    char_right = char_data[len - 1 - index];
                    next_state = COMPARE;
                end else begin
                    // Comparison phase done. Move to Validation.
                    // Reset index for validation phase
                    index = 4'd0;
                    current_char = char_data[0];
                    is_valid_char = 1'b1; // Assume valid until proven otherwise
                    next_state = VALIDATE;
                end
            end

            VALIDATE: begin
                // Sequential block increments index.
                // We need to validate indices 0 to len-1.
                // Logic for next validation setup:
                // If index < len, we need to fetch next char.
                
                // If len=0 (handled in IDLE), we shouldn't be here.
                
                if (index < len) begin
                    current_char = char_data[index];
                    next_state = VALIDATE;
                end else begin
                    // Validation phase done. Move to Result calculation.
                    next_state = RESULT;
                end
            end

            RESULT: begin
                // Just a cycle to latch the result value
                next_state = FINISH;
            end

            FINISH: begin
                // One cycle for done signal
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        // Safety timeout override
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = RESULT; // Force result state
        end
    end

endmodule