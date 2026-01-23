module digitSum (
  input [7:0] char0,
  input [7:0] char1,
  input [7:0] char2,
  input [7:0] char3,
  input [7:0] char4,
  input [7:0] char5,
  input [7:0] char6,
  input [7:0] char7,
  output [15:0] sum
);

  wire [15:0] sum0 = (char0 >= 8'd65 && char0 <= 8'd90) ? char0 : 16'd0;
  wire [15:0] sum1 = (char1 >= 8'd65 && char1 <= 8'd90) ? char1 : 16'd0;
  wire [15:0] sum2 = (char2 >= 8'd65 && char2 <= 8'd90) ? char2 : 16'd0;
  wire [15:0] sum3 = (char3 >= 8'd65 && char3 <= 8'd90) ? char3 : 16'd0;
  wire [15:0] sum4 = (char4 >= 8'd65 && char4 <= 8'd90) ? char4 : 16'd0;
  wire [15:0] sum5 = (char5 >= 8'd65 && char5 <= 8'd90) ? char5 : 16'd0;
  wire [15:0] sum6 = (char6 >= 8'd65 && char6 <= 8'd90) ? char6 : 16'd0;
  wire [15:0] sum7 = (char7 >= 8'd65 && char7 <= 8'd90) ? char7 : 16'd0;

  assign sum = sum0 + sum1 + sum2 + sum3 + sum4 + sum5 + sum6 + sum7;

endmodule