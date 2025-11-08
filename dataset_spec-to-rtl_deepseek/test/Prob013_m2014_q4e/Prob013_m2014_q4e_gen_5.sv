module TopModule(input reg in1, input reg in2, output out);
  assign out = ~(in1 | in2);
endmodule