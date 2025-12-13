module case_reverse_or_invert(
  input  [63:0] str_in,
  output [63:0] str_out
);

  wire [7:0] c0_in = str_in[63:56];
  wire [7:0] c1_in = str_in[55:48];
  wire [7:0] c2_in = str_in[47:40];
  wire [7:0] c3_in = str_in[39:32];
  wire [7:0] c4_in = str_in[31:24];
  wire [7:0] c5_in = str_in[23:16];
  wire [7:0] c6_in = str_in[15:8];
  wire [7:0] c7_in = str_in[7:0];

  wire [7:0] c0_conv = (c0_in >= 8'd97 && c0_in <= 8'd122) ? (c0_in - 8'd32) :
                       (c0_in >= 8'd65 && c0_in <= 8'd90)  ? (c0_in + 8'd32) : c0_in;
  wire [7:0] c1_conv = (c1_in >= 8'd97 && c1_in <= 8'd122) ? (c1_in - 8'd32) :
                       (c1_in >= 8'd65 && c1_in <= 8'd90)  ? (c1_in + 8'd32) : c1_in;
  wire [7:0] c2_conv = (c2_in >= 8'd97 && c2_in <= 8'd122) ? (c2_in - 8'd32) :
                       (c2_in >= 8'd65 && c2_in <= 8'd90)  ? (c2_in + 8'd32) : c2_in;
  wire [7:0] c3_conv = (c3_in >= 8'd97 && c3_in <= 8'd122) ? (c3_in - 8'd32) :
                       (c3_in >= 8'd65 && c3_in <= 8'd90)  ? (c3_in + 8'd32) : c3_in;
  wire [7:0] c4_conv = (c4_in >= 8'd97 && c4_in <= 8'd122) ? (c4_in - 8'd32) :
                       (c4_in >= 8'd65 && c4_in <= 8'd90)  ? (c4_in + 8'd32) : c4_in;
  wire [7:0] c5_conv = (c5_in >= 8'd97 && c5_in <= 8'd122) ? (c5_in - 8'd32) :
                       (c5_in >= 8'd65 && c5_in <= 8'd90)  ? (c5_in + 8'd32) : c5_in;
  wire [7:0] c6_conv = (c6_in >= 8'd97 && c6_in <= 8'd122) ? (c6_in - 8'd32) :
                       (c6_in >= 8'd65 && c6_in <= 8'd90)  ? (c6_in + 8'd32) : c6_in;
  wire [7:0] c7_conv = (c7_in >= 8'd97 && c7_in <= 8'd122) ? (c7_in - 8'd32) :
                       (c7_in >= 8'd65 && c7_in <= 8'd90)  ? (c7_in + 8'd32) : c7_in;

  wire any_letter = (c0_conv != c0_in) |
                    (c1_conv != c1_in) |
                    (c2_conv != c2_in) |
                    (c3_conv != c3_in) |
                    (c4_conv != c4_in) |
                    (c5_conv != c5_in) |
                    (c6_conv != c6_in) |
                    (c7_conv != c7_in);

  assign str_out = any_letter ?
                   {c0_conv, c1_conv, c2_conv, c3_conv, c4_conv, c5_conv, c6_conv, c7_conv} :
                   {c7_in,   c6_in,   c5_in,   c4_in,   c3_in,   c2_in,   c1_in,   c0_in};

endmodule