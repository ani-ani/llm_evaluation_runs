module none_check(
  input wire [4:0][7:0] tuple_in,
  output reg res
);
  assign res = (tuple_in[0] == 8'hFF) || (tuple_in[1] == 8'hFF) || (tuple_in[2] == 8'hFF) || (tuple_in[3] == 8'hFF) || (tuple_in[4] == 8'hFF);
endmodule