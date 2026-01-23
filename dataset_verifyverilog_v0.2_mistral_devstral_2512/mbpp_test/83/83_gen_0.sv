module char_from_string (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  input [2:0] len,
  output [7:0] result_char
);

  wire [7:0] val_0 = (char_0 >= 8'h61 && char_0 <= 8'h7a) ? (char_0 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_1 = (char_1 >= 8'h61 && char_1 <= 8'h7a) ? (char_1 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_2 = (char_2 >= 8'h61 && char_2 <= 8'h7a) ? (char_2 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_3 = (char_3 >= 8'h61 && char_3 <= 8'h7a) ? (char_3 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_4 = (char_4 >= 8'h61 && char_4 <= 8'h7a) ? (char_4 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_5 = (char_5 >= 8'h61 && char_5 <= 8'h7a) ? (char_5 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_6 = (char_6 >= 8'h61 && char_6 <= 8'h7a) ? (char_6 - 8'h61 + 1'b1) : 8'h00;
  wire [7:0] val_7 = (char_7 >= 8'h61 && char_7 <= 8'h7a) ? (char_7 - 8'h61 + 1'b1) : 8'h00;

  wire [7:0] sum = val_0 + val_1 + val_2 + val_3 + val_4 + val_5 + val_6 + val_7;

  wire [4:0] mod_result;
  assign mod_result = (sum % 26);

  assign result_char = (mod_result == 0) ? 8'h7a : (8'h61 + mod_result - 1);

endmodule