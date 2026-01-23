module divisor_parity (
  input [15:0] n,
  output even_divisors
);

  reg [7:0] root;
  reg [15:0] square;
  integer i;

  always @* begin
    if (n == 0) begin
      even_divisors = 1'b1;
    end else begin
      root = 0;
      for (i = 0; i < 256; i = i + 1) begin
        square = i * i;
        if (square > n) begin
          root = i - 1;
          break;
        end
      end
      if (root * root == n) begin
        even_divisors = 1'b0;
      end else begin
        even_divisors = 1'b1;
      end
    end
  end

endmodule