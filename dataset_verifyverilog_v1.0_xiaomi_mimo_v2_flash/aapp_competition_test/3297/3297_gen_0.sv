module cryptarithm_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] puzzle_char,
    input puzzle_valid,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg done,
    output reg impossible
);

// Parameters
localparam [7:0] MAX_PUZZLE_LEN = 8'd20;
localparam [7:0] MAX_LETTERS = 8'd8;
localparam [15:0] CLK_TIMEOUT = 16'd10000;

// States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PARSE = 3'd1;
localparam [2:0] SOLVE = 3'd2;
localparam [2:0] OUTPUT = 3'd3;
localparam [2:0] DONE = 3'd4;

// Registers
reg [2:0] state, next_state;
reg [7:0] puzzle [0:19];
reg [5:0] puzzle_len;
reg [7:0] letters [0:7];
reg [3:0] letter_count;
reg [7:0] digit_assignment [0:7];
reg [3:0] output_idx;
reg [15:0] timeout_counter;
reg [7:0] current_char;
reg [7:0] temp_char;

// Wires for helper functions
wire [7:0] char_in;
assign char_in = puzzle_char;

// Helper function signals
reg [7:0] num1_reg;
reg [7:0] num2_reg;
reg [7:0] num3_reg;
reg [7:0] current_num_reg;
reg valid_reg;
reg in_num1_reg;
reg in_num2_reg;
reg in_num3_reg;
reg all_tried_reg;
reg found_letter_reg;
reg [3:0] digit_idx_reg;
reg [3:0] i_reg;
reg [3:0] j_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        puzzle_len <= 6'd0;
        letter_count <= 4'd0;
        output_idx <= 4'd0;
        result_valid <= 1'b0;
        done <= 1'b0;
        impossible <= 1'b0;
        timeout_counter <= 16'd0;
        result_char <= 8'd0;
        current_char <= 8'd0;
        temp_char <= 8'd0;
        num1_reg <= 8'd0;
        num2_reg <= 8'd0;
        num3_reg <= 8'd0;
        current_num_reg <= 8'd0;
        valid_reg <= 1'b0;
        in_num1_reg <= 1'b0;
        in_num2_reg <= 1'b0;
        in_num3_reg <= 1'b0;
        all_tried_reg <= 1'b0;
        found_letter_reg <= 1'b0;
        digit_idx_reg <= 4'd0;
        i_reg <= 4'd0;
        j_reg <= 4'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    puzzle_len <= 6'd0;
                    letter_count <= 4'd0;
                    output_idx <= 4'd0;
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    impossible <= 1'b0;
                    timeout_counter <= 16'd0;
                    // Initialize all digit assignments to 0
                    for (integer i = 0; i < 8; i = i + 1) begin
                        digit_assignment[i] <= 8'd0;
                    end
                end
            end
            
            PARSE: begin
                if (puzzle_valid && puzzle_len < MAX_PUZZLE_LEN) begin
                    puzzle[puzzle_len] <= puzzle_char;
                    puzzle_len <= puzzle_len + 1;
                    
                    // Check if character is a letter (A-Z)
                    if (puzzle_char >= 8'h41 && puzzle_char <= 8'h5A) begin
                        // Check if letter already exists
                        found_letter_reg <= 1'b0;
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (i < letter_count && letters[i] == puzzle_char) begin
                                found_letter_reg <= 1'b1;
                            end
                        end
                        
                        if (!found_letter_reg && letter_count < MAX_LETTERS) begin
                            letters[letter_count] <= puzzle_char;
                            letter_count <= letter_count + 1;
                        end
                    end
                end
            end
            
            SOLVE: begin
                timeout_counter <= timeout_counter + 1;
                
                // Generate next digit assignment
                if (digit_assignment[0] < 8'd9) begin
                    digit_assignment[0] <= digit_assignment[0] + 1;
                end else begin
                    digit_assignment[0] <= 8'd0;
                    if (letter_count > 1 && digit_assignment[1] < 8'd9) begin
                        digit_assignment[1] <= digit_assignment[1] + 1;
                    end else if (letter_count > 1) begin
                        digit_assignment[1] <= 8'd0;
                        if (letter_count > 2 && digit_assignment[2] < 8'd9) begin
                            digit_assignment[2] <= digit_assignment[2] + 1;
                        end else if (letter_count > 2) begin
                            digit_assignment[2] <= 8'd0;
                            if (letter_count > 3 && digit_assignment[3] < 8'd9) begin
                                digit_assignment[3] <= digit_assignment[3] + 1;
                            end else if (letter_count > 3) begin
                                digit_assignment[3] <= 8'd0;
                                if (letter_count > 4 && digit_assignment[4] < 8'd9) begin
                                    digit_assignment[4] <= digit_assignment[4] + 1;
                                end else if (letter_count > 4) begin
                                    digit_assignment[4] <= 8'd0;
                                    if (letter_count > 5 && digit_assignment[5] < 8'd9) begin
                                        digit_assignment[5] <= digit_assignment[5] + 1;
                                    end else if (letter_count > 5) begin
                                        digit_assignment[5] <= 8'd0;
                                        if (letter_count > 6 && digit_assignment[6] < 8'd9) begin
                                            digit_assignment[6] <= digit_assignment[6] + 1;
                                        end else if (letter_count > 6) begin
                                            digit_assignment[6] <= 8'd0;
                                            if (letter_count > 7 && digit_assignment[7] < 8'd9) begin
                                                digit_assignment[7] <= digit_assignment[7] + 1;
                                            end else if (letter_count > 7) begin
                                                digit_assignment[7] <= 8'd0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            OUTPUT: begin
                if (output_idx < puzzle_len) begin
                    result_valid <= 1'b1;
                    output_idx <= output_idx + 1;
                    current_char <= puzzle[output_idx];
                    
                    // Check if it's a letter
                    if (puzzle[output_idx] >= 8'h41 && puzzle[output_idx] <= 8'h5A) begin
                        found_letter_reg <= 1'b0;
                        digit_idx_reg <= 4'd0;
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (i < letter_count && letters[i] == puzzle[output_idx]) begin
                                found_letter_reg <= 1'b1;
                                digit_idx_reg <= i;
                            end
                        end
                        
                        if (found_letter_reg) begin
                            result_char <= 8'h30 + digit_assignment[digit_idx_reg];
                        end
                    end else begin
                        result_char <= puzzle[output_idx];
                    end
                end else begin
                    result_valid <= 1'b0;
                end
            end
            
            DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end

// Next state logic and helper calculations
always @(*) begin
    next_state = state;
    
    // Initialize helper registers
    valid_reg = 1'b1;
    num1_reg = 8'd0;
    num2_reg = 8'd0;
    num3_reg = 8'd0;
    current_num_reg = 8'd0;
    in_num1_reg = 1'b1;
    in_num2_reg = 1'b0;
    in_num3_reg = 1'b0;
    all_tried_reg = 1'b1;
    
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
            // Check if current assignment has duplicate digits
            for (integer i = 0; i < 8; i = i + 1) begin
                for (integer j = i + 1; j < 8; j = j + 1) begin
                    if (i < letter_count && j < letter_count) begin
                        if (digit_assignment[i] == digit_assignment[j]) begin
                            valid_reg = 1'b0;
                        end
                    end
                end
            end
            
            // Check leading zeros
            for (integer i = 0; i < puzzle_len; i = i + 1) begin
                if (puzzle[i] >= 8'h41 && puzzle[i] <= 8'h5A) begin
                    // Check if this is the first character or preceded by operator
                    if (i > 0 && puzzle[i-1] != 8'h2B && puzzle[i-1] != 8'h3D) begin
                        // Not leading, continue
                    end else begin
                        // Leading letter - check if assigned 0
                        for (integer j = 0; j < letter_count; j = j + 1) begin
                            if (letters[j] == puzzle[i] && digit_assignment[j] == 8'd0) begin
                                valid_reg = 1'b0;
                            end
                        end
                    end
                end
            end
            
            // Validate equation
            if (valid_reg) begin
                for (integer i = 0; i < 8'd20 && i < puzzle_len; i = i + 1) begin
                    if (puzzle[i] == 8'h2B) begin  // '+'
                        if (in_num1_reg) begin
                            num1_reg = current_num_reg;
                            current_num_reg = 8'd0;
                            in_num1_reg = 1'b0;
                            in_num2_reg = 1'b1;
                        end else begin
                            valid_reg = 1'b0;
                        end
                    end else if (puzzle[i] == 8'h3D) begin  // '='
                        if (in_num2_reg) begin
                            num2_reg = current_num_reg;
                            current_num_reg = 8'd0;
                            in_num2_reg = 1'b0;
                            in_num3_reg = 1'b1;
                        end else begin
                            valid_reg = 1'b0;
                        end
                    end else if (puzzle[i] >= 8'h41 && puzzle[i] <= 8'h5A) begin
                        // Find digit for this letter
                        found_letter_reg = 1'b0;
                        for (integer j = 0; j < 8; j = j + 1) begin
                            if (j < letter_count && letters[j] == puzzle[i]) begin
                                current_num_reg = current_num_reg * 10 + digit_assignment[j];
                                found_letter_reg = 1'b1;
                            end
                        end
                        if (!found_letter_reg) begin
                            valid_reg = 1'b0;
                        end
                    end
                end
                
                if (in_num3_reg) begin
                    num3_reg = current_num_reg;
                end
                
                if (valid_reg && (num1_reg + num2_reg != num3_reg)) begin
                    valid_reg = 1'b0;
                end
            end
            
            // Check if all assignments tried
            for (integer i = 0; i < 8; i = i + 1) begin
                if (i < letter_count && digit_assignment[i] != 8'd9) begin
                    all_tried_reg = 1'b0;
                end
            end
            
            if (valid_reg) begin
                next_state = OUTPUT;
            end else if (timeout_counter >= CLK_TIMEOUT || all_tried_reg) begin
                next_state = DONE;
                if (all_tried_reg) begin
                    impossible = 1'b1;
                end
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
        
        default: next_state = IDLE;
    endcase
end

endmodule