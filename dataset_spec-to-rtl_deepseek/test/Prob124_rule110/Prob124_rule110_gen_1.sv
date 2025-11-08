module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);
  reg [511:0] next_q;

  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end

  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic left, center, right;
      center = q[i];
      left = (i == 511) ? 1'b0 : q[i+1];
      right = (i == 0) ? 1'b0 : q[i-1];
      next_q[i] = ~( (left & center & right) | (~center & ~right) );
    end
  end
endmodule