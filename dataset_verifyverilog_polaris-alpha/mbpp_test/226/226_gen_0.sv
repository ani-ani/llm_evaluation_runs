module even_char_filter(
  input  [7:0]  str_length,
  input  [63:0] input_str,
  output [63:0] filtered_str,
  output [7:0]  out_length
);

  // Compute ceil(str_length/2)
  assign out_length = (str_length + 8'd1) >> 1;

  // Helper wires to indicate if each even index is valid
  wire valid0 = (str_length > 8'd0);
  wire valid2 = (str_length > 8'd2);
  wire valid4 = (str_length > 8'd4);
  wire valid6 = (str_length > 8'd6);

  // Extract even-indexed bytes from input_str (byte 0 is LSB [7:0])
  wire [7:0] b0 = input_str[7:0];
  wire [7:0] b2 = input_str[23:16];
  wire [7:0] b4 = input_str[39:32];
  wire [7:0] b6 = input_str[55:48];

  // Place valid even-index bytes contiguously at the LSB side
  assign filtered_str = {
    32'd0,
    (valid6 ? b6 : 8'd0),
    (valid4 ? b4 : 8'd0),
    (valid2 ? b2 : 8'd0),
    (valid0 ? b0 : 8'd0)
  };

endmodule