module array_rotator(
  input  [2:0]      n,
  input  [7:0]      arr [0:7],
  output reg [7:0]  result [0:7]
);

  integer i;

  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      if (n == 0)
        result[i] = arr[i];
      else
        result[i] = arr[(n + i) % 8];
    end
  end

endmodule