module perfect_squares_rom (
    input wire [7:0] a,          // Lower bound (0-255)
    input wire [7:0] b,          // Upper bound (0-255)
    output reg [15:0] matches    // Bitmask: bit i set if i is a perfect square in range
);

    // Internal lookup table for perfect squares up to 255
    // Valid squares: 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256 (256 is > 255)
    // We will check values 0-15 for squares (since 15^2=225 <= 255)
    
    reg [15:0] square_mask;      // Precomputed mask of all perfect squares
    
    always @(*) begin
        // Initialize square mask: set bit i if i is a perfect square
        square_mask = 16'h0000;
        
        // Check values 0 through 15
        if (0*0 >= a && 0*0 <= b) square_mask[0] = 1'b1;
        if (1*1 >= a && 1*1 <= b) square_mask[1] = 1'b1;
        if (2*2 >= a && 2*2 <= b) square_mask[4] = 1'b1;
        if (3*3 >= a && 3*3 <= b) square_mask[9] = 1'b1;
        if (4*4 >= a && 4*4 <= b) square_mask[16] = 1'b1;
        if (5*5 >= a && 5*5 <= b) square_mask[25] = 1'b1;
        if (6*6 >= a && 6*6 <= b) square_mask[36] = 1'b1;
        if (7*7 >= a && 7*7 <= b) square_mask[49] = 1'b1;
        if (8*8 >= a && 8*8 <= b) square_mask[64] = 1'b1;
        if (9*9 >= a && 9*9 <= b) square_mask[81] = 1'b1;
        if (10*10 >= a && 10*10 <= b) square_mask[100] = 1'b1;
        if (11*11 >= a && 11*11 <= b) square_mask[121] = 1'b1;
        if (12*12 >= a && 12*12 <= b) square_mask[144] = 1'b1;
        if (13*13 >= a && 13*13 <= b) square_mask[169] = 1'b1;
        if (14*14 >= a && 14*14 <= b) square_mask[196] = 1'b1;
        if (15*15 >= a && 15*15 <= b) square_mask[225] = 1'b1;
        
        matches = square_mask;
    end

endmodule