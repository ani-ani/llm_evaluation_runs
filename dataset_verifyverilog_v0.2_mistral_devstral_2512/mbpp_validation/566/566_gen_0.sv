module digit_sum (
  input [15:0] num,
  output [7:0] sum
);

  reg [7:0] digit_sum_reg = 0;
  reg [15:0] num_temp = num;
  integer i;

  always @* begin
    digit_sum_reg = 0;
    num_temp = num;
    for (i = 0; i < 5; i = i + 1) begin
      if (num_temp == 0) begin
        break;
      end
      digit_sum_reg = digit_sum_reg + (num_temp % 10);
      num_temp = num_temp / 10;
    end
  end

  assign sum = digit_sum_reg;

endmodule