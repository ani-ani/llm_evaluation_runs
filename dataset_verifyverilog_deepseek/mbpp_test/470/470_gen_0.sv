module pairwise_add (
  input [7:0][3:0] in_array,
  output [6:0][4:0] out_array
);

  always_comb begin
    for (int i = 0; i < 7; i++) begin
      out_array[i] = in_array[i] + in_array[i+1];
    end
  end

endmodule