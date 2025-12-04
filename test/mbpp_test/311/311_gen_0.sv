module set_leftmost_unset_bit(
  input  [3:0] n,
  output [3:0] result
);

  assign result[3] = n[3] | (~n[3] & n[2] & n[1] & n[0]);
  assign result[2] = n[2] | ( n[3] & ~n[2] & n[1] & n[0]);
  assign result[1] = n[1] | ( n[3] & n[2] & ~n[1] & n[0]);
  assign result[0] = n[0] | ( n[3] & n[2] & n[1] & ~n[0]);

endmodule