module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);

  logic [511:0] next_state;

  always_comb begin
    for (int i=0; i<512; i++) begin
      bit left, right;
      left = (i == 511) ? 1'b0 : q[i+1];
      right = (i == 0) ? 1'b0 : q[i-1];
      next_state[i] = (left & q[i] & ~right) | (~left & q[i]) | (~q[i] & right);
    end
  end

  always_ff @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      q <= next_state;
    end
  end

endmodule