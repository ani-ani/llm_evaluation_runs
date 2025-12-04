module distinct_check (
  input [7:0] arr [0:7],
  output logic result
);
  logic all_same;
  always_comb begin
    all_same = 1'b1;
    for (int i = 0; i < 8; i++) begin
      if (arr[i] !== arr[0]) begin
        all_same = 1'b0;
        break;
      end
    end
    result = all_same;
  end
endmodule