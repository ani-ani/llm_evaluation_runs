module set_even_bits(input [7:0] num, output [7:0] result);
  assign result = num | 8'b01010101;
endmodule