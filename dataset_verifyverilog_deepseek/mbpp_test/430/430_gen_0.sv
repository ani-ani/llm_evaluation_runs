module parabola_directrix (
  input signed [15:0] a,
  input signed [15:0] b,
  input signed [15:0] c,
  output signed [15:0] directrix
);

  assign directrix = c - (( (b * b + 1) * 4 ) * a);

endmodule