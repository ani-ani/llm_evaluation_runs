module divisible_tuples(
  input  [7:0] K,
  input  [7:0] tuple0_0, input [7:0] tuple0_1, input [7:0] tuple0_2,
  input  [7:0] tuple1_0, input [7:0] tuple1_1, input [7:0] tuple1_2,
  input  [7:0] tuple2_0, input [7:0] tuple2_1, input [7:0] tuple2_2,
  input  [7:0] tuple3_0, input [7:0] tuple3_1, input [7:0] tuple3_2,
  output [3:0] valid_tuples
);

  // Local function to check divisibility, treating 0 as divisible by any K
  function automatic is_divisible;
    input [7:0] val;
    input [7:0] div;
    begin
      if (val == 8'd0)
        is_divisible = 1'b1;
      else
        is_divisible = (div != 8'd0) && ((val % div) == 8'd0);
    end
  endfunction

  assign valid_tuples[0] = is_divisible(tuple0_0, K) &
                           is_divisible(tuple0_1, K) &
                           is_divisible(tuple0_2, K);

  assign valid_tuples[1] = is_divisible(tuple1_0, K) &
                           is_divisible(tuple1_1, K) &
                           is_divisible(tuple1_2, K);

  assign valid_tuples[2] = is_divisible(tuple2_0, K) &
                           is_divisible(tuple2_1, K) &
                           is_divisible(tuple2_2, K);

  assign valid_tuples[3] = is_divisible(tuple3_0, K) &
                           is_divisible(tuple3_1, K) &
                           is_divisible(tuple3_2, K);

endmodule