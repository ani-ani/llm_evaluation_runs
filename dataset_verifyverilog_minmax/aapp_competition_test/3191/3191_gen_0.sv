module crashing_line_cost(
  input [3:0] n,
  input [31:0] r,
  input [31:0] p,
  output reg [31:0] cost
);

  // Precompute T values for n = 1..16 using the recurrence relation
  integer T [0:16];
  integer k, t, seg, cand;

  initial begin
    T[0] = 0;
    T[1] = 0;
    for (t = 2; t <= 16; t = t + 1) begin
      T[t] = 32'h7fffffff; // large positive number
      for (k = 1; k <= t - 1; k = k + 1) begin
        seg = (t + k) / (k + 1); // ceil(t / (k+1))
        cand = p * k + r + T[seg];
        if (cand < T[t]) T[t] = cand;
      end
    end
  end

  always @(*) begin
    if (n <= 4'd1)
      cost = 32'd0;
    else if (n > 4'd16)
      cost = 32'd0; // undefined for n > 16; default to 0
    else
      cost = T[n];
  end

endmodule
