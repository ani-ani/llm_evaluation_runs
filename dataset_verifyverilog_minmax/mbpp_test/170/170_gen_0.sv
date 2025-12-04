module array_range_sum (
  input [127:0] array_data,
  input [3:0] start_idx,
  input [3:0] end_idx,
  output [11:0] range_sum
);

  // Unpack 16 elements of 8-bit data from the 128-bit vector
  // array_data[7:0]    -> elem[0] (LSB)
  // array_data[127:120]-> elem[15] (MSB)
  logic [7:0] elem [0:15];
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : UNPACK
      assign elem[i] = array_data[(i+1)*8 - 1 -: 8];
    end
  endgenerate

  // Sum in the range [start_idx, end_idx]; return 0 if start > end
  logic [11:0] sum;
  logic valid_range;

  assign valid_range = (start_idx <= end_idx);
  assign range_sum = valid_range ? sum : 12'd0;

  logic [11:0] sum_q [0:15];
  assign sum_q[0] = (0 >= start_idx && 0 <= end_idx) ? {4'd0, elem[0]} : 12'd0;

  genvar j;
  generate
    for (j = 1; j < 16; j = j + 1) begin : RANGE_SUM
      logic in_range;
      assign in_range = (j >= start_idx && j <= end_idx);
      assign sum_q[j] = sum_q[j-1] + (in_range ? {4'd0, elem[j]} : 12'd0);
    end
  endgenerate

  assign sum = sum_q[15];

endmodule