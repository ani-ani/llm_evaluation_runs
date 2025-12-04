module tuple_to_int(input [15:0] digits, output [13:0] result);
  wire [3:0] digit3 = digits[15:12];
  wire [3:0] digit2 = digits[11:8];
  wire [3:0] digit1 = digits[7:4];
  wire [3:0] digit0 = digits[3:0];
  assign result = (digit3 * 14'd1000) + (digit2 * 14'd100) + (digit1 * 14'd10) + digit0;
endmodule