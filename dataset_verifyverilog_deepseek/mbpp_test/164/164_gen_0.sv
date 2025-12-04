module divisor_sum_comparator (
  input reg [7:0] num1, num2,
  output logic match_flag
);
  
  logic [15:0] sum1, sum2;

  always_comb begin : CALC_SUM1
    sum1 = 16'd0;
    if (num1 != 8'd1) begin
      for (int i = 1; i <= 15; i++) begin
        logic [7:0] divisor = 8'(i);
        if (num1 % divisor == 8'd0) begin
          if (divisor != num1) begin
            sum1 = sum1 + divisor;
          end
          logic [7:0] quotient = num1 / divisor;
          if (quotient != divisor && quotient != num1 && divisor < quotient) begin
            sum1 = sum1 + quotient;
          end
        end
      end
    end
  end

  always_comb begin : CALC_SUM2
    sum2 = 16'd0;
    if (num2 != 8'd1) begin
      for (int i = 1; i <= 15; i++) begin
        logic [7:0] divisor = 8'(i);
        if (num2 % divisor == 8'd0) begin
          if (divisor != num2) begin
            sum2 = sum2 + divisor;
          end
          logic [7:0] quotient = num2 / divisor;
          if (quotient != divisor && quotient != num2 && divisor < quotient) begin
            sum2 = sum2 + quotient;
          end
        end
      end
    end
  end

  assign match_flag = (sum1 == sum2);

endmodule