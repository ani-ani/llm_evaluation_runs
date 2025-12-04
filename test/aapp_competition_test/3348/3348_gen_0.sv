module bonbon_arrangement(
  input  [1:0] r,
  input  [1:0] c,
  input  [4:0] a,
  input  [4:0] b,
  input  [4:0] c_in,
  output       possible
);

  wire [3:0] total;
  wire [3:0] half_total;

  assign total = r * c;
  assign half_total = total >> 1;

  assign possible = (a <= half_total) &&
                    (b <= half_total) &&
                    (c_in <= half_total);

endmodule