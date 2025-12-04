module array_sum(
  input  [7:0]  arr [0:7],
  output [15:0] sum
);

  assign sum = arr[0] + arr[1] + arr[2] + arr[3]
             + arr[4] + arr[5] + arr[6] + arr[7];

endmodule