module even_divisor_count(
  input  [7:0] n,
  output       is_even
);

  // Combinational calculation of the number of divisors parity
  integer count;
  integer i;

  always @* begin
    count = 0;
    for (i = 1; i <= 15; i = i + 1) begin
      if (i <= n && (n % i) == 0) begin
        if ((n / i) == i)
          count = count + 1;
        else
          count = count + 2;
      end
    end
  end

  assign is_even = (count[0] == 1'b0);

endmodule