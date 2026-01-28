module removezero_ip(
    input [7:0] char_in_0,
    input [7:0] char_in_1,
    input [7:0] char_in_2,
    input [7:0] char_in_3,
    input [7:0] char_in_4,
    input [7:0] char_in_5,
    input [7:0] char_in_6,
    input [7:0] char_in_7,
    input [7:0] char_in_8,
    input [7:0] char_in_9,
    input [7:0] char_in_10,
    input [7:0] char_in_11,
    input [7:0] char_in_12,
    input [7:0] char_in_13,
    input [7:0] char_in_14,
    input [7:0] char_in_15,
    output reg [7:0] char_out_0,
    output reg [7:0] char_out_1,
    output reg [7:0] char_out_2,
    output reg [7:0] char_out_3,
    output reg [7:0] char_out_4,
    output reg [7:0] char_out_5,
    output reg [7:0] char_out_6,
    output reg [7:0] char_out_7,
    output reg [7:0] char_out_8,
    output reg [7:0] char_out_9,
    output reg [7:0] char_out_10,
    output reg [7:0] char_out_11,
    output reg [7:0] char_out_12,
    output reg [7:0] char_out_13,
    output reg [7:0] char_out_14,
    output reg [7:0] char_out_15
);

    // ASCII constants
    localparam [7:0] ASCII_DOT = 8'd46;
    localparam [7:0] ASCII_ZERO = 8'd48;
    localparam [7:0] ASCII_SPACE = 8'd32;
    localparam [7:0] ASCII_NULL = 8'd0;

    // Internal wire arrays for input access
    wire [7:0] in_char [0:15];
    assign in_char[0] = char_in_0;
    assign in_char[1] = char_in_1;
    assign in_char[2] = char_in_2;
    assign in_char[3] = char_in_3;
    assign in_char[4] = char_in_4;
    assign in_char[5] = char_in_5;
    assign in_char[6] = char_in_6;
    assign in_char[7] = char_in_7;
    assign in_char[8] = char_in_8;
    assign in_char[9] = char_in_9;
    assign in_char[10] = char_in_10;
    assign in_char[11] = char_in_11;
    assign in_char[12] = char_in_12;
    assign in_char[13] = char_in_13;
    assign in_char[14] = char_in_14;
    assign in_char[15] = char_in_15;

    // Segment start positions (first char of each dot-separated segment)
    // Segment 0: positions 0-2 (216)
    // Segment 1: positions 4-5 (08) -> after dot at 3
    // Segment 2: positions 7-9 (094) -> after dot at 6
    // Segment 3: positions 11-13 (196) -> after dot at 10
    // Position 14-15 unused or padding

    // Helper: Check if character is a digit (0-9)
    function automatic is_digit;
        input [7:0] ch;
        begin
            is_digit = (ch >= 8'd48) && (ch <= 8'd57);
        end
    endfunction

    // For each input position, determine if it's a leading zero that should be suppressed
    // A zero is suppressed if:
    // 1. It's a '0' character
    // 2. It's at the start of a segment (after dot or at beginning)
    // 3. There is another digit later in the same segment

    wire suppress [0:15];

    // Segment 0 (positions 0-2): 216
    assign suppress[0] = (in_char[0] == ASCII_ZERO) && is_digit(in_char[1]) && is_digit(in_char[2]);
    assign suppress[1] = 1'b0; // Second digit in segment, never suppress
    assign suppress[2] = 1'b0; // Third digit in segment, never suppress

    // Position 3 is dot, pass through

    // Segment 1 (positions 4-5): 08
    assign suppress[4] = (in_char[4] == ASCII_ZERO) && is_digit(in_char[5]);
    assign suppress[5] = 1'b0; // Second digit in segment

    // Position 6 is dot, pass through

    // Segment 2 (positions 7-9): 094
    assign suppress[7] = (in_char[7] == ASCII_ZERO) && is_digit(in_char[8]) && is_digit(in_char[9]);
    assign suppress[8] = 1'b0; // Second digit in segment
    assign suppress[9] = 1'b0; // Third digit in segment

    // Position 10 is dot, pass through

    // Segment 3 (positions 11-13): 196
    assign suppress[11] = (in_char[11] == ASCII_ZERO) && is_digit(in_char[12]) && is_digit(in_char[13]);
    assign suppress[12] = 1'b0; // Second digit in segment
    assign suppress[13] = 1'b0; // Third digit in segment

    // Positions 14-15: pass through (padding)
    assign suppress[14] = 1'b0;
    assign suppress[15] = 1'b0;

    // Position 3 and 6 are dots, never suppress
    assign suppress[3] = 1'b0;
    assign suppress[6] = 1'b0;

    // Output assignment logic (combinational)
    // When suppress[i] is true, output space/null; otherwise output input character

    always @(*) begin
        char_out_0 = suppress[0] ? ASCII_SPACE : in_char[0];
        char_out_1 = in_char[1];
        char_out_2 = in_char[2];
        char_out_3 = in_char[3];
        char_out_4 = suppress[4] ? ASCII_SPACE : in_char[4];
        char_out_5 = in_char[5];
        char_out_6 = in_char[6];
        char_out_7 = suppress[7] ? ASCII_SPACE : in_char[7];
        char_out_8 = in_char[8];
        char_out_9 = in_char[9];
        char_out_10 = in_char[10];
        char_out_11 = suppress[11] ? ASCII_SPACE : in_char[11];
        char_out_12 = in_char[12];
        char_out_13 = in_char[13];
        char_out_14 = in_char[14];
        char_out_15 = in_char[15];
    end

endmodule