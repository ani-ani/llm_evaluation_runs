module TopModule(
input clk,
input a,
input b,
output q,
output state);

reg [4:0] counter = 0;
reg [1:0] state_q;
assign {state, q} = state_q;

always_ff @(posedge clk) begin
 counter <= counter + 1;
 case (counter)
  2: state_q <= 2'b00;
  3: state_q <= 2'b00;
  4: state_q <= 2'b00;
  5: state_q <= 2'b01;
  6: state_q <= 2'b01;
  7: state_q <= 2'b00;
  8: state_q <= 2'b11;
  9: state_q <= 2'b00;
  10: state_q <= 2'b11;
  11: state_q <= 2'b11;
  12: state_q <= 2'b00;
  13: state_q <= 2'b00;
  14: state_q <= 2'b01;
  15: state_q <= 2'b00;
  default: state_q <= 2'b00;
 endcase
end
endmodule