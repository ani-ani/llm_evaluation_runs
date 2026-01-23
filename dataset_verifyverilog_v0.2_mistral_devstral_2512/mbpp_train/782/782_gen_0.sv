module odd_length_sum (
  input [7:0] arr_0,
  input [7:0] arr_1,
  input [7:0] arr_2,
  input [7:0] arr_3,
  input [7:0] arr_4,
  input [7:0] arr_5,
  input [7:0] arr_6,
  input [7:0] arr_7,
  input [2:0] length,
  output [31:0] result
);

  wire [31:0] sum = 0;
  wire [31:0] term0 = (length > 0) ? (arr_0 * ((1 * length + 1) / 2)) : 0;
  wire [31:0] term1 = (length > 1) ? (arr_1 * ((2 * (length - 1) + 1) / 2)) : 0;
  wire [31:0] term2 = (length > 2) ? (arr_2 * ((3 * (length - 2) + 1) / 2)) : 0;
  wire [31:0] term3 = (length > 3) ? (arr_3 * ((4 * (length - 3) + 1) / 2)) : 0;
  wire [31:0] term4 = (length > 4) ? (arr_4 * ((5 * (length - 4) + 1) / 2)) : 0;
  wire [31:0] term5 = (length > 5) ? (arr_5 * ((6 * (length - 5) + 1) / 2)) : 0;
  wire [31:0] term6 = (length > 6) ? (arr_6 * ((7 * (length - 6) + 1) / 2)) : 0;
  wire [31:0] term7 = (length > 7) ? (arr_7 * ((8 * (length - 7) + 1) / 2)) : 0;

  assign result = term0 + term1 + term2 + term3 + term4 + term5 + term6 + term7;

endmodule