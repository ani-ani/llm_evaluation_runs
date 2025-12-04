module starts_with_vowel (input reg [63:0] str_packed, output reg result);
  always_comb begin
    result = (str_packed[63:56] == 8'h41) ||
             (str_packed[63:56] == 8'h45) ||
             (str_packed[63:56] == 8'h49) ||
             (str_packed[63:56] == 8'h4F) ||
             (str_packed[63:56] == 8'h55) ||
             (str_packed[63:56] == 8'h61) ||
             (str_packed[63:56] == 8'h65) ||
             (str_packed[63:56] == 8'h69) ||
             (str_packed[63:56] == 8'h6F) ||
             (str_packed[63:56] == 8'h75);
  end
endmodule