module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);

  always @(posedge clk) begin
    if (load) q <= data;
    else begin
      for (int i = 0; i < 512; i++) begin
        logic l, c, r;
        l = (i < 511) ? q[i+1] : 0;
        c = q[i];
        r = (i > 0) ? q[i-1] : 0;
        if (l && c && r) q[i] <= 0;
        else if (l && c && !r) q[i] <= 1;
        else if (l && !c && r) q[i] <= 1;
        else if (l && !c && !r) q[i] <= 0;
        else if (!l && c && r) q[i] <= 1;
        else if (!l && c && !r) q[i] <= 1;
        else if (!l && !c && r) q[i] <= 1;
        else q[i] <= 0;
      end
    end
  end

endmodule