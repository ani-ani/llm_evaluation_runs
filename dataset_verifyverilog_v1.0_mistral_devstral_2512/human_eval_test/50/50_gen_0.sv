module decode_shift(
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    input [2:0] length,
    output [7:0] decoded_0, decoded_1, decoded_2, decoded_3, decoded_4, decoded_5, decoded_6, decoded_7
);

    // Helper function for decoding a single character
    function [7:0] decode_char(input [7:0] c);
        reg [7:0] result;
        reg [4:0] offset;
        
        if (c >= 8'd97 && c <= 8'd122) begin
            // Convert to 0-25 offset
            offset = c - 8'd97;
            // Subtract 5 with wrap-around
            offset = (offset - 5'd5 + 5'd26) % 5'd26;
            // Convert back to ASCII
            result = offset + 8'd97;
        end else begin
            // Pass through unchanged
            result = c;
        end
        
        decode_char = result;
    endfunction

    // Decode each character
    assign decoded_0 = (length > 3'd0) ? decode_char(char_0) : 8'd0;
    assign decoded_1 = (length > 3'd1) ? decode_char(char_1) : 8'd0;
    assign decoded_2 = (length > 3'd2) ? decode_char(char_2) : 8'd0;
    assign decoded_3 = (length > 3'd3) ? decode_char(char_3) : 8'd0;
    assign decoded_4 = (length > 3'd4) ? decode_char(char_4) : 8'd0;
    assign decoded_5 = (length > 3'd5) ? decode_char(char_5) : 8'd0;
    assign decoded_6 = (length > 3'd6) ? decode_char(char_6) : 8'd0;
    assign decoded_7 = (length > 3'd7) ? decode_char(char_7) : 8'd0;

endmodule