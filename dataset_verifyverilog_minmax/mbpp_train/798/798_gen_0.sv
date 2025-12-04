module array_sum(
  input logic [7:0] arr[0:7],
  output logic [15:0] sum
);
  always_comb begin
    sum = 0;
    for (int i = 0; i < 8; i++) begin
      sum = sum + arr[i];
    end
  end
endmodule