module TopModule(input a, b, c, d, output out, out_n);
  wire and_ab, and_cd;
  assign and_ab = a & b;
  assign and_cd = c & d;
  assign out = and_ab | and_cd;
  assign out_n = ~out;
endmodule