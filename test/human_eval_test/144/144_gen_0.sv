module fraction_multiplier_check(
  input  [7:0] num_x,
  input  [7:0] den_x,
  input  [7:0] num_n,
  input  [7:0] den_n,
  output reg result
);

  reg [15:0] num_product;
  reg [15:0] den_product;

  always @* begin
    num_product = num_x * num_n;
    den_product = den_x * den_n;

    if (den_product != 16'd0 && (num_product % den_product) == 16'd0)
      result = 1'b1;
    else
      result = 1'b0;
  end

endmodule