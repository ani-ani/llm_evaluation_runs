module TopModule (
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);
  logic [511:0] next_q;

  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic left, center, right;
      // Boundary conditions
      if (i == 0) begin
        left = q[1];
        center = q[0];
        right = 1'b0;
      end else if (i == 511) begin
        left = 1'b0;
        center = q[511];
        right = q[510];
      end else begin
        left = q[i+1];
        center = q[i];
        right = q[i-1];
      end
      // Rule 110 logic
      next_q[i] = (left & center & ~right) | (left & ~center & right) | (~left & center) | (~left & right);
    end
  end

  always_ff @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end
endmodule