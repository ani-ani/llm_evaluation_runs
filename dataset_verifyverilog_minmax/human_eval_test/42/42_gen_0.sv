module list_increment (
  input [7:0][7:0] l,
  output [7:0][7:0] result
);
  assign result[0] = l[0] + 1;
  assign result[1] = l[1] + 1;
  assign result[2] = l[2] + 1;
  assign result[3] = l[3] + 1;
  assign result[4] = l[4] + 1;
  assign result[5] = l[5] + 1;
  assign result[6] = l[6] + 1;
  assign result[7] = l[7] + 1;
endmodule