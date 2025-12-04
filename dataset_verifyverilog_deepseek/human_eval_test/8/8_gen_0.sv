module sum_product(
  input reg [3:0] len,
  input reg [63:0] numbers,
  output reg [15:0] sum,
  output reg [63:0] product
);

  always_comb begin
    integer i;
    sum = 0;
    product = 1;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < len) begin
        sum = sum + numbers[63 - 8*i -: 8];
        product = product * numbers[63 - 8*i -: 8];
      end
    end
  end

endmodule