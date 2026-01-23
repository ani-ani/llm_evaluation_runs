module nonagonal_number (
    input [15:0] n,
    output [15:0] result
);

    wire [15:0] temp1;
    wire [15:0] temp2;
    wire [31:0] temp3;

    // Step 1: Calculate temp1 = 7 * n
    assign temp1 = 7 * n;

    // Step 2: Calculate temp2 = temp1 - 5
    assign temp2 = temp1 - 5;

    // Step 3: Calculate temp3 = n * temp2 (result needs 32 bits to avoid overflow)
    assign temp3 = n * temp2;

    // Step 4: Calculate result = temp3 / 2 (right shift by 1)
    // We take the upper 15 bits and the MSB of the lower half to ensure precision,
    // effectively shifting the 32-bit value right by 1 and truncating to 16 bits.
    assign result = temp3[31:15];

endmodule