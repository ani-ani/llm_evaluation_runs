module triplet_counter(
  input reg [3:0] n,
  output reg [5:0] count
);

  // Compute a_mod3 for i=1..8
  int a_mod3[9];
  integer i, j, k;

  always_comb begin
    for (i = 1; i <= 8; i = i + 1) begin
      a_mod3[i] = (i * i - i + 1) % 3;
    end

    count = 0;
    for (i = 1; i <= 6; i = i + 1) begin
      for (j = i + 1; j <= 7; j = j + 1) begin
        for (k = j + 1; k <= 8; k = k + 1) begin
          if ((i <= n) && (j <= n) && (k <= n) && ((a_mod3[i] + a_mod3[j] + a_mod3[k]) % 3 == 0)) begin
            count = count + 1;
          end
        end
      end
    end
  end

endmodule