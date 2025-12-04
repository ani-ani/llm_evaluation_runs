module add_dict_to_tuple (
  input [23:0] tuple_data,
  input [71:0] dict_data,
  output logic [127:0] result
);
  assign result = {32'b0, dict_data, tuple_data};
endmodule
