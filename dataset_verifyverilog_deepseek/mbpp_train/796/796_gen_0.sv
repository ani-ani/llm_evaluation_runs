module dict_sum (
  input [9:0] val0,
  input [9:0] val1,
  input [9:0] val2,
  input [9:0] val3,
  output logic [10:0] sum_total
);
  assign sum_total = val0 + val1 + val2 + val3;
endmodule