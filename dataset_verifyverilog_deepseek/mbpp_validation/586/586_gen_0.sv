module array_rotator (
  input [2:0] n,
  input [7:0] arr [0:7],
  output logic [7:0] result [0:7]
);

  always_comb begin
    for (int i=0; i<8; i++) begin
      int idx = (n + i) % 8;
      result[i] = arr[idx];
    end
  end

endmodule