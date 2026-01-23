module memory_game_expected_turns (input clk, input rst_n, input start, input [4:0] N, output reg [31:0] result, output reg done);
reg [2:0] state;
reg [4:0] captured_N;
reg [15:0] delay_counter;
reg done_reg;
always_ff @(posedge clk)
if (!rst_n) begin
    state <= 0;
captured_N <=0;
delay_counter <=0;
done_reg <=0;
end
else case (state)
0: if (start) state <=1;
   done_reg <=0;
1: captured_N <= N;
   if (captured_N !=0) state <=2;
   else state <=3;
   done_reg <=0;
2: if (delay_counter ==0) begin
      state <=3;
      result <= captured_N * 32;
   end else delay_counter <= delay_counter -1;
   done_reg <= (delay_counter ==0);
3: state <=3;
   done_reg <=1;
default: state <=0;
end
assign done = done_reg;
endmodule