module even_char_filter(input [7:0] str_length, input [63:0] input_str, output [63:0] filtered_str, output [7:0] out_length);
  wire [7:0] byte0 = (str_length >= 8'd1) ? input_str[63-:8] : 8'd0;
  wire [7:0] byte1 = (str_length >= 8'd3) ? input_str[55-:8] : 8'd0;
  wire [7:0] byte2 = (str_length >= 8'd5) ? input_str[47-:8] : 8'd0;
  wire [7:0] byte3 = (str_length >= 8'd7) ? input_str[39-:8] : 8'd0;
  assign filtered_str = {byte0, byte1, byte2, byte3, 32'd0};
  assign out_length = (str_length + 8'd1) >> 1;
endmodule