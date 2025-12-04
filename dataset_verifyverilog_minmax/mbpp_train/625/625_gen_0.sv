module swap_first_last (
  input [2:0] array_size,
  input [7:0] arr_in [0:7],
  output reg [7:0] arr_out [0:7]
);

  integer i;
  always_comb begin
    if (array_size >= 3'd2) begin
      arr_out[0] = arr_in[array_size - 3'd1];
      arr_out[array_size - 3'd1] = arr_in[0];
      for (i = 0; i < 8; i = i + 1) begin
        if (i != 0 && i != (array_size - 3'd1)) begin
          arr_out[i] = arr_in[i];
        end
      end
    end else begin
      for (i = 0; i < 8; i = i + 1) begin
        arr_out[i] = arr_in[i];
      end
    end
  end

endmodule
