module dict_sum(
  input [9:0] val0,  // Dictionary value 1 (10-bit unsigned)
  input [9:0] val1,  // Dictionary value 2
  input [9:0] val2,  // Dictionary value 3
  input [9:0] val3,  // Dictionary value 4
  output [10:0] sum_total  // 11-bit sum of all non-zero values (val0 + val1 + val2 + val3)
);

  // Combinational sum: unused slots should be set to 0 in instantiation
  assign sum_total = val0 + val1 + val2 + val3;

endmodule
