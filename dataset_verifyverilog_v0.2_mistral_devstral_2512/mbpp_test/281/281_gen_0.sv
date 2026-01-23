module check_unique (
  input [7:0] data_0,
  input [7:0] data_1,
  input [7:0] data_2,
  input [7:0] data_3,
  input [7:0] data_4,
  input [7:0] data_5,
  input [7:0] data_6,
  input [7:0] data_7,
  output unique
);

  wire [27:0] comparisons;

  // Perform all pairwise comparisons
  assign comparisons[0]  = (data_0 == data_1);
  assign comparisons[1]  = (data_0 == data_2);
  assign comparisons[2]  = (data_0 == data_3);
  assign comparisons[3]  = (data_0 == data_4);
  assign comparisons[4]  = (data_0 == data_5);
  assign comparisons[5]  = (data_0 == data_6);
  assign comparisons[6]  = (data_0 == data_7);
  assign comparisons[7]  = (data_1 == data_2);
  assign comparisons[8]  = (data_1 == data_3);
  assign comparisons[9]  = (data_1 == data_4);
  assign comparisons[10] = (data_1 == data_5);
  assign comparisons[11] = (data_1 == data_6);
  assign comparisons[12] = (data_1 == data_7);
  assign comparisons[13] = (data_2 == data_3);
  assign comparisons[14] = (data_2 == data_4);
  assign comparisons[15] = (data_2 == data_5);
  assign comparisons[16] = (data_2 == data_6);
  assign comparisons[17] = (data_2 == data_7);
  assign comparisons[18] = (data_3 == data_4);
  assign comparisons[19] = (data_3 == data_5);
  assign comparisons[20] = (data_3 == data_6);
  assign comparisons[21] = (data_3 == data_7);
  assign comparisons[22] = (data_4 == data_5);
  assign comparisons[23] = (data_4 == data_6);
  assign comparisons[24] = (data_4 == data_7);
  assign comparisons[25] = (data_5 == data_6);
  assign comparisons[26] = (data_5 == data_7);
  assign comparisons[27] = (data_6 == data_7);

  // unique is high only if no comparisons are true
  assign unique = ~|comparisons;

endmodule