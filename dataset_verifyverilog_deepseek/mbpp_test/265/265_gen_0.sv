module list_splitter (
  input [7:0] data [0:7],
  input [2:0] step,
  output [63:0] sublists
);
  wire [7:0] sub0_0, sub0_1, sub1_0, sub1_1, sub2_0, sub2_1, sub3_0, sub3_1;

  assign sub0_0 = (0 < step) ? data[0] : 8'b0;
  assign sub0_1 = ((0 < step) && ((0 + step) < 8)) ? data[0 + step] : 8'b0;

  assign sub1_0 = (1 < step) ? data[1] : 8'b0;
  assign sub1_1 = ((1 < step) && ((1 + step) < 8)) ? data[1 + step] : 8'b0;

  assign sub2_0 = (2 < step) ? data[2] : 8'b0;
  assign sub2_1 = ((2 < step) && ((2 + step) < 8)) ? data[2 + step] : 8'b0;

  assign sub3_0 = (3 < step) ? data[3] : 8'b0;
  assign sub3_1 = ((3 < step) && ((3 + step) < 8)) ? data[3 + step] : 8'b0;

  assign sublists = {sub3_1, sub3_0, sub2_1, sub2_0, sub1_1, sub1_0, sub0_1, sub0_0};
endmodule