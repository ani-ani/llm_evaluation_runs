module min_unique_substring(
  input [3:0] n,
  input [3:0] k,
  output reg [15:0] s
);

  always_comb begin
    int a;
    int pattern_length;
    int counter;
    if (k == n) begin
      s = (16'b1 << n) - 1'b1;
    end else begin
      a = (n - k) >> 1;
      pattern_length = a + 1;
      counter = 0;
      for (int i = 0; i < 16; i = i + 1) begin
        if (i < n) begin
          s[i] = (counter < a) ? 1'b0 : 1'b1;
          counter = counter + 1;
          if (counter == pattern_length) counter = 0;
        end else begin
          s[i] = 1'b0;
        end
      end
    end
  end

endmodule