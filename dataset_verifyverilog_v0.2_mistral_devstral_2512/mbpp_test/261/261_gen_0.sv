module tuple_division (
  input [7:0] dividend [0:3],
  input [7:0] divisor [0:3],
  output reg [7:0] quotient [0:3]
);

  always @* begin
    quotient[0] = dividend[0] / divisor[0];
    quotient[1] = dividend[1] / divisor[1];
    quotient[2] = dividend[2] / divisor[2];
    quotient[3] = dividend[3] / divisor[3];
  end

endmodule