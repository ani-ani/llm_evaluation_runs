module biggest_even(
  input [15:0] x,
  input [15:0] y,
  output reg signed [15:0] result
);
  always_comb begin
    if (x > y) result = -1;
    else if (y[0] == 0) result = y;
    else if ((y - 1) >= x) result = y - 1;
    else result = -1;
  end
endmodule