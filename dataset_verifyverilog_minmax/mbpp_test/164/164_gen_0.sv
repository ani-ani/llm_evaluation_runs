module divisor_sum_comparator(
  input [7:0] num1,
  input [7:0] num2,
  output reg match_flag
);

  function [15:0] divisor_sum;
    input [7:0] n;
    integer i, j;
    reg [15:0] sum;
  begin
    sum = 0;
    for (i = 1; i <= 15; i = i + 1) begin
      if (i * i > n) break;
      if (n % i == 0) begin
        j = n / i;
        if (i == j) begin
          if (i != n) sum = sum + i;
        end else begin
          if (i != n) sum = sum + i;
          if (j != n) sum = sum + j;
        end
      end
    end
    divisor_sum = sum;
  end
  endfunction

  always_comb begin
    match_flag = (divisor_sum(num1) == divisor_sum(num2));
  end

endmodule