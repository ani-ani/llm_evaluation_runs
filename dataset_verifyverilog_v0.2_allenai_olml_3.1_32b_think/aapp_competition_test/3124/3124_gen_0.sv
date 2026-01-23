module ivana_game_solver (
 input clk,
 input rst_n,
 input start,
 input [7:0] num_bits,
 input [2:0] N,
 output reg [3:0] result,
 output reg done
);
reg [2:0] state;
reg [7:0] reg_num_bits;
reg [2:0] reg_N;
reg [7:0] memo [0:255];
reg [7:0] current_mask;
reg [15:0] counter;
always @(posedge clk) begin
 if (!rst_n) begin
 state <= 3'b000;
 reg_num_bits <= 8'b0;
 reg_N <= 3'b0;
 result <= 4'b0;
 done <= 1'b0;
 counter <= 16'b0;
 end else begin
 case (state)
 3'b000: begin
 if (start) state <= 3'b001;
 end
 3'b001: begin
 reg_num_bits <= num_bits;
 reg_N <= N;
 if (counter == 0) state <= 3'b010;
 end
 3'b010: begin
 if (counter < 2048) counter <= counter + 1;
 if (counter == 2048) begin
 state <= 3'b100;
 result <= 4'b0;
 done <= 1'b1;
 end
 end
 3'b100: begin
 end
 endcase
 end
endmodule