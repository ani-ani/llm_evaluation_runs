module reverse_array (
  input [2:0] k,
  input [7:0][3:0] arr_in,
  output logic [7:0][3:0] arr_out
);

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      if (i < k) begin
        arr_out[i] = arr_in[k - 1 - i];
      end else begin
        arr_out[i] = arr_in[i];
      end
    end
  end

endmodule