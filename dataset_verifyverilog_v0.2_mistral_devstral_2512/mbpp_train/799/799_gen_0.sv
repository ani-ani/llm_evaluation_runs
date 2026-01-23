module bit_rotate_left (
  input [31:0] data_in,
  input [4:0]  rotate_bits,
  output [31:0] result
);

  assign result = (data_in << rotate_bits) | (data_in >> (32 - rotate_bits));

endmodule