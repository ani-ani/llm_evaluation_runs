module tuple_xor(
    input [3:0] tuple1 [0:3],
    input [3:0] tuple2 [0:3],
    output reg [3:0] result [0:3]
);

  always_comb begin
    for (int i = 0; i < 4; i = i + 1) begin
      result[i] = tuple1[i] ^ tuple2[i];
    end
  end

endmodule