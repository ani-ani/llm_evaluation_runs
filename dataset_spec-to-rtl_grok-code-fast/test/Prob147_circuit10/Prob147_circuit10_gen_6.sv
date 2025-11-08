module TopModule(
  input clk,
  input a,
  input b,
  output q,
  output state
);
  reg state;
  always @(posedge clk) begin
    if (state == 0) begin
      state <= (a && b) ? 1 : 0;
    end else begin
      state <= (a && b) ? 0 : 1;
    end
  end
  assign q = (state == 0) ? (a ^ b) : (a == 0 ? 1 : b);
endmodule