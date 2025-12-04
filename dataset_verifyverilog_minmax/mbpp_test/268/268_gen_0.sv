module star_number
(
  input reg [4:0] n,
  output reg [10:0] star_num
);
  always_comb begin
    if (n < 2)
      star_num = 11'd1;
    else
      star_num = 6 * n * (n - 1) + 1;
  end
endmodule