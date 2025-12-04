module a_start_b_end (
  input  [63:0] str_bytes,
  output        match_flag
);

  assign match_flag = (str_bytes[63:56] == 8'h61) &&
                      (str_bytes[7:0]   == 8'h62);

endmodule