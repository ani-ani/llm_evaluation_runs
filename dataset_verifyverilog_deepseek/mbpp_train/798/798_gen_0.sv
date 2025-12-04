module array_sum(
  input [7:0] arr[0:7],
  output logic [15:0] sum
);

  always_comb begin
    sum = 16'b0;
    for (int i = 0; i < 8; i++)
      sum = sum + arr[i];
  end

endmodule