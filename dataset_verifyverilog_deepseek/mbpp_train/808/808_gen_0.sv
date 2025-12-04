module tuple_element_checker (
  input [7:0] K,
  input [7:0][7:0] tuple_elements,
  output logic found
);

  logic [7:0] match_array;

  assign match_array[0] = (tuple_elements[0] == K);
  assign match_array[1] = (tuple_elements[1] == K);
  assign match_array[2] = (tuple_elements[2] == K);
  assign match_array[3] = (tuple_elements[3] == K);
  assign match_array[4] = (tuple_elements[4] == K);
  assign match_array[5] = (tuple_elements[5] == K);
  assign match_array[6] = (tuple_elements[6] == K);
  assign match_array[7] = (tuple_elements[7] == K);

  assign found = |match_array;

endmodule