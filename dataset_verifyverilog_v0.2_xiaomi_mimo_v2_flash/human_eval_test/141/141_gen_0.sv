module file_name_check(
    input [127:0] file_name,
    output reg is_valid
);

    // Helper signals for validation
    reg [3:0] digit_count;
    reg dot_found;
    reg [3:0] dot_position;
    reg prefix_valid;
    reg suffix_valid;
    reg first_char_valid;
    
    // Extract bytes from the 128-bit vector
    // Little-endian: byte 0 is file_name[7:0], byte 1 is file_name[15:8], etc.
    wire [7:0] char [15:0];
    assign char[0] = file_name[7:0];
    assign char[1] = file_name[15:8];
    assign char[2] = file_name[23:16];
    assign char[3] = file_name[31:24];
    assign char[4] = file_name[39:32];
    assign char[5] = file_name[47:40];
    assign char[6] = file_name[55:48];
    assign char[7] = file_name[63:56];
    assign char[8] = file_name[71:64];
    assign char[9] = file_name[79:72];
    assign char[10] = file_name[87:80];
    assign char[11] = file_name[95:88];
    assign char[12] = file_name[103:96];
    assign char[13] = file_name[111:104];
    assign char[14] = file_name[119:112];
    assign char[15] = file_name[127:120];

    // Count digits and find dot position
    integer i;
    always @(*) begin
        digit_count = 0;
        dot_found = 0;
        dot_position = 0;
        
        for (i = 0; i < 16; i = i + 1) begin
            // Check for digit
            if (char[i] >= 8'h30 && char[i] <= 8'h39) begin
                digit_count = digit_count + 1;
            end
            
            // Check for dot (only first dot is relevant)
            if (char[i] == 8'h2E && !dot_found) begin
                dot_found = 1;
                dot_position = i;
            end
        end
    end
    
    // Check prefix validity
    always @(*) begin
        prefix_valid = 0;
        first_char_valid = 0;
        
        // Prefix must exist (dot_position > 0)
        if (dot_found && dot_position > 0) begin
            // Check if first character (at index 0) is a letter
            if (char[0] >= 8'h41 && char[0] <= 8'h5A) begin // A-Z
                first_char_valid = 1;
            end else if (char[0] >= 8'h61 && char[0] <= 8'h7A) begin // a-z
                first_char_valid = 1;
            end
            
            prefix_valid = first_char_valid;
        end
    end
    
    // Check suffix validity
    always @(*) begin
        suffix_valid = 0;
        
        if (dot_found && dot_position < 13) begin // Need at least 3 chars after dot
            // Get the 3 characters after the dot
            // Suffix positions: dot_position+1, dot_position+2, dot_position+3
            if (char[dot_position + 1] == 8'h74 && // 't'
                char[dot_position + 2] == 8'h78 && // 'x'
                char[dot_position + 3] == 8'h74) begin // 't'
                suffix_valid = 1;
            end else if (char[dot_position + 1] == 8'h65 && // 'e'
                         char[dot_position + 2] == 8'h78 && // 'x'
                         char[dot_position + 3] == 8'h65) begin // 'e'
                suffix_valid = 1;
            end else if (char[dot_position + 1] == 8'h64 && // 'd'
                         char[dot_position + 2] == 8'h6C && // 'l'
                         char[dot_position + 3] == 8'h6C) begin // 'l'
                suffix_valid = 1;
            end
        end
    end
    
    // Final validation
    always @(*) begin
        is_valid = 0;
        
        // Check all conditions:
        // 1. Digits <= 3
        // 2. Exactly one dot (dot_found)
        // 3. Prefix valid (non-empty, starts with letter)
        // 4. Suffix valid
        if (digit_count <= 3 && dot_found && prefix_valid && suffix_valid) begin
            is_valid = 1;
        end
    end

endmodule
