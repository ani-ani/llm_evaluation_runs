module a_start_b_end (
  input  [63:0] str_bytes,
  output logic match_flag
);
  // combinational logic: check first byte is 'a' (0x61) and last byte is 'b' (0x62)
  assign match_flag = (str_bytes[63:56] == 8'h61) && (str_bytes[7:0] == 8'h62);
endmodule