module integer_division (
  input [15:0] dividend,
  input [15:0] divisor,
  output [15:0] quotient
);

  reg [15:0] remainder;
  reg [15:0] temp_quotient;
  integer i;

  always @* begin
    temp_quotient = 16'b0;
    remainder = dividend;

    for (i = 15; i >= 0; i = i - 1) begin
      remainder = remainder << 1;
      temp_quotient = temp_quotient << 1;

      if (remainder[16]) begin
        remainder[15:0] = remainder[15:0] - divisor;
        temp_quotient[0] = 1'b1;
      end
    end

    quotient = temp_quotient;
  end

endmodule