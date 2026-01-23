module powers_game(input clk, input rst_n, input [7:0] n, input start, output reg winner, output reg done);
   reg [7:0] reg_n;
   reg [1:0] state;
   reg [2:0] current_i;
   reg [3:0] xor_result;
   reg [15:0] total_chain;
   reg [3:0] chain_len_reg;
   reg winner_reg;

   localparam IDLE = 2'd0, CHECK_BASE = 2'd1, COMPUTE_CHAIN = 2'd2, UPDATE_XOR = 2'd3, COUNT_REMAINING = 2'd4, DONE = 2'd5;

   parameter [3:0] Grundy_LUT [1:8] = {1,2,1,4,3,2,1,5};

   function int is_perfect_power;
      input int i;
      if (i ==4 || i ==8 || i ==9) return 1;
      else return 0;
   endfunction

   function int compute_chain;
      input int b, n;
      int count, current;
      count = 0;
      current = 1;
      while (current <= n) begin
         current = current * b;
         if (current > n) break;
         count = count + 1;
      end
      return count;
   endfunction

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         reg_n <= 8'd0;
         state <= IDLE;
         current_i <= 3'd2;
         xor_result <= 4'd0;
         total_chain <= 16'd0;
         chain_len_reg <= 4'd0;
         winner_reg <= 1'd0;
         done <= 1'b0;
      end else begin
         case (state)
            IDLE: begin
               if (start) begin
                  reg_n <= n;
                  state <= CHECK_BASE;
                  done <= 1'b0;
               end else begin
                  state <= IDLE;
               end
            end
            CHECK_BASE: begin
               if (current_i > 15) begin
                  state <= COUNT_REMAINING;
               end else if (is_perfect_power(current_i)) begin
                  current_i <= current_i + 1;
                  state <= CHECK_BASE;
               end else begin
                  state <= COMPUTE_CHAIN;
               end
            end
            COMPUTE_CHAIN: begin
               chain_len_reg <= compute_chain(current_i, reg_n);
               state <= UPDATE_XOR;
            end
            UPDATE_XOR: begin
               if (chain_len_reg > 0) begin
                  xor_result <= xor_result ^ Grundy_LUT[chain_len_reg];
                  total_chain <= total_chain + chain_len_reg;
               end
               current_i <= current_i + 1;
               state <= CHECK_BASE;
            end
            COUNT_REMAINING: begin
               int remaining = reg_n - total_chain;
               int parity = remaining % 2;
               int total_xor = xor_result ^ parity;
               winner_reg <= total_xor != 0 ? 1 : 0;
               done <= 1'b1;
               state <= DONE;
            end
            DONE: begin
               if (start) begin
                  reg_n <= n;
                  current_i <= 3'd2;
                  xor_result <= 4'd0;
                  total_chain <= 16'd0;
                  chain_len_reg <= 4'd0;
                  winner_reg <= 1'd0;
                  state <= CHECK_BASE;
                  done <= 1'b0;
               end else begin
                  state <= DONE;
               end
            end
         endcase
      end
   end

   assign winner = winner_reg;

endmodule