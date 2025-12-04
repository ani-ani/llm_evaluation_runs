module start_end_same(input reg [7:0] first_char, input reg [7:0] last_char, output logic match);
  assign match = (first_char == last_char);
endmodule