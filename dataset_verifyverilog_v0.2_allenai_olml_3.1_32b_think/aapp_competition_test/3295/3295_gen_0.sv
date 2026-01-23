module mirko_solver (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] K,
    input [7:0] L,
    input [7:0] M,
    output reg [15:0] result,
    output reg done
);
localparam IDLE = 3'd0, PROCESSING_X = 1, COUNTING = 2, DONE_STATE = 3;
reg [2:0] state;
reg [15:0] x;
reg [15:0] result;
reg done;
reg [7:0] n_counter;
reg [7:0] happy_count;
function automatic int is_prime(int n);
   if (n < 2) return 0;
   if (n == 2) return 1;
   if (n % 2 == 0) return 0;
   if (n == 3) return 1;
   if (n % 3 == 0) return 0;
   if (n == 5) return 1;
   if (n % 5 == 0) return 0;
   if (n == 7) return 1;
   if (n % 7 == 0) return 0;
   if (n == 11) return 1;
   if (n % 11 == 0) return 0;
   if (n == 13) return 1;
   if (n % 13 == 0) return 0;
   if (n == 17) return 1;
   if (n % 17 == 0) return 0;
   if (n == 19) return 1;
   if (n % 19 == 0) return 0;
   if (n == 23) return 1;
   if (n % 23 == 0) return 0;
   if (n == 29) return 1;
   if (n % 29 == 0) return 0;
   if (n == 31) return 1;
   if (n % 31 == 0) return 0;
   if (n == 37) return 1;
   if (n % 37 == 0) return 0;
   if (n == 41) return 1;
   if (n % 41 == 0) return 0;
   if (n == 43) return 1;
   if (n % 43 == 0) return 0;
   return 1;
endfunction
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      x <= 1;
      result <= -1;
      done <= 0;
      n_counter <= 0;
      happy_count <= 0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            state <= PROCESSING_X;
         end
      end else if (state == PROCESSING_X) begin
         if (x > 2000) begin
            result <= -1;
            done <= 1;
            state <= DONE_STATE;
         end else begin
            n_counter <= 0;
            happy_count <= 0;
            state <= COUNTING;
         end
      end else if (state == COUNTING) begin
         if (n_counter < K) begin
            int n = x + n_counter;
            int happy_bit;
            if (n <= M) begin
               happy_bit = 1;
            end else begin
               happy_bit = is_prime(n);
            end
            happy_count <= happy_count + happy_bit;
            n_counter <= n_counter + 1;
            state <= COUNTING;
         end else begin
            if (happy_count == L) begin
               result <= x;
               done <= 1;
               state <= DONE_STATE;
            end else begin
               x <= x + 1;
               if (x > 2000) begin
                  result <= -1;
                  done <= 1;
                  state <= DONE_STATE;
               end else begin
                  state <= PROCESSING_X;
               end
            end
         end
      end else if (state == DONE_STATE) begin
         state <= DONE_STATE;
      end
   end
endmodule