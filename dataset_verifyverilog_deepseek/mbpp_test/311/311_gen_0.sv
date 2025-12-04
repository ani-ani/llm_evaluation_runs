module set_leftmost_unset_bit(input [3:0] n, output [3:0] result);
  assign result = (n[3] == 1'b0) ? (n | 4'b1000) :
                 (n[2] == 1'b0) ? (n | 4'b0100) :
                 (n[1] == 1'b0) ? (n | 4'b0010) :
                 (n[0] == 1'b0) ? (n | 4'b0001) :
                 n;
endmodule