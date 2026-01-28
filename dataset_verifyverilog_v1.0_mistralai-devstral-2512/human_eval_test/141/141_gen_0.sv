module filename_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output reg result,
    output reg done,
    output reg [2:0] err_type
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READING_NAME = 3'd1;
    localparam [2:0] READING_EXT = 3'd2;
    localparam [2:0] VALIDATING = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Counters and flags
    reg [5:0] pos;           // Position counter (0-31)
    reg [5:0] dot_pos;       // Position of dot
    reg [2:0] digit_count;   // Count of digits (0-7)
    reg dot_found;          // Flag for dot detection
    reg [2:0] ext_index;     // Extension character index
    reg [7:0] ext_chars [0:2]; // Store extension characters
    reg [7:0] prev_char;     // Previous character
    
    // Error flags
    reg err_no_dot;
    reg err_bad_extension;
    reg err_too_many_digits;
    reg err_bad_start;
    reg err_bad_length;
    reg err_multiple_dots;
    reg err_empty_name;
    
    // Character validation
    wire is_letter = (char_in >= 8'd65 && char_in <= 8'd90) || (char_in >= 8'd97 && char_in <= 8'd122);
    wire is_digit = (char_in >= 8'd48 && char_in <= 8'd57);
    wire is_dot = (char_in == 8'd46);
    wire is_valid_char = is_letter || is_digit || is_dot || (char_in == 8'd95) || (char_in == 8'd45);
    
    // Extension check
    wire is_txt = (ext_chars[0] == 8'd116 || ext_chars[0] == 8'd84) && 
                  (ext_chars[1] == 8'd120 || ext_chars[1] == 8'd88) && 
                  (ext_chars[2] == 8'd116 || ext_chars[2] == 8'd84);
    wire is_exe = (ext_chars[0] == 8'd101 || ext_chars[0] == 8'd69) && 
                  (ext_chars[1] == 8'd120 || ext_chars[1] == 8'd88) && 
                  (ext_chars[2] == 8'd101 || ext_chars[2] == 8'd69);
    wire is_dll = (ext_chars[0] == 8'd100 || ext_chars[0] == 8'd68) && 
                  (ext_chars[1] == 8'd108 || ext_chars[1] == 8'd76) && 
                  (ext_chars[2] == 8'd108 || ext_chars[2] == 8'd76);
    wire valid_extension = is_txt || is_exe || is_dll;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            err_type <= 3'd0;
            
            // Reset all internal signals
            pos <= 6'd0;
            dot_pos <= 6'd0;
            digit_count <= 3'd0;
            dot_found <= 1'b0;
            ext_index <= 3'd0;
            
            err_no_dot <= 1'b0;
            err_bad_extension <= 1'b0;
            err_too_many_digits <= 1'b0;
            err_bad_start <= 1'b0;
            err_bad_length <= 1'b0;
            err_multiple_dots <= 1'b0;
            err_empty_name <= 1'b0;
            
            // Reset extension characters
            ext_chars[0] <= 8'd0;
            ext_chars[1] <= 8'd0;
            ext_chars[2] <= 8'd0;
            prev_char <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READING_NAME;
                    // Reset counters on start
                    pos = 6'd0;
                    dot_pos = 6'd0;
                    digit_count = 3'd0;
                    dot_found = 1'b0;
                    ext_index = 3'd0;
                    
                    err_no_dot = 1'b0;
                    err_bad_extension = 1'b0;
                    err_too_many_digits = 1'b0;
                    err_bad_start = 1'b0;
                    err_bad_length = 1'b0;
                    err_multiple_dots = 1'b0;
                    err_empty_name = 1'b0;
                    
                    ext_chars[0] = 8'd0;
                    ext_chars[1] = 8'd0;
                    ext_chars[2] = 8'd0;
                    prev_char = 8'd0;
                end
            end
            
            READING_NAME: begin
                if (char_valid) begin
                    // Check for maximum length
                    if (pos >= 6'd31) begin
                        err_bad_length = 1'b1;
                        next_state = VALIDATING;
                    end
                    // Check for invalid start character
                    else if (pos == 6'd0 && !is_letter) begin
                        err_bad_start = 1'b1;
                        next_state = VALIDATING;
                    end
                    // Check for multiple dots
                    else if (dot_found && is_dot) begin
                        err_multiple_dots = 1'b1;
                        next_state = VALIDATING;
                    end
                    // Check for too many digits
                    else if (digit_count >= 3'd3 && is_digit) begin
                        err_too_many_digits = 1'b1;
                        next_state = VALIDATING;
                    end
                    // Check for invalid characters
                    else if (!is_valid_char) begin
                        err_bad_extension = 1'b1;
                        next_state = VALIDATING;
                    end
                    // Check for dot
                    else if (is_dot) begin
                        if (pos == 6'd0) begin
                            err_empty_name = 1'b1;
                            next_state = VALIDATING;
                        end else begin
                            dot_found = 1'b1;
                            dot_pos = pos;
                            next_state = READING_EXT;
                        end
                    end
                    // Count digits
                    else if (is_digit) begin
                        digit_count = digit_count + 3'd1;
                    end
                    
                    // Update position
                    pos = pos + 6'd1;
                    prev_char = char_in;
                end
                
                if (char_done && !dot_found) begin
                    err_no_dot = 1'b1;
                    next_state = VALIDATING;
                end
            end
            
            READING_EXT: begin
                if (char_valid) begin
                    // Store extension characters
                    if (ext_index < 3'd3) begin
                        ext_chars[ext_index] = char_in;
                        ext_index = ext_index + 3'd1;
                    end
                    
                    // Check for invalid characters in extension
                    if (!is_letter) begin
                        err_bad_extension = 1'b1;
                        next_state = VALIDATING;
                    end
                    
                    // Update position
                    pos = pos + 6'd1;
                end
                
                if (char_done) begin
                    next_state = VALIDATING;
                end
            end
            
            VALIDATING: begin
                // Check for empty extension
                if (dot_found && ext_index < 3'd3) begin
                    err_bad_extension = 1'b1;
                end
                
                // Check for dot at end
                if (dot_found && pos == dot_pos + 6'd1) begin
                    err_bad_extension = 1'b1;
                end
                
                // Check extension validity
                if (dot_found && ext_index == 3'd3 && !valid_extension) begin
                    err_bad_extension = 1'b1;
                end
                
                // Set error type
                if (err_no_dot) err_type = 3'd1;
                else if (err_bad_extension) err_type = 3'd2;
                else if (err_too_many_digits) err_type = 3'd3;
                else if (err_bad_start) err_type = 3'd4;
                else if (err_bad_length) err_type = 3'd5;
                else if (err_multiple_dots) err_type = 3'd6;
                else if (err_empty_name) err_type = 3'd7;
                else err_type = 3'd0;
                
                // Set result
                result = (err_type == 3'd0);
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule