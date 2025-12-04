module triples_sum_zero(
  input logic signed [7:0] arr [0:7], // 8 8-bit signed integers (2's complement)
  output logic out                   // 1 if any 3 distinct elements sum to zero, else 0
);
  logic signed [7:0] sum3;
  integer i, j, k;

  always_comb begin
    out = 1'b0;
    for (i = 0; i < 8 && !out; i++) begin
      for (j = i + 1; j < 8 && !out; j++) begin
        for (k = j + 1; k < 8 && !out; k++) begin
          sum3 = arr[i] + arr[j] + arr[k];
          if (sum3 == 8'sb0) out = 1'b1;
        end
      end
    end
  end
endmodule