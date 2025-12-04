module array_comparator(
  input  [3:0]       number,
  input  [7:0][3:0]  arr,
  output             result
);

  reg [3:0] max_val;

  always @* begin
    max_val = arr[0];
    if (arr[1] > max_val) max_val = arr[1];
    if (arr[2] > max_val) max_val = arr[2];
    if (arr[3] > max_val) max_val = arr[3];
    if (arr[4] > max_val) max_val = arr[4];
    if (arr[5] > max_val) max_val = arr[5];
    if (arr[6] > max_val) max_val = arr[6];
    if (arr[7] > max_val) max_val = arr[7];
  end

  assign result = (number > max_val) ? 1'b1 : 1'b0;

endmodule