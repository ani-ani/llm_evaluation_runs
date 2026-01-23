module crazy_town (
    input signed [31:0] x1, y1,
    input signed [31:0] x2, y2,
    input signed [31:0] a, b, c,
    output separation
);

    wire signed [63:0] term1_home = $signed(a) * $signed(x1);
    wire signed [63:0] term2_home = $signed(b) * $signed(y1);
    wire signed [63:0] val_home = term1_home + term2_home + $signed(c);

    wire signed [63:0] term1_uni = $signed(a) * $signed(x2);
    wire signed [63:0] term2_uni = $signed(b) * $signed(y2);
    wire signed [63:0] val_uni = term1_uni + term2_uni + $signed(c);

    assign separation = (val_home[63] != val_uni[63]);

endmodule