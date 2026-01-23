module match_parens(input clk, input rst_n, input start, input [7:0] str1 [0:7], input [7:0] str2 [0:7], output reg result, output reg done);
parameter IDLE = 3'd0, CHECK_S1_S2=1, CHECK_S2_S1=2, COMPUTE_RESULT=3, DONE=4;
reg [2:0] state, next_state;
reg [15:0] reg_order1, reg_order2;

always @(posedge clk) begin
 if (!rst_n) begin
   state <= IDLE;
   next_state <= IDLE;
   reg_order1 <= 16'd0;
   reg_order2 <= 16'd0;
   result <= 1'b0;
   done <=1'b0;
 end else begin
   case (state)
   IDLE: begin
     if (start) next_state <= CHECK_S1_S2; else next_state <= IDLE;
   end
   CHECK_S1_S2: begin
     reg_order1 <= 1'b0; next_state <= CHECK_S2_S1;
   end
   CHECK_S2_S1: begin
     reg_order2 <= 1'b0; next_state <= COMPUTE_RESULT;
   end
   COMPUTE_RESULT: begin
     result <= reg_order1 | reg_order2; next_state <= DONE; done <=1'b0;
   end
   DONE: begin
     done <=1'b1; next_state <= DONE;
   end
   endcase
   state <= next_state;
 end
endmodule