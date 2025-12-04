module set_even_bits(
  input  [7:0] num,
  output reg [7:0] result
);
  always @(*) begin
    result = num | 8'h55;
  end
endmodule