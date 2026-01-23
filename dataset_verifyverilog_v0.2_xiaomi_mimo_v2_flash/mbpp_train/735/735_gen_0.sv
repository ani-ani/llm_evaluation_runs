module toggle_middle_bits (
    input [7:0] n,
    output [7:0] result
);

    // Internal wire declarations for the combinational logic
    wire [7:0] mask1;
    wire [7:0] mask2;
    wire [7:0] mask3;
    wire [7:0] middle;

    // Step 1: Create a mask of middle bits
    // This propagates set bits to the right to cover the middle region
    assign mask1 = n | (n >> 1);
    assign mask2 = mask1 | (mask1 >> 2);
    assign mask3 = mask2 | (mask2 >> 4);

    // Step 2: Extract middle bits
    // Shift right by 1 to align, then XOR 1 to clear the LSB (which corresponds to the MSB of the original number)
    assign middle = (mask3 >> 1) ^ 8'h01;

    // Step 3: Toggle middle bits
    assign result = n ^ middle;

endmodule