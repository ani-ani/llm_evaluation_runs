module TopModule(input a, b, c, d, output out, out_n);
  wire wire_ab = a & b;
  wire wire_cd = c & d;
  assign out = wire_ab | wire_cd;
  assign out_n = ~out;
endmodule