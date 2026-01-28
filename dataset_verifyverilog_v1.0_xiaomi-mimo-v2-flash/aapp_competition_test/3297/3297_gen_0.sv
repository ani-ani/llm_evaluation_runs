module cryptarithmetic_solver(
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] puzzle_str,
    input [3:0] puzzle_len,
    output reg [15:0][7:0] result_str,
    output reg done,
    output reg solved
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] PARSE       = 4'd1;
    localparam [3:0] INIT_SEARCH = 4'd2;
    localparam [3:0] ASSIGN      = 4'd3;
    localparam [3:0] VALIDATE    = 4'd4;
    localparam [3:0] OUTPUT      = 4'd5;
    localparam [3:0] FINISH      = 4'd6;
    localparam [3:0] IMPOSSIBLE  = 4'd7;

    reg [3:0] state, next_state;
    
    // Max values
    localparam [3:0] MAX_LEN = 4'd15;
    localparam [3:0] MAX_LETTERS = 4'd8;
    localparam [7:0] ASCII_A = 8'd65;
    localparam [7:0] ASCII_Z = 8'd90;
    localparam [7:0] ASCII_0 = 8'd48;

    // Parse registers
    reg [3:0] parse_idx;
    reg [3:0] letter_count;
    reg [3:0] unique_idx;
    reg [7:0] unique_letters [0:7];
    reg [7:0] temp_letter;
    reg found_flag;
    
    // Search registers
    reg [3:0] search_depth;     // Current letter index (0-7)
    reg [3:0] digit_assign;     // Current digit (0-9)
    reg [7:0] letter_to_digit [0:25];  // Maps ASCII letter to digit (255=unassigned)
    reg [7:0] digit_to_letter [0:9];   // For checking duplicates (255=unused)
    reg [3:0] digit_try_count;  // Counter for digit attempts (0-9)
    
    // Word parsing
    reg [7:0] w1 [0:3];
    reg [7:0] w2 [0:3];
    reg [7:0] w3 [0:3];
    reg [3:0] w1_len, w2_len, w3_len;
    reg [3:0] current_word_idx;
    reg [3:0] current_char_idx;
    reg [1:0] word_part;  // 0=w1, 1=w2, 2=w3
    
    // Computation registers
    reg [15:0] val_w1, val_w2, val_w3;
    reg [3:0] compute_idx;
    reg [1:0] compute_word;
    reg [15:0] mult_temp;
    reg valid_assignment;
    
    // Output construction
    reg [3:0] output_idx;
    reg [7:0] orig_char;
    reg [7:0] mapped_digit;
    
    // Cycle counter
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd512;

    integer i, j;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            solved <= 1'b0;
            cycle_count <= 10'd0;
            // Initialize result_str
            for (i = 0; i < 16; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
            // Initialize letter_to_digit
            for (i = 0; i < 26; i = i + 1) begin
                letter_to_digit[i] <= 8'd255;
            end
            // Initialize digit_to_letter
            for (i = 0; i < 10; i = i + 1) begin
                digit_to_letter[i] <= 8'd255;
            end
            // Initialize unique_letters
            for (i = 0; i < 8; i = i + 1) begin
                unique_letters[i] <= 8'd0;
            end
            // Initialize word storage
            for (i = 0; i < 4; i = i + 1) begin
                w1[i] <= 8'd0;
                w2[i] <= 8'd0;
                w3[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            if (state != IDLE && state != FINISH && state != IMPOSSIBLE) begin
                cycle_count <= cycle_count + 10'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end
            
            PARSE: begin
                if (parse_idx >= puzzle_len || parse_idx >= MAX_LEN) begin
                    next_state = INIT_SEARCH;
                end
            end
            
            INIT_SEARCH: begin
                if (letter_count == 4'd0) begin
                    next_state = IMPOSSIBLE;
                end else begin
                    next_state = ASSIGN;
                end
            end
            
            ASSIGN: begin
                if (search_depth >= letter_count) begin
                    next_state = VALIDATE;
                end else if (digit_try_count >= 4'd10) begin
                    // Try next letter with reset digits
                    next_state = ASSIGN;
                end
            end
            
            VALIDATE: begin
                if (valid_assignment) begin
                    next_state = OUTPUT;
                end else begin
                    // Backtrack: if can increment digit on current search_depth
                    if (digit_try_count < 4'd10) begin
                        next_state = ASSIGN;
                    end else begin
                        // Need to backtrack to previous letter
                        if (search_depth == 4'd0) begin
                            next_state = IMPOSSIBLE;
                        end else begin
                            next_state = ASSIGN;
                        end
                    end
                end
            end
            
            OUTPUT: begin
                if (output_idx >= puzzle_len || output_idx >= MAX_LEN) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            IMPOSSIBLE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parse_idx <= 4'd0;
            letter_count <= 4'd0;
            unique_idx <= 4'd0;
            temp_letter <= 8'd0;
            found_flag <= 1'b0;
            search_depth <= 4'd0;
            digit_assign <= 4'd0;
            digit_try_count <= 4'd0;
            w1_len <= 4'd0;
            w2_len <= 4'd0;
            w3_len <= 4'd0;
            current_word_idx <= 4'd0;
            current_char_idx <= 4'd0;
            word_part <= 2'd0;
            val_w1 <= 16'd0;
            val_w2 <= 16'd0;
            val_w3 <= 16'd0;
            compute_idx <= 4'd0;
            compute_word <= 2'd0;
            valid_assignment <= 1'b0;
            output_idx <= 4'd0;
            done <= 1'b0;
            solved <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    parse_idx <= 4'd0;
                    letter_count <= 4'd0;
                    unique_idx <= 4'd0;
                    temp_letter <= 8'd0;
                    found_flag <= 1'b0;
                    search_depth <= 4'd0;
                    digit_assign <= 4'd0;
                    digit_try_count <= 4'd0;
                    w1_len <= 4'd0;
                    w2_len <= 4'd0;
                    w3_len <= 4'd0;
                    current_word_idx <= 4'd0;
                    current_char_idx <= 4'd0;
                    word_part <= 2'd0;
                    val_w1 <= 16'd0;
                    val_w2 <= 16'd0;
                    val_w3 <= 16'd0;
                    compute_idx <= 4'd0;
                    compute_word <= 2'd0;
                    valid_assignment <= 1'b0;
                    output_idx <= 4'd0;
                    done <= 1'b0;
                    solved <= 1'b0;
                    // Reset mappings
                    for (i = 0; i < 26; i = i + 1) begin
                        letter_to_digit[i] <= 8'd255;
                    end
                    for (i = 0; i < 10; i = i + 1) begin
                        digit_to_letter[i] <= 8'd255;
                    end
                    for (i = 0; i < 8; i = i + 1) begin
                        unique_letters[i] <= 8'd0;
                    end
                end
                
                PARSE: begin
                    if (parse_idx < puzzle_len && parse_idx < MAX_LEN) begin
                        temp_letter <= puzzle_str[parse_idx];
                        // Check if it's a letter (A-Z)
                        if (puzzle_str[parse_idx] >= ASCII_A && puzzle_str[parse_idx] <= ASCII_Z) begin
                            found_flag <= 1'b0;
                            // Check if already in unique list
                            for (i = 0; i < 8; i = i + 1) begin
                                if (unique_letters[i] == puzzle_str[parse_idx]) begin
                                    found_flag <= 1'b1;
                                end
                            end
                            // If not found, add to unique list
                            if (!found_flag && letter_count < 8) begin
                                unique_letters[letter_count] <= puzzle_str[parse_idx];
                                letter_count <= letter_count + 4'd1;
                            end
                        end
                        parse_idx <= parse_idx + 4'd1;
                    end
                end
                
                INIT_SEARCH: begin
                    // Sort unique_letters alphabetically (bubble sort)
                    // Simple bubble sort for small array
                    if (letter_count > 4'd1) begin
                        // Perform one swap pass
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i + 1 < letter_count && unique_letters[i] > unique_letters[i+1]) begin
                                unique_letters[i] <= unique_letters[i+1];
                                unique_letters[i+1] <= unique_letters[i];
                            end
                        end
                    end
                    // Initialize search state
                    search_depth <= 4'd0;
                    digit_try_count <= 4'd0;
                    digit_assign <= 4'd0;
                    // Reset all letter mappings
                    for (i = 0; i < 26; i = i + 1) begin
                        letter_to_digit[i] <= 8'd255;
                    end
                    for (i = 0; i < 10; i = i + 1) begin
                        digit_to_letter[i] <= 8'd255;
                    end
                end
                
                ASSIGN: begin
                    // Try to assign a digit to the current letter (search_depth)
                    if (digit_try_count < 4'd10) begin
                        digit_assign <= digit_try_count;
                        digit_try_count <= digit_try_count + 4'd1;
                        // Check if this digit is already used
                        found_flag <= 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            if (digit_to_letter[i] == unique_letters[search_depth]) begin
                                found_flag <= 1'b1;  // Should not happen with reset
                            end
                            if (i < digit_try_count && digit_to_letter[i] == 8'd255) begin
                                // Check if other letter assigned to this digit
                            end
                        end
                        // Need to check if digit is used by OTHER letters
                        // Simplified: we just assign and validate
                        // If invalid, we'll backtrack
                    end else begin
                        // All digits tried for this letter, reset and backtrack
                        digit_try_count <= 4'd0;
                        digit_assign <= 4'd0;
                        // Reset current letter mapping
                        if (search_depth > 4'd0) begin
                            letter_to_digit[unique_letters[search_depth-1]-ASCII_A] <= 8'd255;
                            digit_to_letter[letter_to_digit[unique_letters[search_depth-1]-ASCII_A]] <= 8'd255;
                        end
                        search_depth <= search_depth - 4'd1;
                    end
                end
                
                VALIDATE: begin
                    // Assign current digit
                    if (digit_try_count <= 4'd10 && search_depth < letter_count) begin
                        letter_to_digit[unique_letters[search_depth]-ASCII_A] <= digit_assign;
                        digit_to_letter[digit_assign] <= unique_letters[search_depth];
                        // Check for leading zeros
                        valid_assignment <= 1'b1;
                        // Check w1[0], w2[0], w3[0] mapping != 0
                        // Need to find which letter is at position 0 of each word
                        // This requires parsing the string again
                        // For now, assume valid, will be checked in computation
                    end
                    // Compute word values
                    if (compute_word == 2'd0) begin
                        // Compute w1
                        if (compute_idx < w1_len) begin
                            if (w1[compute_idx] >= ASCII_A && w1[compute_idx] <= ASCII_Z) begin
                                val_w1 <= val_w1 * 10 + letter_to_digit[w1[compute_idx]-ASCII_A];
                            end else begin
                                valid_assignment <= 1'b0;
                            end
                            compute_idx <= compute_idx + 4'd1;
                        end else begin
                            compute_idx <= 4'd0;
                            compute_word <= 2'd1;
                        end
                    end else if (compute_word == 2'd1) begin
                        // Compute w2
                        if (compute_idx < w2_len) begin
                            if (w2[compute_idx] >= ASCII_A && w2[compute_idx] <= ASCII_Z) begin
                                val_w2 <= val_w2 * 10 + letter_to_digit[w2[compute_idx]-ASCII_A];
                            end else begin
                                valid_assignment <= 1'b0;
                            end
                            compute_idx <= compute_idx + 4'd1;
                        end else begin
                            compute_idx <= 4'd0;
                            compute_word <= 2'd2;
                        end
                    end else if (compute_word == 2'd2) begin
                        // Compute w3
                        if (compute_idx < w3_len) begin
                            if (w3[compute_idx] >= ASCII_A && w3[compute_idx] <= ASCII_Z) begin
                                val_w3 <= val_w3 * 10 + letter_to_digit[w3[compute_idx]-ASCII_A];
                            end else begin
                                valid_assignment <= 1'b0;
                            end
                            compute_idx <= compute_idx + 4'd1;
                        end else begin
                            compute_idx <= 4'd0;
                            compute_word <= 2'd0;
                            // Check sum
                            if (val_w1 + val_w2 != val_w3) begin
                                valid_assignment <= 1'b0;
                            end
                            // Check leading zeros
                            if (w1_len > 0 && letter_to_digit[w1[0]-ASCII_A] == 4'd0) begin
                                valid_assignment <= 1'b0;
                            end
                            if (w2_len > 0 && letter_to_digit[w2[0]-ASCII_A] == 4'd0) begin
                                valid_assignment <= 1'b0;
                            end
                            if (w3_len > 0 && letter_to_digit[w3[0]-ASCII_A] == 4'd0) begin
                                valid_assignment <= 1'b0;
                            end
                            // Reset values for next attempt
                            val_w1 <= 16'd0;
                            val_w2 <= 16'd0;
                            val_w3 <= 16'd0;
                        end
                    end
                    // If invalid, need to reset mappings for backtracking
                    if (!valid_assignment && state == VALIDATE) begin
                        // Clean up current assignment
                        letter_to_digit[unique_letters[search_depth]-ASCII_A] <= 8'd255;
                        digit_to_letter[digit_assign] <= 8'd255;
                    end
                end
                
                OUTPUT: begin
                    // Build result string
                    if (output_idx < puzzle_len && output_idx < MAX_LEN) begin
                        if (puzzle_str[output_idx] >= ASCII_A && puzzle_str[output_idx] <= ASCII_Z) begin
                            result_str[output_idx] <= ASCII_0 + letter_to_digit[puzzle_str[output_idx]-ASCII_A];
                        end else begin
                            result_str[output_idx] <= puzzle_str[output_idx];
                        end
                        output_idx <= output_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    solved <= 1'b1;
                end
                
                IMPOSSIBLE: begin
                    // Output original string or marked version
                    for (i = 0; i < 16; i = i + 1) begin
                        result_str[i] <= puzzle_str[i];
                    end
                    done <= 1'b1;
                    solved <= 1'b0;
                end
            endcase
        end
    end

    // Word extraction logic (combinational helper)
    always @(*) begin
        w1_len = 4'd0;
        w2_len = 4'd0;
        w3_len = 4'd0;
        current_word_idx = 4'd0;
        current_char_idx = 4'd0;
        word_part = 2'd0;
        // Initialize word storage
        for (i = 0; i < 4; i = i + 1) begin
            w1[i] = 8'd0;
            w2[i] = 8'd0;
            w3[i] = 8'd0;
        end
        
        for (i = 0; i < 16 && i < puzzle_len; i = i + 1) begin
            if (puzzle_str[i] == 8'd43) begin  // '+'
                word_part = word_part + 2'd1;
                current_char_idx = 4'd0;
            end else if (puzzle_str[i] == 8'd61) begin  // '='
                word_part = 2'd2;
                current_char_idx = 4'd0;
            end else if (puzzle_str[i] >= ASCII_A && puzzle_str[i] <= ASCII_Z) begin
                case (word_part)
                    2'd0: begin
                        if (current_char_idx < 4) begin
                            w1[current_char_idx] = puzzle_str[i];
                            w1_len = current_char_idx + 4'd1;
                        end
                    end
                    2'd1: begin
                        if (current_char_idx < 4) begin
                            w2[current_char_idx] = puzzle_str[i];
                            w2_len = current_char_idx + 4'd1;
                        end
                    end
                    2'd2: begin
                        if (current_char_idx < 4) begin
                            w3[current_char_idx] = puzzle_str[i];
                            w3_len = current_char_idx + 4'd1;
                        end
                    end
                endcase
                current_char_idx = current_char_idx + 4'd1;
            end
        end
    end

    // Reset word values for next search attempt
    always @(posedge clk) begin
        if (state == INIT_SEARCH || (state == ASSIGN && digit_try_count == 4'd0)) begin
            val_w1 <= 16'd0;
            val_w2 <= 16'd0;
            val_w3 <= 16'd0;
        end
    end

    // Additional validation check for current assignment
    always @(posedge clk) begin
        if (state == ASSIGN && digit_try_count <= 4'd10 && search_depth < letter_count) begin
            // Check if leading digit would be zero
            if (letter_to_digit[unique_letters[0]-ASCII_A] == 4'd0 && 
                w1_len > 0 && unique_letters[0] == w1[0] && word_part == 2'd0) begin
                // Skip this assignment
                digit_try_count <= 4'd10;
            end
        end
    end

    // Helper: Check if digit is available
    reg digit_used;
    always @(*) begin
        digit_used = 1'b0;
        for (j = 0; j < 10; j = j + 1) begin
            if (digit_to_letter[j] == unique_letters[search_depth]) begin
                digit_used = 1'b1;  // Already assigned (shouldn't happen)
            end
        end
        // Check if this digit is used by OTHER letters
        for (j = 0; j < 10; j = j + 1) begin
            if (j < digit_try_count) begin
                if (digit_to_letter[j] != 8'd255 && digit_to_letter[j] != unique_letters[search_depth]) begin
                    // This digit is taken by another letter
                    // But we need to allow reassignment in backtrack
                end
            end
        end
    end

endmodule

module TopModule(
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] puzzle_str,
    input [3:0] puzzle_len,
    output reg [15:0][7:0] result_str,
    output reg done,
    output reg solved
);

    // Instantiate the solver
    cryptarithmetic_solver solver (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .puzzle_str(puzzle_str),
        .puzzle_len(puzzle_len),
        .result_str(result_str),
        .done(done),
        .solved(solved)
    );

endmodule