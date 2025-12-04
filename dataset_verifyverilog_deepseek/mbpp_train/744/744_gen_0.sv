module none_check (
  input [4:0][7:0] tuple_in,
  output logic res
);
  always_comb begin
    res = (tuple_in[0] == 8'hFF) |
           (tuple_in[1] == 8'hFF) |
           (tuple_in[2] == 8'hFF) |
           (tuple_in[3] == 8'hFF) |
           (tuple_in[4] == 8'hFF);
  end
endmodule