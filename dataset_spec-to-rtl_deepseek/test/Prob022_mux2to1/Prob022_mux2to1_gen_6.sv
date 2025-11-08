module TopModule(input reg a, input reg b, input reg sel, output out);
  assign out = sel ? b : a;
endmodule