module dict_empty_check(
  input  [8:0] entries [0:7],
  output       empty_flag
);

  assign empty_flag = ~(|{entries[0][8], entries[1][8], entries[2][8], entries[3][8],
                          entries[4][8], entries[5][8], entries[6][8], entries[7][8]});

endmodule