module arithmetic_book(
  input [4:0] n,
  input [31:0] numbers [0:15],
  output reg [7:0] count
);

  reg [63:0] sum;
  reg [63:0] product;
  integer i, j, k;

  always @* begin
    count = 8'b0;
    for (i = 0; i < n-1; i = i + 1) begin
      for (j = i+1; j < n; j = j + 1) begin
        sum = 0;
        product = 1;
        for (k = i; k <= j; k = k + 1) begin
          sum = sum + numbers[k];
          product = product * numbers[k];
        end
        if (sum == product) begin
          count = count + 1;
        end
      end
    end
  end

endmodule