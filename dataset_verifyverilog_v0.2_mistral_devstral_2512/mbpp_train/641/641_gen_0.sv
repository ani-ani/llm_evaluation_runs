module nonagonal_number (
  input [15:0] n,
  output [15:0] result
);

  wire [15:0] temp1 = 7 * n;
  wire [15:0] temp2 = temp1 - 5;
  wire [15:0] temp3 = n * temp2;
  assign result = temp3 >> 1;

endmodule