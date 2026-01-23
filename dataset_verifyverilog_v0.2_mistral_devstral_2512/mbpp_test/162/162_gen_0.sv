module sum_series (
  input [7:0] n,
  output reg [15:0] result
);

  integer i;
  reg [15:0] term;
  reg [15:0] sum;

  always @* begin
    sum = 16'b0;
    for (i = 0; i < 16; i = i + 1) begin
      term = n - (2 * i);
      if (term <= 0) begin
        break;
      end
      sum = sum + term;
    end
    result = sum;
  end

endmodule