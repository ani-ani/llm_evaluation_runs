module sum_of_squares (
  input [7:0] n,
  output reg [24:0] sum_squares
);

  always_comb begin
    logic [26:0] temp_product;
    temp_product = (2 * n) * (n + 1) * (2 * n + 1);
    sum_squares = temp_product / 3;
  end

endmodule