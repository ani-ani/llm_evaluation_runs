module last_digit(input reg [7:0] n, output reg [3:0] digit);
  always_comb begin
    digit = n % 10;
  end
endmodule