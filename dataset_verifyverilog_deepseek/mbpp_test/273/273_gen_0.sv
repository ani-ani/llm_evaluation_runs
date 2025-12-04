module elementwise_subtractor (
  input reg signed [3:0][6:0] tuple1,
  input reg signed [3:0][6:0] tuple2,
  output reg signed [3:0][6:0] result
);
  always_comb begin
    for (int i = 0; i < 4; i++) begin
      result[i] = tuple1[i] - tuple2[i];
    end
  end
endmodule