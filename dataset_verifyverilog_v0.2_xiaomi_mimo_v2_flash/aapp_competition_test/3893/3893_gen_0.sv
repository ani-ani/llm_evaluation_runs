module crazy_town (
    input signed [31:0] x1, y1,
    input signed [31:0] x2, y2,
    input signed [31:0] a, b, c,
    output separation
);

    // Calculate L1 = a*x1 + b*y1 + c using 64-bit arithmetic to prevent overflow
    wire signed [63:0] term1_home = a * x1;
    wire signed [63:0] term2_home = b * y1;
    wire signed [63:0] val_home = term1_home + term2_home + c;

    // Calculate L2 = a*x2 + b*y2 + c using 64-bit arithmetic to prevent overflow
    wire signed [63:0] term1_uni = a * x2;
    wire signed [63:0] term2_uni = b * y2;
    wire signed [63:0] val_uni = term1_uni + term2_uni + c;

    // Check for different signs (one negative, one positive)
    // If MSB of val_home != MSB of val_uni, they have different signs.
    assign separation = (val_home[63] != val_uni[63]);

endmodule