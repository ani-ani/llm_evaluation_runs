module last_fact_digit(
  input reg [4:0] n,
  output reg [3:0] last_digit
);
  always @(*) begin
    case (n)
      5'b0, 5'b1: last_digit = 4'b0001;
      5'b2: last_digit = 4'b0010;
      5'b3: last_digit = 4'b0110;
      5'b4: last_digit = 4'b0100;
      5'b5, 5'b6, 5'b7, 5'b8, 5'b9,
      5'b10, 5'b11, 5'b12, 5'b13, 5'b14,
      5'b15, 5'b16, 5'b17, 5'b18, 5'b19,
      5'b20, 5'b21, 5'b22, 5'b23, 5'b24,
      5'b25, 5'b26, 5'b27, 5'b28, 5'b29,
      5'b30, 5'b31: last_digit = 4'b0000;
      default: last_digit = 4'b0;
    endcase
  end
endmodule