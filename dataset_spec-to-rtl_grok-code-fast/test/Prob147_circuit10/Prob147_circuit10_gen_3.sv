module TopModule(
  input clk,
  input a,
  input b,
  output reg state,
  output q
);
  always @( posedge clk ) begin
     if (a == b) begin
       state <= ~state;
     end
  end
  assign q = state ^ (a ^ b);
endmodule
