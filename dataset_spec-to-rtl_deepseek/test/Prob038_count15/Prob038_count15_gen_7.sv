module TopModule (input clk, input reset, output logic [3:0] q);
always_ff @(posedge clk) begin
  if (reset) begin
    q <= 4'b0;
  end else begin
    q <= q + 4'b1;
  end
end
endmodule