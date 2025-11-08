module TopModule(
  input clk,
  input reset,
  output reg [4:0] q
);

always_ff @(posedge clk) begin
  if (reset)
    q <= 5'b1;
  else
    q <= {q[2] ^ q[0], q[4:1]};
end

endmodule