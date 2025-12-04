module remove_odd_numbers(
  input [7:0][7:0] data_in,
  output logic [7:0] mask_out,
  output [7:0][7:0] data_out
);
  assign data_out = data_in;
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      mask_out[i] = ~data_in[i][0];
    end
  end
endmodule