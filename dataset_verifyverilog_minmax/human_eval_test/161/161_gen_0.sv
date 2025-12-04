module case_reverse_or_invert (
    input reg [63:0] str_in,
    output reg [63:0] str_out
);

    // Extract each byte
    wire [7:0] char0 = str_in[63:56];
    wire [7:0] char1 = str_in[55:48];
    wire [7:0] char2 = str_in[47:40];
    wire [7:0] char3 = str_in[39:32];
    wire [7:0] char4 = str_in[31:24];
    wire [7:0] char5 = str_in[23:16];
    wire [7:0] char6 = str_in[15:8];
    wire [7:0] char7 = str_in[7:0];
    wire any_letter;

    // For char0
    wire is_letter0 = (char0 >= 8'd65 && char0 <= 8'd90) || (char0 >= 8'd97 && char0 <= 8'd122);
    wire [7:0] conv_char0 = is_letter0 ? ( (char0 >= 8'd65 && char0 <= 8'd90) ? char0 + 8'd32 : char0 - 8'd32 ) : char0;

    // Similarly for char1
    wire is_letter1 = (char1 >= 8'd65 && char1 <= 8'd90) || (char1 >= 8'd97 && char1 <= 8'd122);
    wire [7:0] conv_char1 = is_letter1 ? ( (char1 >= 8'd65 && char1 <= 8'd90) ? char1 + 8'd32 : char1 - 8'd32 ) : char1;

    // char2
    wire is_letter2 = (char2 >= 8'd65 && char2 <= 8'd90) || (char2 >= 8'd97 && char2 <= 8'd122);
    wire [7:0] conv_char2 = is_letter2 ? ( (char2 >= 8'd65 && char2 <= 8'd90) ? char2 + 8'd32 : char2 - 8'd32 ) : char2;

    // char3
    wire is_letter3 = (char3 >= 8'd65 && char3 <= 8'd90) || (char3 >= 8'd97 && char3 <= 8'd122);
    wire [7:0] conv_char3 = is_letter3 ? ( (char3 >= 8'd65 && char3 <= 8'd90) ? char3 + 8'd32 : char3 - 8'd32 ) : char3;

    // char4
    wire is_letter4 = (char4 >= 8'd65 && char4 <= 8'd90) || (char4 >= 8'd97 && char4 <= 8'd122);
    wire [7:0] conv_char4 = is_letter4 ? ( (char4 >= 8'd65 && char4 <= 8'd90) ? char4 + 8'd32 : char4 - 8'd32 ) : char4;

    // char5
    wire is_letter5 = (char5 >= 8'd65 && char5 <= 8'd90) || (char5 >= 8'd97 && char5 <= 8'd122);
    wire [7:0] conv_char5 = is_letter5 ? ( (char5 >= 8'd65 && char5 <= 8'd90) ? char5 + 8'd32 : char5 - 8'd32 ) : char5;

    // char6
    wire is_letter6 = (char6 >= 8'd65 && char6 <= 8'd90) || (char6 >= 8'd97 && char6 <= 8'd122);
    wire [7:0] conv_char6 = is_letter6 ? ( (char6 >= 8'd65 && char6 <= 8'd90) ? char6 + 8'd32 : char6 - 8'd32 ) : char6;

    // char7
    wire is_letter7 = (char7 >= 8'd65 && char7 <= 8'd90) || (char7 >= 8'd97 && char7 <= 8'd122);
    wire [7:0] conv_char7 = is_letter7 ? ( (char7 >= 8'd65 && char7 <= 8'd90) ? char7 + 8'd32 : char7 - 8'd32 ) : char7;

    // Combine into case-converted string
    wire [63:0] conv_str = { conv_char0, conv_char1, conv_char2, conv_char3, conv_char4, conv_char5, conv_char6, conv_char7 };

    // Check if any letter exists
    assign any_letter = is_letter0 || is_letter1 || is_letter2 || is_letter3 || is_letter4 || is_letter5 || is_letter6 || is_letter7;

    // Reversed string
    wire [63:0] rev_str = { char7, char6, char5, char4, char3, char2, char1, char0 };

    // Output
    assign str_out = any_letter ? conv_str : rev_str;

endmodule