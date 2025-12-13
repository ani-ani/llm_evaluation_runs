module count_trues(
  input  [7:0] lst,
  output [3:0] count
);
  wire [3:0] sum_low;
  wire [3:0] sum_high;

  assign sum_low  = lst[0] + lst[1] + lst[2] + lst[3];
  assign sum_high = lst[4] + lst[5] + lst[6] + lst[7];
  assign count    = sum_low + sum_high;

endmodule