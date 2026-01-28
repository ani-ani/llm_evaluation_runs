module decode_shift (
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    input [2:0] length,
    output reg [7:0] decoded_0, decoded_1, decoded_2, decoded_3, decoded_4, decoded_5, decoded_6, decoded_7
);
    // Internal wires for computation
    wire [7:0] offset_0, offset_1, offset_2, offset_3, offset_4, offset_5, offset_6, offset_7;
    wire [7:0] new_offset_0, new_offset_1, new_offset_2, new_offset_3, new_offset_4, new_offset_5, new_offset_6, new_offset_7;
    wire [7:0] shifted_0, shifted_1, shifted_2, shifted_3, shifted_4, shifted_5, shifted_6, shifted_7;
    wire is_alpha_0, is_alpha_1, is_alpha_2, is_alpha_3, is_alpha_4, is_alpha_5, is_alpha_6, is_alpha_7;
    
    // Helper function to check if character is in range 'a'-'z'
    // Also check if character is within valid length range
    function automatic is_valid;
        input [7:0] char;
        input [2:0] idx;
        input [2:0] len;
        begin
            // Check if char is 'a'-'z'
            if ((char >= 8'd97) && (char <= 8'd122)) begin
                // Check if index is within length
                if (idx < len) begin
                    is_valid = 1'b1;
                end else begin
                    is_valid = 1'b0;
                end
            end else begin
                is_valid = 1'b0;
            end
        end
    endfunction
    
    // Helper function to shift character backward by 5
    function automatic [7:0] shift_char;
        input [7:0] char;
        begin
            // offset = char - 97
            // new_offset = offset - 5
            // If negative, add 26: new_offset = (offset - 5) + 26
            // But we need to handle wrap properly: (offset - 5 + 26) % 26
            // Since offset is 0-25, offset - 5 is -5 to 20
            // Add 26 gives 21 to 46, which is 21-25 and 0-20 when modulo 26
            // We can simplify: if offset < 5, then new_offset = offset - 5 + 26
            // else new_offset = offset - 5
            reg [7:0] offset;
            reg [7:0] new_offset;
            offset = char - 8'd97;
            if (offset < 8'd5) begin
                new_offset = offset - 8'd5 + 8'd26;
            end else begin
                new_offset = offset - 8'd5;
            end
            shift_char = new_offset + 8'd97;
        end
    endfunction
    
    // Process each character
    always @(*) begin
        // Character 0
        if (is_valid(char_0, 3'd0, length)) begin
            decoded_0 = shift_char(char_0);
        end else if (3'd0 < length) begin
            // Within length but not alpha - pass through
            decoded_0 = char_0;
        end else begin
            // Outside length
            decoded_0 = 8'd0;
        end
        
        // Character 1
        if (is_valid(char_1, 3'd1, length)) begin
            decoded_1 = shift_char(char_1);
        end else if (3'd1 < length) begin
            decoded_1 = char_1;
        end else begin
            decoded_1 = 8'd0;
        end
        
        // Character 2
        if (is_valid(char_2, 3'd2, length)) begin
            decoded_2 = shift_char(char_2);
        end else if (3'd2 < length) begin
            decoded_2 = char_2;
        end else begin
            decoded_2 = 8'd0;
        end
        
        // Character 3
        if (is_valid(char_3, 3'd3, length)) begin
            decoded_3 = shift_char(char_3);
        end else if (3'd3 < length) begin
            decoded_3 = char_3;
        end else begin
            decoded_3 = 8'd0;
        end
        
        // Character 4
        if (is_valid(char_4, 3'd4, length)) begin
            decoded_4 = shift_char(char_4);
        end else if (3'd4 < length) begin
            decoded_4 = char_4;
        end else begin
            decoded_4 = 8'd0;
        end
        
        // Character 5
        if (is_valid(char_5, 3'd5, length)) begin
            decoded_5 = shift_char(char_5);
        end else if (3'd5 < length) begin
            decoded_5 = char_5;
        end else begin
            decoded_5 = 8'd0;
        end
        
        // Character 6
        if (is_valid(char_6, 3'd6, length)) begin
            decoded_6 = shift_char(char_6);
        end else if (3'd6 < length) begin
            decoded_6 = char_6;
        end else begin
            decoded_6 = 8'd0;
        end
        
        // Character 7
        if (is_valid(char_7, 3'd7, length)) begin
            decoded_7 = shift_char(char_7);
        end else if (3'd7 < length) begin
            decoded_7 = char_7;
        end else begin
            decoded_7 = 8'd0;
        end
    end
    
endmodule