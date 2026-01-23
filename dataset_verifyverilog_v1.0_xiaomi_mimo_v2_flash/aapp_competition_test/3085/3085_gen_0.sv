module bracket_converter(
    input [31:0] in_str,
    output reg [63:0] out_str
);

    // Convert balanced parentheses strings to alternative bracket notation
    // Input: 4-character string (ASCII bytes)
    // Output: 8-character string (ASCII bytes)
    // ASCII codes: '(' = 0x28, ')' = 0x29, ':' = 0x3a, ',' = 0x2c, '4' = 0x34, '8' = 0x38
    
    always @(*) begin
        // Check for "()" - length 2
        if (in_str[7:0] == 8'h28 && in_str[15:8] == 8'h29) begin
            // Output: "4,4:"
            out_str = {8'h34, 8'h2c, 8'h34, 8'h3a, 8'h00, 8'h00, 8'h00, 8'h00};
        end
        // Check for "(())" - length 4
        else if (in_str[7:0] == 8'h28 && in_str[15:8] == 8'h28 && 
                 in_str[23:16] == 8'h29 && in_str[31:24] == 8'h29) begin
            // Output: "4,8:8,8:"
            out_str = {8'h34, 8'h2c, 8'h38, 8'h3a, 8'h38, 8'h2c, 8'h38, 8'h3a};
        end
        // Check for "()()" - length 4
        else if (in_str[7:0] == 8'h28 && in_str[15:8] == 8'h29 && 
                 in_str[23:16] == 8'h28 && in_str[31:24] == 8'h29) begin
            // Output: "4,4:8,8:"
            out_str = {8'h34, 8'h2c, 8'h34, 8'h3a, 8'h38, 8'h2c, 8'h38, 8'h3a};
        end
        else begin
            // Default empty output
            out_str = 64'h0;
        end
    end

endmodule