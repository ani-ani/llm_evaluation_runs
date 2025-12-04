module tuple_to_dict (
  input [3:0] a, b, c, d, e, f,
  output [3:0] key1, val1,
  output [3:0] key2, val2,
  output [3:0] key3, val3
);
  assign key1 = a;
  assign val1 = b;
  assign key2 = c;
  assign val2 = d;
  assign key3 = e;
  assign val3 = f;
endmodule