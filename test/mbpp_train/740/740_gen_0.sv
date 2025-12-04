module tuple_to_dict(
  input  [3:0] a,
  input  [3:0] b,
  input  [3:0] c,
  input  [3:0] d,
  input  [3:0] e,
  input  [3:0] f,
  output [3:0] key1,
  output [3:0] val1,
  output [3:0] key2,
  output [3:0] val2,
  output [3:0] key3,
  output [3:0] val3
);

  assign key1 = a;
  assign val1 = b;

  assign key2 = c;
  assign val2 = d;

  assign key3 = e;
  assign val3 = f;

endmodule