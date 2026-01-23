module odd_count(
    input [7:0][7:0] input_str,
    output reg [255:0] result
);

    // Internal signals for counting
    wire [7:0] char [0:7];
    wire [0:7] is_odd;
    wire [3:0] count;
    wire [7:0] count_ascii;
    
    // Assign input characters to array for easy access
    assign char[0] = input_str[0];
    assign char[1] = input_str[1];
    assign char[2] = input_str[2];
    assign char[3] = input_str[3];
    assign char[4] = input_str[4];
    assign char[5] = input_str[5];
    assign char[6] = input_str[6];
    assign char[7] = input_str[7];
    
    // Odd digit detection logic
    // A digit is odd if it is in range '1'-'9' (0x31-0x39) and the LSB is 1.
    // Note: '0' is 0x30 (even), so checking range 0x31-0x39 is sufficient for digits 1-9.
    // Then we check char[0] for oddness (since 1=0x31, 3=0x33, etc.)
    assign is_odd[0] = (char[0] >= 8'h31 && char[0] <= 8'h39) && char[0][0];
    assign is_odd[1] = (char[1] >= 8'h31 && char[1] <= 8'h39) && char[1][0];
    assign is_odd[2] = (char[2] >= 8'h31 && char[2] <= 8'h39) && char[2][0];
    assign is_odd[3] = (char[3] >= 8'h31 && char[3] <= 8'h39) && char[3][0];
    assign is_odd[4] = (char[4] >= 8'h31 && char[4] <= 8'h39) && char[4][0];
    assign is_odd[5] = (char[5] >= 8'h31 && char[5] <= 8'h39) && char[5][0];
    assign is_odd[6] = (char[6] >= 8'h31 && char[6] <= 8'h39) && char[6][0];
    assign is_odd[7] = (char[7] >= 8'h31 && char[7] <= 8'h39) && char[7][0];
    
    // Count the number of odd digits
    assign count = is_odd[0] + is_odd[1] + is_odd[2] + is_odd[3] + 
                   is_odd[4] + is_odd[5] + is_odd[6] + is_odd[7];
    
    // Convert count to ASCII digit
    assign count_ascii = 8'h30 + count;
    
    // Output String Construction
    // Target String: "the number of odd elements Xn the strXng X of the Xnput."
    // Indices where count appears (based on manual count of target string):
    // 25: after "elements "
    // 35: after "str" before "ng"
    // 39: after "ng "
    // 48: after "the "
    // Note: The prompt provided indices 35, 41, 46, 52, but the text "...str4ng..." implies indices 35 and 39.
    // The prompt's indices seem to correspond to a different string version or off-by errors.
    // I will use the indices derived from the explicit example text: "the number of odd elements 4n the str4ng 4 of the 4nput."
    
    // Generating the full string (54 bytes) and assigning to result[255:0] (first 32 bytes).
    // The output port is 32 bytes. The generated string is longer. We truncate to fit the port.
    
    always @(*) begin
        // Initialize result with spaces (0x20) or zero
        result = 256'h0;
        
        // Fill the first 32 bytes (indices 0-31)
        // Indices 0-24: "the number of odd elements "
        result[7:0]   = 8'h74; // 0: t
        result[15:8]  = 8'h68; // 1: h
        result[23:16] = 8'h65; // 2: e
        result[31:24] = 8'h20; // 3: space
        result[39:32] = 8'h6e; // 4: n
        result[47:40] = 8'h75; // 5: u
        result[55:48] = 8'h6d; // 6: m
        result[63:56] = 8'h62; // 7: b
        result[71:64] = 8'h65; // 8: e
        result[79:72] = 8'h72; // 9: r
        result[87:80] = 8'h20; // 10: space
        result[95:88]  = 8'h6f; // 11: o
        result[103:96] = 8'h66; // 12: f
        result[111:104]= 8'h20; // 13: space
        result[119:112]= 8'h6f; // 14: o
        result[127:120]= 8'h64; // 15: d
        result[135:128]= 8'h64; // 16: d
        result[143:136]= 8'h20; // 17: space
        result[151:144]= 8'h65; // 18: e
        result[159:152]= 8'h6c; // 19: l
        result[167:160]= 8'h65; // 20: e
        result[175:168]= 8'h6d; // 21: m
        result[183:176]= 8'h65; // 22: e
        result[191:184]= 8'h6e; // 23: n
        result[199:192]= 8'h74; // 24: t
        
        // Index 25: Count
        result[207:200] = count_ascii;
        
        // Index 26: 'n'
        result[215:208] = 8'h6e;
        
        // Index 27-30: " the"
        // Index 27 (Bit 31:24): space
        result[223:216] = 8'h20;
        // Index 28 (Bit 23:16): 't'
        result[231:224] = 8'h74;
        // Index 29 (Bit 15:8): 'h'
        result[239:232] = 8'h68;
        // Index 30 (Bit 7:0): 'e'
        result[247:240] = 8'h65;
    end
endmodule