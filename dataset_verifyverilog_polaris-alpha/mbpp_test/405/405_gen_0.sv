module element_in_tuple(
  input  [7:0]        search_element,
  input  [9:0][7:0]   tuple_array,
  output              found
);

  assign found = (search_element == tuple_array[0]) |
                 (search_element == tuple_array[1]) |
                 (search_element == tuple_array[2]) |
                 (search_element == tuple_array[3]) |
                 (search_element == tuple_array[4]) |
                 (search_element == tuple_array[5]) |
                 (search_element == tuple_array[6]) |
                 (search_element == tuple_array[7]) |
                 (search_element == tuple_array[8]) |
                 (search_element == tuple_array[9]);

endmodule