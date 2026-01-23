module bool_count (
  input [7:0] data,
  output [3:0] count
);

  wire [1:0] sum1 = data[7] + data[6];
  wire [1:0] sum2 = data[5] + data[4];
  wire [1:0] sum3 = data[3] + data[2];
  wire [1:0] sum4 = data[1] + data[0];
  wire [2:0] sum5 = sum1 + sum2;
  wire [2:0] sum6 = sum3 + sum4;
  wire [3:0] sum7 = sum5 + sum6;

  assign count = sum7;

endmodule