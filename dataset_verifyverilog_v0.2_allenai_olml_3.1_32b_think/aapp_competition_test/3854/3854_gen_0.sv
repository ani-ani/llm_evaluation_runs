module subset_coins_dp (input reg clk, input reg rst_n, input reg start, input reg [7:0] coin_in, input reg load_coin, output reg [7:0] result_index, output reg result_valid, output reg done);
parameter K = 128;
parameter MAX_COINS = 12;

// Declare registers
reg [1:0] state;
reg [7:0] buffer [0:11];
reg [3:0] coin_count;
reg [3:0] coin_index;
reg [K:0] dp;
reg [7:0] s_index;
reg [7:0] result_index;
reg result_valid;
reg done;

// State machine and control logic
always @(posedge clk or posedge rst_n) begin
   if (!rst_n) begin
      state <= 2'b00;
      coin_count <= 4'd0;
      coin_index <= 4'd0;
      s_index <= 8'd0;
      done <= 1'b0;
      dp <= {1'b1, K{1'b0}}; // Initialize dp[0] = 1
   end else begin
      case (state)
         2'b00: begin // IDLE
            if (start) begin
               if (load_coin && coin_count < MAX_COINS) begin
                  buffer[coin_count] <= coin_in;
                  coin_count <= coin_count + 1;
               end
               else if (!load_coin && coin_count > 0) begin
                  state <= 2'b01; // PROCESS_COINS
               end
            end
         end
         2'b01: begin // PROCESS_COINS
            if (coin_index < coin_count) begin
               reg [7:0] c = buffer[coin_index];
               for (int s = c; s <= K; s = s + 1) begin
                  dp[s] = dp[s] | dp[s - c];
               end
               coin_index <= coin_index + 1;
            end
            else begin
               state <= 2'b10; // OUTPUT_STATE
               coin_index <= 4'd0;
            end
         end
         2'b10: begin // OUTPUT_STATE
            if (s_index <= K) begin
               result_index <= s_index;
               result_valid <= dp[s_index] ? 1'b1 : 1'b0;
               s_index <= s_index + 1;
               if (s_index > K) begin
                  state <= 2'b11;
                  s_index <= 8'd0;
                  done <= 1'b1;
               end
            end
         end
         2'b11: begin // DONE
            // Remain in DONE state
         end
      endcase
   end
end
endmodule