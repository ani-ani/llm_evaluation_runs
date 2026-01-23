module crazy_town (
    input signed [31:0] x1, y1,
    input signed [31:0] x2, y2,
    input signed [31:0] a, b, c,
    output separation
);
wire signed [63:0] term1_home = a * x1;
wire signed [63:0] term2_home = b * y1;
wire signed [63:0] val_home = term1_home + term2_home + c;
wire signed [63:0] term1_uni = a * x2;
wire signed [63:0] term2_uni = b * y2;
wire signed [63:0] val_uni = term1_uni + term2_uni + c;
assign separation = (val_home[63] != val_uni[63]);
endmodule