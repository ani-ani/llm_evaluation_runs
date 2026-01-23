module pythagorean_triple_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] count,
    output reg done
);

localparam IDLE = 3'b000;
localparam COMPUTE = 3'b001;
localparam DONE = 3'b010;

reg [2:0] state;
reg [15:0] a, b, c;
reg [15:0] count_reg;
reg done_reg;

reg [15:0] next_a, next_b, next_c, next_count;
reg [2:0] next_state;
reg next_done;

function [15:0] mod;
input [15:0] x, input [4:0] n;
begin
   mod = x;
   for (int i=0; i <16; i++) begin
      if (mod < n) break;
      mod = mod - n;
   end
endfunction

always_comb begin
   next_a = a;
   next_b = b;
   next_c = c;
   next_count = count_reg;
   next_state = state;
   next_done = done_reg;

   if (state == COMPUTE) begin
      integer a_sq, b_sq, c_sq;
      a_sq = mod(a*a, n);
      b_sq = mod(b*b, n);
      c_sq = mod(c*c, n);
      if ((a_sq + b_sq) % n == c_sq) begin
         next_count = count_reg + 1;
      end

      if (c < n-1) begin
         next_c = c + 1;
      end else begin
         next_c = 1;
         if (b < n-1) begin
            next_b = b + 1;
         end else begin
            next_b = 1;
            next_a = a + 1;
            if (next_a > n-1) begin
               next_state = DONE;
               next_done = 1;
            end else begin
               next_b = next_a;
               next_state = COMPUTE;
               next_done = 0;
            end
         end
      end

      if (next_state != DONE) begin
         next_state = COMPUTE;
         next_done = 0;
      end
   end

   if (state == IDLE && start) begin
      next_state = COMPUTE;
      next_a = 1;
      next_b = 1;
      next_c = 1;
      next_count = 0;
      next_done = 0;
   end
end

always_ff @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      count_reg <= 0;
      a <= 0;
      b <= 0;
      c <= 0;
      done_reg <= 0;
   end else begin
      state <= next_state;
      count_reg <= next_count;
      a <= next_a;
      b <= next_b;
      c <= next_c;
      done_reg <= next_done;
   end
end

assign count = count_reg;
assign done = done_reg;

endmodule