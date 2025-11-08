module TopModule(input clk, input reset, input w, output z);
reg [2:0] state, next_state;
assign z = (state == 3'd4) || (state == 3'd5);
always @(posedge clk or posedge reset) begin
  if (reset)
    state <= 3'd0;
  else
    state <= next_state;
end
always_comb begin
  case (state)
    3'd0: next_state = w ? 3'd0 : 3'd1;
    3'd1: next_state = w ? 3'd3 : 3'd2;
    3'd2: next_state = w ? 3'd3 : 3'd4;
    3'd3: next_state = w ? 3'd0 : 3'd5;
    3'd4: next_state = w ? 3'd3 : 3'd4;
    3'd5: next_state = w ? 3'd3 : 3'd2;
    default: next_state = 3'd0;
  endcase
end
endmodule