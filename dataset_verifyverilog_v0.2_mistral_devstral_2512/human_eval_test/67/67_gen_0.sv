module fruit_distribution(
  input [7:0] apples_str,
  input [7:0] oranges_str,
  input [7:0] total_fruits,
  output [7:0] mangoes
);

  wire [7:0] apples = apples_str;
  wire [7:0] oranges = oranges_str;
  wire [8:0] temp_result = total_fruits - apples - oranges;
  assign mangoes = (temp_result[8]) ? 8'd0 : temp_result[7:0];

endmodule