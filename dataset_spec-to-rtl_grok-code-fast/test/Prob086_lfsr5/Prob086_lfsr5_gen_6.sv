module TopModule(
  input clk,
  input reset,
  output reg [4:0] q
);
always @(posedge clk or posedge reset) begin
  if (reset) q <= 5'd1;
  else begin
    q[0] <= q[4] ^ q[2];
    q[1] <= q[0];
    q[2] <= q[1];
    q[3] <= q[2];
    q[4] <= q[3];
  end
end
endmodule