module parabola_directrix(
  input  signed [15:0] a,
  input  signed [15:0] b,
  input  signed [15:0] c,
  output signed [15:0] directrix
);

  // Extend inputs to prevent overflow during intermediate calculations
  wire signed [31:0] a_ext = {{16{a[15]}}, a};
  wire signed [31:0] b_ext = {{16{b[15]}}, b};
  wire signed [31:0] c_ext = {{16{c[15]}}, c};

  // b*b (up to 32 bits)
  wire signed [31:0] bb = b_ext * b_ext;

  // (b*b) + 1
  wire signed [31:0] bb_plus_1 = bb + 32'sd1;

  // ((b*b)+1) * 4
  wire signed [31:0] mult4 = bb_plus_1 <<< 2;

  // ((b*b)+1)*4 * a
  wire signed [63:0] term = $signed(mult4) * $signed(a_ext);

  // Compute c - term, using sufficient width then truncate
  wire signed [63:0] c_ext_64 = {{32{c_ext[31]}}, c_ext};
  wire signed [63:0] directrix_full = c_ext_64 - term;

  // Truncate to 16-bit signed output (2's complement)
  assign directrix = directrix_full[15:0];

endmodule