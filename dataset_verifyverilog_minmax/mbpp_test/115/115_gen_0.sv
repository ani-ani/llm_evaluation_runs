module check_empty_dicts (
  input [3:0] dict_list,
  output wire all_empty
);
  
  // all_empty is 1 when all bits in dict_list are 0
  assign all_empty = ~|dict_list;
  
endmodule