module toggle_case(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output [7:0] out_0,
    output [7:0] out_1,
    output [7:0] out_2,
    output [7:0] out_3,
    output [7:0] out_4,
    output [7:0] out_5,
    output [7:0] out_6,
    output [7:0] out_7
);

    // Helper function to toggle case of a single character
    function [7:0] toggle;
        input [7:0] c;
        begin
            // Check for uppercase (A-Z: 0x41-0x5A)
            if (c >= 8'h41 && c <= 8'h5A)
                toggle = c + 8'h20; // Convert to lowercase
            // Check for lowercase (a-z: 0x61-0x7A)
            else if (c >= 8'h61 && c <= 8'h7A)
                toggle = c - 8'h20; // Convert to uppercase
            else
                toggle = c; // Leave unchanged
        end
    endfunction

    // Process all 8 characters in parallel
    assign out_0 = toggle(char_0);
    assign out_1 = toggle(char_1);
    assign out_2 = toggle(char_2);
    assign out_3 = toggle(char_3);
    assign out_4 = toggle(char_4);
    assign out_5 = toggle(char_5);
    assign out_6 = toggle(char_6);
    assign out_7 = toggle(char_7);

endmodule