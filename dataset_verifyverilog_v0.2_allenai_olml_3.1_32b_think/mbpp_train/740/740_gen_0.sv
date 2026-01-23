module tuple_to_dict (
  input [7:0] tuple_data [0:7],
  input [2:0] valid_count,
  output reg [7:0] key_0, key_1, key_2, key_3,
  output reg [7:0] val_0, val_1, val_2, val_3,
  output reg [2:0] pair_count
);
  assign pair_count = valid_count >> 1;
  assign key_0 = (pair_count >= 1) ? tuple_data[0] : 8'b0;
  assign val_0 = (pair_count >= 1) ? tuple_data[1] : 8'b0;
  assign key_1 = (pair_count >= 2) ? tuple_data[2] : 8'b0;
  assign val_1 = (pair_count >= 2) ? tuple_data[3] : 8'b0;
  assign key_2 = (pair_count >= 3) ? tuple_data[4] : 8'b0;
  assign val_2 = (pair_count >= 3) ? tuple_data[5] : 8'b0;
  assign key_3 = (pair_count >= 4) ? tuple_data[6] : 8'b0;
  assign val_3 = (pair_count >= 4) ? tuple_data[7] : 8'b0;
endmodule