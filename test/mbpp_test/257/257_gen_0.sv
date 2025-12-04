module swap_numbers(
  input  [7:0] a,
  input  [7:0] b,
  output [7:0] out0,
  output [7:0] out1
);

  assign out0 = b;
  assign out1 = a;

endmodule