module factorial_last_digit (
  input [7:0] n,
  output [3:0] last_digit
);

  always_comb begin
    case (n)
      0: last_digit = 1;
      1: last_digit = 1;
      2: last_digit = 2;
      3: last_digit = 6;
      4: last_digit = 4;
      default: last_digit = 0;
    endcase
  end

endmodule