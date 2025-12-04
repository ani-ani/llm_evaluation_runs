module element_in_tuple(
  input [7:0] search_element,
  input [9:0][7:0] tuple_array,
  output logic found
);

  logic [9:0] matches;

  genvar i;
  generate
    for (i = 0; i < 10; i++) begin : gen_eq
      assign matches[i] = (search_element == tuple_array[i]);
    end
  endgenerate

  assign found = |matches;

endmodule
