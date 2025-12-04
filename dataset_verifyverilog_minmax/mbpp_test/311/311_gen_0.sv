module set_leftmost_unset_bit(
  input [3:0] n,
  output [3:0] result
);

  assign mask = 
      (~n[3]) ? 4'b1000 :
      (n[3] & ~n[2]) ? 4'b0100 :
      (n[3] & n[2] & ~n[1]) ? 4'b0010 :
      (n[3] & n[2] & n[1] & ~n[0]) ? 4'b0001 : 4'b0000;

  assign result = n | mask;

endmodule