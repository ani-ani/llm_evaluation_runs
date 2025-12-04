module swap_first_last (
  input [2:0] array_size,
  input [7:0] arr_in [0:7],
  output logic [7:0] arr_out [0:7]
);

  always_comb begin
    for (int i=0; i<8; i++) begin
      arr_out[i] = arr_in[i];
    end
    if (array_size >= 2) begin
      arr_out[0] = arr_in[array_size-1];
      arr_out[array_size-1] = arr_in[0];
    end
  end
endmodule