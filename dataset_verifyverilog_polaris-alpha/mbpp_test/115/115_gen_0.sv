module check_empty_dicts(
  input  [3:0] dict_list,
  output       all_empty
);

  assign all_empty = ~(|dict_list);

endmodule