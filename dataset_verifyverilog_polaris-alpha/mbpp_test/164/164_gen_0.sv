module divisor_sum_comparator(
  input  [7:0] num1,
  input  [7:0] num2,
  output       match_flag
);

  // Function to compute sum of proper divisors for an 8-bit number
  function automatic [8:0] sum_proper_divisors;
    input [7:0] n;
    reg   [8:0] sum;
    reg   [7:0] d;
  begin
    // Special cases and initialization
    if (n <= 1) begin
      // For n = 0 or 1, proper divisor sum is 0
      sum = 9'd0;
    end else begin
      sum = 9'd1; // 1 is always a proper divisor for n > 1
      // Check divisors from 2 to 16 (bounded for 8-bit inputs)
      for (d = 8'd2; d <= 8'd16; d = d + 1) begin
        if (d < n) begin
          if (n % d == 0) begin
            if ((n / d) == d) begin
              // Perfect square factor, add d once
              if (d != n)
                sum = sum + d;
            end else begin
              // Pair of divisors d and n/d
              if (d != n)
                sum = sum + d;
              if ((n / d) != n)
                sum = sum + (n / d);
            end
          end
        end
      end
    end
    sum_proper_divisors = sum;
  end
  endfunction

  wire [8:0] sum1;
  wire [8:0] sum2;

  assign sum1 = sum_proper_divisors(num1);
  assign sum2 = sum_proper_divisors(num2);

  assign match_flag = (sum1 == sum2);

endmodule