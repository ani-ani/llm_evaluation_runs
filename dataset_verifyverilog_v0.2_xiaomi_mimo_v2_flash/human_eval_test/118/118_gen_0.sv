module closest_vowel(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] word,
    output reg [7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [2:0] index; // 0 to 7
    reg [2:0] next_index;

    // Helper logic to check vowel/consonant status of current and neighbors
    // Using wires for combinational checks makes the FSM logic cleaner
    wire current_is_vowel;
    wire left_is_consonant;
    wire right_is_consonant;
    wire is_vowel_char;
    wire is_consonant_char;

    // Function to check if a char is a vowel (a,e,i,o,u upper/lower)
    assign is_vowel_char = (
        (word[index] == 8'h61) || (word[index] == 8'h41) || // a, A
        (word[index] == 8'h65) || (word[index] == 8'h45) || // e, E
        (word[index] == 8'h69) || (word[index] == 8'h49) || // i, I
        (word[index] == 8'h6F) || (word[index] == 8'h4F) || // o, O
        (word[index] == 8'h75) || (word[index] == 8'h55)    // u, U
    );

    // Function to check if a char is a consonant (A-Z or a-z but not vowel)
    // A char is a consonant if it is an English letter (A-Z or a-z) and NOT a vowel.
    wire [7:0] char_left = (index > 0) ? word[index - 1] : 8'h00;
    wire [7:0] char_right = (index < 7) ? word[index + 1] : 8'h00;

    // Helper logic for neighbors
    wire left_is_letter;
    wire right_is_letter;
    wire left_is_vowel;
    wire right_is_vowel;

    // Check if input is ASCII letter A-Z (0x41-0x5A) or a-z (0x61-0x7A)
    wire is_letter_left = (char_left >= 8'h41 && char_left <= 8'h5A) || (char_left >= 8'h61 && char_left <= 8'h7A);
    wire is_letter_right = (char_right >= 8'h41 && char_right <= 8'h5A) || (char_right >= 8'h61 && char_right <= 8'h7A);
    
    // Check if neighbors are vowels
    wire is_vowel_left = (
        (char_left == 8'h61) || (char_left == 8'h41) ||
        (char_left == 8'h65) || (char_left == 8'h45) ||
        (char_left == 8'h69) || (char_left == 8'h49) ||
        (char_left == 8'h6F) || (char_left == 8'h4F) ||
        (char_left == 8'h75) || (char_left == 8'h55)
    );
    wire is_vowel_right = (
        (char_right == 8'h61) || (char_right == 8'h41) ||
        (char_right == 8'h65) || (char_right == 8'h45) ||
        (char_right == 8'h69) || (char_right == 8'h49) ||
        (char_right == 8'h6F) || (char_right == 8'h4F) ||
        (char_right == 8'h75) || (char_right == 8'h55)
    );

    // Definition of Consonant: English letter AND NOT Vowel
    assign left_is_consonant = is_letter_left && !is_vowel_left;
    assign right_is_consonant = is_letter_right && !is_vowel_right;
    
    // Definition of Vowel: Is a vowel character
    assign current_is_vowel = is_vowel_char;

    // State Register & Data Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 8'h00;
            done <= 1'b0;
            index <= 3'd7;
        end else begin
            current_state <= next_state;
            index <= next_index;
            // Update result only when a match is found (transitioning to FINISH)
            // Or reset result when starting new scan
            if (start && current_state == IDLE) result <= 8'h00;
            else if (next_state == FINISH && current_state == SCAN) begin
                result <= word[index];
            end
            
            // Done signal handling
            if (start && current_state == IDLE) done <= 1'b0;
            else if (next_state == FINISH) done <= 1'b1;
        end
    end

    // Next State Logic
    always @(*) begin
        // Defaults
        next_state = current_state;
        next_index = index;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                    next_index = 3'd6; // Start checking index 6 (needs 7 and 5 valid)
                end
            end

            SCAN: begin
                // Check validity of current index
                // We need to check: current is vowel, left is cons, right is cons.
                // Valid indices are 1 through 6 inclusive (since index 0 has no right neighbor index -1,
                // and index 7 has no right neighbor index 8).
                // Our loop starts at 6. 
                
                if (index < 3'd1) begin
                    // Reached end of valid scan range without finding match
                    next_state = FINISH;
                end else begin
                    // Perform Check
                    if (current_is_vowel && left_is_consonant && right_is_consonant) begin
                        // Match found at current index
                        next_state = FINISH;
                    end else begin
                        // No match, move left
                        if (index > 0) next_index = index - 1;
                        else next_index = 3'd0; // Safety, though index < 1 handles this
                    end
                end
            end

            FINISH: begin
                // Wait for reset or start to go back to IDLE
                if (start) begin
                    next_state = SCAN;
                    next_index = 3'd6;
                end else begin
                    next_state = FINISH;
                end
            end

            default: begin
                next_state = IDLE;
                next_index = 3'd7;
            end
        endcase
    end

endmodule