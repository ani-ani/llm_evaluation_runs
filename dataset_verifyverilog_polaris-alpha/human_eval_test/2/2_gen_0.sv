module truncate_fixed(
  input  [31:0] number,
  output [15:0] decimal
);

  assign decimal = number[15:0];

endmodule