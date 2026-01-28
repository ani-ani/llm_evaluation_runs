module date_converter (
    input [79:0] date_in,
    output [79:0] date_out
);
    // Combinational logic for date format conversion
    // Input format: YYYY-MM-DD (10 characters, 80 bits)
    // Output format: DD-MM-YYYY (10 characters, 80 bits)
    
    // Map bits: date_in[79:0] -> characters 0-9 (each 8 bits)
    // Position 0: year thousands, Position 1: year hundreds, Position 2: year tens, Position 3: year ones
    // Position 5: month tens, Position 6: month ones
    // Position 8: day tens, Position 9: day ones
    
    assign date_out = {
        // Character 9: Year ones (input char 3)
        date_in[31:24],
        // Character 8: Year tens (input char 2)
        date_in[23:16],
        // Character 7: Year hundreds (input char 1)
        date_in[15:8],
        // Character 6: Year thousands (input char 0)
        date_in[7:0],
        // Character 5: Dash '-' (0x2D)
        8'h2D,
        // Character 4: Month ones (input char 6)
        date_in[55:48],
        // Character 3: Month tens (input char 5)
        date_in[47:40],
        // Character 2: Dash '-' (0x2D)
        8'h2D,
        // Character 1: Day ones (input char 9)
        date_in[79:72],
        // Character 0: Day tens (input char 8)
        date_in[71:64]
    };
    
endmodule