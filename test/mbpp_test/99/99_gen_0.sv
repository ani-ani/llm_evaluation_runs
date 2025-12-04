module decimal_to_binary_converter(
  input  [15:0] decimal_in,
  output [15:0] binary_out,
  output [4:0]  significant_bits
);

  // Direct mapping (input is already 16-bit value to be represented in binary)
  assign binary_out = decimal_in;

  // Priority encoder to find MSB position (1-based index)
  assign significant_bits =
      (decimal_in[15]) ? 5'd16 :
      (decimal_in[14]) ? 5'd15 :
      (decimal_in[13]) ? 5'd14 :
      (decimal_in[12]) ? 5'd13 :
      (decimal_in[11]) ? 5'd12 :
      (decimal_in[10]) ? 5'd11 :
      (decimal_in[9])  ? 5'd10 :
      (decimal_in[8])  ? 5'd9  :
      (decimal_in[7])  ? 5'd8  :
      (decimal_in[6])  ? 5'd7  :
      (decimal_in[5])  ? 5'd6  :
      (decimal_in[4])  ? 5'd5  :
      (decimal_in[3])  ? 5'd4  :
      (decimal_in[2])  ? 5'd3  :
      (decimal_in[1])  ? 5'd2  :
      (decimal_in[0])  ? 5'd1  :
                         5'd1; // For input 0, per requirement

endmodule