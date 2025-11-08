module TopModule(input a, input b, input c, input d, output out, output out_n);
  wire out_wire;
  wire and1, and2;
  assign and1 = a & b;
  assign and2 = c & d;
  assign out_wire = and1 | and2;
  assign out = out_wire;
  assign out_n = ~out_wire;
endmodule