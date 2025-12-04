module min_unique_substring(
  input reg [3:0] n,
  input reg [3:0] k,
  output reg [15:0] s
);

  always_comb begin
    integer a;
    a = (n - k) / 2;
    for (int i = 0; i < 16; i++) begin
      if (i < n) begin
        if (k == n) s[i] = 1'b1;
        else begin
          s[i] = (i % (a + 1) < a) ? 1'b0 : 1'b1;
        end
      end else begin
        s[i] = 1'b0;
      end
    end
  end

endmodule