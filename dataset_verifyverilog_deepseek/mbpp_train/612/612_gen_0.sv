module array_transposer (
  input [3:0][3:0][7:0] arr_in,
  output logic [3:0][3:0][7:0] arr_out
);

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        arr_out[i][j] = arr_in[j][i];
      end
    end
  end

endmodule