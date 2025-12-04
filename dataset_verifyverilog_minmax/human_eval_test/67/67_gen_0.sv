module fruit_distribution (
  input [7:0] apples,
  input [7:0] oranges,
  input [7:0] total,
  output [7:0] mangoes
);
  assign mangoes = total - apples - oranges;
endmodule