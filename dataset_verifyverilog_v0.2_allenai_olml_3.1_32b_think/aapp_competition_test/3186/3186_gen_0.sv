module ways_calculator (
input clk,
input rst_n,
input start,
input [6:0] N_in,
input [6:0] M_in,
input [6:0] K_in,
output reg [19:0] result,
output reg done
);

`timescale 1ns/1ps
localparam MOD = 1000007;
localparam IDLE = 3'd0, INIT = 3'd1, ITERATE_N = 3'd2, ITERATE_K = 3'd3, UPDATE_RESULT = 3'd4, DONE = 3'd5;

// Registers
reg [19:0] prev_dp [127:0];
reg [19:0] curr_dp [127:0];
reg [6:0] n_counter;
reg [6:0] k_counter;
reg [2:0] state;
reg [19:0] result;
reg done;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      prev_dp <= 0;
      prev_dp[0] <= 1;
      curr_dp <= 0;
      n_counter <= 0;
      k_counter <= 0;
      state <= IDLE;
      result <= 0;
      done <=0;
   end else begin
      case (state)
         IDLE: begin
             if (start)
                 state <= INIT;
             else
                 state <= IDLE;
         end
         INIT: begin
             if (N_in == 0) begin
                 result <= (K_in == 0) ? 1 : 0;
                 done <= 1;
                 state <= DONE;
             end else begin
                 n_counter <= 1;
                 state <= ITERATE_N;
             end
         end
         ITERATE_N: begin
             curr_dp[0] <= 1;
             k_counter <= 1;
             state <= ITERATE_K;
         end
         ITERATE_K: begin
             if (k_counter <= K_in) begin
                 reg [19:0] temp;
                 temp = curr_dp[k_counter - 1] + prev_dp[k_counter];
                 if (k_counter >= (M_in + 1)) begin
                     temp = temp - prev_dp[k_counter - (M_in + 1)];
                 end
                 temp = (temp + MOD) % MOD;
                 curr_dp[k_counter] <= temp;
                 k_counter <= k_counter + 1;
                 state <= ITERATE_K;
             end else begin
                 prev_dp <= curr_dp;
                 n_counter <= n_counter + 1;
                 if (n_counter <= N_in) begin
                     state <= ITERATE_N;
                 end else begin
                     result <= prev_dp[K_in];
                     done <= 1;
                     state <= UPDATE_RESULT;
                 end
             end
         end
         UPDATE_RESULT: begin
             state <= DONE;
         end
         DONE: begin
             state <= DONE;
         end
      endcase
   end
endmodule