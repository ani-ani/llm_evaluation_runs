module integer_counter(input [3:0] is_int, output [2:0] count);
  assign count = is_int[0] + is_int[1] + is_int[2] + is_int[3];
endmodule