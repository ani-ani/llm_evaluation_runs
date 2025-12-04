module fraction_multiplier_check(
  input reg [7:0] num_x,
  input reg [7:0] den_x,
  input reg [7:0] num_n,
  input reg [7:0] den_n,
  output reg result
);
  always @* begin
    reg [15:0] num_product = num_x * num_n;
    reg [15:0] den_product = den_x * den_n;
    if (den_product != 16'b0 && (num_product % den_product) == 16'b0)
      result = 1'b1;
    else
      result = 1'b0;
  end
endmodule