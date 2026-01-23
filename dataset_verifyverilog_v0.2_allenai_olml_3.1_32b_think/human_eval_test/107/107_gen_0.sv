module even_odd_palindrome (
   input clk,
   input rst_n,
   input start,
   input [7:0] n,
   output reg [7:0] even_count,
   output reg [7:0] odd_count,
   output reg done
);

reg [7:0] current_num;
reg [2:0] state;
reg [7:0] even_count_reg, odd_count_reg;
reg done_reg;
reg is_pal;

parameter IDLE = 3'd0,
INIT = 3'd1,
CHECK_NEXT = 3'd2,
COUNT_UP = 3'd3,
DONE = 3'd4;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      current_num <= 0;
      even_count_reg <= 0;
      odd_count_reg <= 0;
      done_reg <= 1'b0;
      is_pal <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start) state <= INIT;
         end
         INIT: begin
            state <= CHECK_NEXT;
            current_num <= 1;
         end
         CHECK_NEXT: begin
            is_pal <= (current_num < 10) ? 1'b1 : (current_num < 100) ? ((current_num /10) == (current_num %10)) : ((current_num /100) == (current_num %10));
            state <= COUNT_UP;
         end
         COUNT_UP: begin
            if (is_pal) begin
               if (current_num % 2 == 0) even_count_reg <= even_count_reg + 1;
               else odd_count_reg <= odd_count_reg + 1;
            end
            current_num <= current_num + 1;
            if (current_num > n) begin
               done_reg <= 1'b1;
               state <= DONE;
            end else begin
               state <= CHECK_NEXT;
            end
         end
         DONE: begin
         end
      endcase
   end
end

assign even_count = even_count_reg;
assign odd_count = odd_count_reg;
assign done = done_reg;

endmodule