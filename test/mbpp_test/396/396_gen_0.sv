module start_end_same(
  input  [7:0] first_char,
  input  [7:0] last_char,
  output       match
);

  assign match = (first_char == last_char);

endmodule