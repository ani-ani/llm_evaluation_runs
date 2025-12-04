module element_in_tuple (
  input [7:0] search_element,
  input [9:0][7:0] tuple_array,
  output logic found
);

  wire [9:0] match_flags;

  assign match_flags[0] = (tuple_array[0] == search_element);
  assign match_flags[1] = (tuple_array[1] == search_element);
  assign match_flags[2] = (tuple_array[2] == search_element);
  assign match_flags[3] = (tuple_array[3] == search_element);
  assign match_flags[4] = (tuple_array[4] == search_element);
  assign match_flags[5] = (tuple_array[5] == search_element);
  assign match_flags[6] = (tuple_array[6] == search_element);
  assign match_flags[7] = (tuple_array[7] == search_element);
  assign match_flags[8] = (tuple_array[8] == search_element);
  assign match_flags[9] = (tuple_array[9] == search_element);

  assign found = |match_flags;

endmodule