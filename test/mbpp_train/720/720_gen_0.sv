module add_dict_to_tuple(
  input  [23:0]  tuple_data,
  input  [71:0]  dict_data,
  output [127:0] result
);

  assign result[7:0]    = tuple_data[7:0];
  assign result[15:8]   = tuple_data[15:8];
  assign result[23:16]  = tuple_data[23:16];

  // Place dictionary data in [24:95]; remaining [96:127] padded with zeros
  assign result[95:24]  = dict_data;
  assign result[127:96] = 32'b0;

endmodule