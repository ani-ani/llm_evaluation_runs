module TopModule (
 input clk,
 input a,
 input b,
 output state,
 output q
);
 reg state_reg;
 assign state = state_reg;
 assign q = state_reg ^ (a ^ b);
 always @(posedge clk) begin
 if ( a && b ) state_reg <= ~state_reg;
 else if ( !a && !b && !state_reg ) state_reg <= ~state_reg ;
 else state_reg <= state_reg ;
 end
endmodule