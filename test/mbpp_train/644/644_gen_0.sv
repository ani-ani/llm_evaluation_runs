module reverse_array(
  input      [2:0]      k,
  input      [7:0][3:0] arr_in,
  output reg [7:0][3:0] arr_out
);

  integer i;

  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      if (i < k)
        arr_out[i] = arr_in[k - 1 - i];
      else
        arr_out[i] = arr_in[i];
    end
  end

endmodule