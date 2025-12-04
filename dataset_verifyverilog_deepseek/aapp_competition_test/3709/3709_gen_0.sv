module interesting_problemset(
  input [15:0] valid,
  input [63:0] problems,
  output result
);
  logic cond1, cond2;
  integer i, m, n;
  
  always_comb begin
    cond1 = 1'b0;
    for (i = 0; i < 16; i = i + 1) begin
      if (valid[i] && (problems[i*4 +: 4] == 4'b0000)) begin
        cond1 = 1'b1;
      end
    end

    cond2 = 1'b0;
    for (m = 0; m < 16; m = m + 1) begin
      for (n = m + 1; n < 16; n = n + 1) begin
        if (valid[m] && valid[n] && ((problems[m*4 +: 4] & problems[n*4 +: 4]) == 4'b0000)) begin
          cond2 = 1'b1;
        end
      end
    end
  end

  assign result = cond1 || cond2;
endmodule