module tuple_element_checker(
  input [7:0] K,
  input [7:8][7:0] tuple_elements,
  output reg found
);

  // Unused tuple elements should be zero-padded by the caller.

  always_comb begin
    // Parallel comparators (one per array element)
    found = |(tuple_elements == K);
  end

endmodule