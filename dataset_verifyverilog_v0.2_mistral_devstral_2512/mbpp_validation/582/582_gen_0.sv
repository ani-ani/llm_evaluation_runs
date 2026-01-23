module dict_empty_check(
  input is_empty,
  output reg result
);
  always @(*) begin
    result = is_empty;
  end
endmodule