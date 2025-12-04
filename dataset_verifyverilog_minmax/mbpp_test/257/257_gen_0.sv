module swap_numbers(
  input  wire [7:0] a,
  input  wire [7:0] b,
  output wire [7:0] out0,
  output wire [7:0] out1
);
  assign out0 = b;
  assign out1 = a;
endmodule
