module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);

reg [2:0] count;

always @(posedge clk) begin
  if (reset) begin
    count <= 3'b000;
    disc  <= 1'b0;
    flag  <= 1'b0;
    err   <= 1'b0;
  end else begin
    if (in) begin
      if (count < 3'd7) count <= count + 1;
    end else begin
      count <= 3'b000;
    end
    disc <= (count == 3'd5) && !in;
    flag <= (count == 3'd6) && !in;
    err  <= (count == 3'd6) && in;
  end
end

endmodule