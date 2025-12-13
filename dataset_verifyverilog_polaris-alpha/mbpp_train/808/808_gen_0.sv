module tuple_element_checker(
  input  [7:0]      K,
  input  [7:0][7:0] tuple_elements,
  output            found
);

  wire [7:0] cmp_eq;

  assign cmp_eq[0] = (tuple_elements[0] == K);
  assign cmp_eq[1] = (tuple_elements[1] == K);
  assign cmp_eq[2] = (tuple_elements[2] == K);
  assign cmp_eq[3] = (tuple_elements[3] == K);
  assign cmp_eq[4] = (tuple_elements[4] == K);
  assign cmp_eq[5] = (tuple_elements[5] == K);
  assign cmp_eq[6] = (tuple_elements[6] == K);
  assign cmp_eq[7] = (tuple_elements[7] == K);

  assign found = |cmp_eq;

endmodule