module tuple_to_int (
  input [3:0] digit_0,
  input [3:0] digit_1,
  input [3:0] digit_2,
  input [3:0] digit_3,
  input [3:0] digit_4,
  input [3:0] digit_5,
  input [3:0] digit_6,
  input [3:0] digit_7,
  output [31:0] result
);

  wire [31:0] term_0 = digit_0;
  wire [31:0] term_1 = digit_1 * 10;
  wire [31:0] term_2 = digit_2 * 100;
  wire [31:0] term_3 = digit_3 * 1000;
  wire [31:0] term_4 = digit_4 * 10000;
  wire [31:0] term_5 = digit_5 * 100000;
  wire [31:0] term_6 = digit_6 * 1000000;
  wire [31:0] term_7 = digit_7 * 10000000;

  assign result = term_0 + term_1 + term_2 + term_3 + term_4 + term_5 + term_6 + term_7;

endmodule