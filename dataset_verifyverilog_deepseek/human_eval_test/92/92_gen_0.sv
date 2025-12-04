module any_int_check(input signed [7:0] x, y, z, output reg result);
  wire cond1 = (x == (y + z));
  wire cond2 = (y == (x + z));
  wire cond3 = (z == (x + y));
  always_comb result = cond1 || cond2 || cond3;
endmodule