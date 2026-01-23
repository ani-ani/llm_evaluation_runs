module sensor_placement (
  input [5:0] a [0:7],
  input [5:0] b [0:7],
  input [2:0] n,
  output reg [31:0] ways
);

  reg [5:0] level [0:63];
  integer i, j, k, m;

  // Compute level for each coordinate x (0 to 63)
  for (i = 0; i < 64; i = i + 1) begin
    level[i] = 0;
    for (m = 0; m < n; m = m + 1) begin
      if (a[m] <= i && i <= b[m]) begin
        level[i] = level[i] + 1;
      end
    end
  end

  // Count valid triplets (i, j, k)
  ways = 0;
  for (i = 0; i < 62; i = i + 1) begin
    for (j = i + 1; j < 63; j = j + 1) begin
      for (k = j + 1; k < 64; k = k + 1) begin
        if (level[i] < level[j] && level[j] < level[k]) begin
          ways = ways + 1;
        end
      end
    end
  end

  // Modulo 1000000009 (though not strictly needed for this problem)
  ways = ways % 1000000009;

endmodule