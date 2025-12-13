module min_unique_substring(
  input [3:0] n,
  input [3:0] k,
  output [15:0] s
);

  integer i;
  reg [15:0] s_reg;
  integer a;
  integer idx;
  integer cnt;

  always @* begin
    s_reg = 16'b0;
    a = (n - k) >> 1;

    if (n == k) begin
      // Case 1: all ones for first n bits
      for (i = 0; i < 16; i = i + 1) begin
        if (i < n)
          s_reg[i] = 1'b1;
        else
          s_reg[i] = 1'b0;
      end
    end else begin
      // Case 2: pattern of a zeros followed by 1, repeated to length n
      idx = 0;
      while (idx < n) begin
        // place 'a' zeros
        cnt = 0;
        while ((cnt < a) && (idx < n)) begin
          s_reg[idx] = 1'b0;
          idx = idx + 1;
          cnt = cnt + 1;
        end
        // place '1'
        if (idx < n) begin
          s_reg[idx] = 1'b1;
          idx = idx + 1;
        end
      end
      // zero-fill remaining bits
      for (i = n; i < 16; i = i + 1) begin
        s_reg[i] = 1'b0;
      end
    end
  end

  assign s = s_reg;

endmodule