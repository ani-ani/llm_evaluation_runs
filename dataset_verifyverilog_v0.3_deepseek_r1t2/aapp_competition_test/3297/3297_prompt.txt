module cryptarithm_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] puzzle_char,  // Current character from puzzle string
    input puzzle_valid,       // Valid character flag
    output reg [7:0] result_char,  // Result character
    output reg result_valid,  // Valid result character
    output reg done,          // Computation complete
    output reg impossible     // No solution found
);

// Parameters
parameter MAX_PUZZLE_LEN = 20;
parameter MAX_LETTERS = 8;
parameter CLK_TIMEOUT = 10000;

// States
parameter IDLE = 0;
parameter PARSE = 1;
parameter SOLVE = 2;
parameter OUTPUT = 3;
parameter DONE = 4;

// Registers
reg [3:0] state, next_state;
reg [7:0] puzzle [0:MAX_PUZZLE_LEN-1];  // Stored puzzle
reg [5:0] puzzle_len;  // Actual puzzle length
reg [7:0] letters [0:MAX_LETTERS-1];  // Distinct letters found
reg [3:0] letter_count;  // Number of distinct letters
reg [3:0] leading_letters [0:MAX_LETTERS-1];  // Flags for leading positions
reg [3:0] current_letter_idx;
reg [3:0] digit_assignment [0:MAX_LETTERS-1];  // Current digit assignment
reg [3:0] output_idx;
reg [31:0] timeout_counter;

// Wires
wire [3:0] letter_pos;
wire [7:0] char_in;

assign char_in = puzzle_char;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        puzzle_len <= 0;
        letter_count <= 0;
        current_letter_idx <= 0;
        output_idx <= 0;
        result_valid <= 0;
        done <= 0;
        impossible <= 0;
        timeout_counter <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    puzzle_len <= 0;
                    letter_count <= 0;
                    current_letter_idx <= 0;
                    output_idx <= 0;
                    result_valid <= 0;
                    done <= 0;
                    impossible <= 0;
                    timeout_counter <= 0;
                end
            end
            
            PARSE: begin
                if (puzzle_valid && puzzle_len < MAX_PUZZLE_LEN) begin
                    puzzle[puzzle_len] <= puzzle_char;
                    puzzle_len <= puzzle_len + 1;
                    
                    // Check if character is a letter (A-Z)
                    if (puzzle_char >= 8'h41 && puzzle_char <= 8'h5A) begin
                        // Check if letter already exists
                        if (letter_count == 0) begin
                            letters[0] <= puzzle_char;
                            letter_count <= 1;
                        end else begin
                            // Simple search - limited to small number of letters
                            reg found = 0;
                            for (integer i = 0; i < letter_count; i = i + 1) begin
                                if (letters[i] == puzzle_char) begin
                                    found = 1;
                                end
                            end
                            if (!found && letter_count < MAX_LETTERS) begin
                                letters[letter_count] <= puzzle_char;
                                letter_count <= letter_count + 1;
                            end
                        end
                    end
                end
            end
            
            SOLVE: begin
                timeout_counter <= timeout_counter + 1;
                
                // Generate next digit assignment and check validity
                if (current_letter_idx < letter_count) begin
                    // Try next digit for current letter
                    if (digit_assignment[current_letter_idx] < 9) begin
                        digit_assignment[current_letter_idx] <= digit_assignment[current_letter_idx] + 1;
                    end else begin
                        digit_assignment[current_letter_idx] <= 0;
                        current_letter_idx <= current_letter_idx + 1;
                    end
                end
            end
            
            OUTPUT: begin
                if (output_idx < puzzle_len) begin
                    result_valid <= 1;
                    output_idx <= output_idx + 1;
                    
                    // Output digit or operator
                    if (puzzle[output_idx] >= 8'h41 && puzzle[output_idx] <= 8'h5A) begin
                        // Find which letter this is
                        for (integer i = 0; i < letter_count; i = i + 1) begin
                            if (letters[i] == puzzle[output_idx]) begin
                                result_char <= 8'h30 + digit_assignment[i];  // Convert to ASCII digit
                            end
                        end
                    end else begin
                        // Keep operator
                        result_char <= puzzle[output_idx];
                    end
                end else begin
                    result_valid <= 0;
                end
            end
            
            DONE: begin
                done <= 1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) next_state = PARSE;
        end
        
        PARSE: begin
            if (!puzzle_valid || puzzle_len >= MAX_PUZZLE_LEN) begin
                if (letter_count > 0 && letter_count <= MAX_LETTERS)
                    next_state = SOLVE;
                else
                    next_state = DONE;
            end
        end
        
        SOLVE: begin
            // Check if solution found or timeout
            if (timeout_counter >= CLK_TIMEOUT) begin
                next_state = DONE;
            end else if (check_solution()) begin
                next_state = OUTPUT;
            end else if (all_assignments_tried()) begin
                next_state = DONE;
            end
        end
        
        OUTPUT: begin
            if (output_idx >= puzzle_len) begin
                next_state = DONE;
            end
        end
        
        DONE: begin
            next_state = IDLE;
        end
    endcase
end

// Helper function to check if current assignment is valid
function reg check_solution();
    reg valid = 1;
    reg [7:0] num1 = 0, num2 = 0, num3 = 0;
    reg [7:0] current_num = 0;
    reg in_num1 = 1, in_num2 = 0, in_num3 = 0;
    integer i;
    
    begin
        // Check leading zeros
        for (i = 0; i < letter_count; i = i + 1) begin
            if (leading_letters[i] && digit_assignment[i] == 0) begin
                valid = 0;
            end
        end
        
        if (valid) begin
            // Convert words to numbers
            for (i = 0; i < puzzle_len; i = i + 1) begin
                if (puzzle[i] == 8'h2B) begin  // '+'
                    if (in_num1) begin
                        num1 = current_num;
                        current_num = 0;
                        in_num1 = 0;
                        in_num2 = 1;
                    end else begin
                        valid = 0;
                    end
                end else if (puzzle[i] == 8'h3D) begin  // '='
                    if (in_num2) begin
                        num2 = current_num;
                        current_num = 0;
                        in_num2 = 0;
                        in_num3 = 1;
                    end else begin
                        valid = 0;
                    end
                end else if (puzzle[i] >= 8'h41 && puzzle[i] <= 8'h5A) begin
                    // Find digit for this letter
                    reg found = 0;
                    reg [3:0] digit = 0;
                    for (integer j = 0; j < letter_count; j = j + 1) begin
                        if (letters[j] == puzzle[i]) begin
                            digit = digit_assignment[j];
                            found = 1;
                        end
                    end
                    if (found) begin
                        current_num = current_num * 10 + digit;
                    end else begin
                        valid = 0;
                    end
                end else begin
                    valid = 0;  // Invalid character
                end
            end
            
            if (in_num3) begin
                num3 = current_num;
            end
            
            // Check equation
            if (valid && (num1 + num2 != num3)) begin
                valid = 0;
            end
        end
        
        return valid;
    end
endfunction

// Helper function to check if all assignments tried
function reg all_assignments_tried();
    begin
        all_assignments_tried = 1;
        for (integer i = 0; i < letter_count; i = i + 1) begin
            if (digit_assignment[i] != 9) begin
                all_assignments_tried = 0;
            end
        end
        // If all are 9, we've tried all possibilities
        if (all_assignments_tried) begin
            impossible = 1;
        end
    end
endfunction

endmodule