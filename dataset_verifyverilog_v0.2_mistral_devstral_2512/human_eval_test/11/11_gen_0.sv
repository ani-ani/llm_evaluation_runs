module string_xor (
  input [15:0] a,
  input [15:0] b,
  input [3:0] len,
  output [15:0] result
);

  assign result = (len == 0) ? 16'b0 : 
                  ({16{1'b0}} ^ (a ^ b)) & ((1 << len) - 1);

endmodule