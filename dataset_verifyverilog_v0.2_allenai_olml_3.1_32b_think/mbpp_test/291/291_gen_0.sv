module fence_painter (
input clk,
input rst_n, // active low
input start,
input [3:0] n,
input [3:0] k,
output reg [29:0] result,
output reg done
);

localparam IDLE = 2'b00;
localparam CALC_INIT = 2'b01;
localparam CALC_LOOP = 2'b10;
localparam DONE = 2'b11;
localparam MOD = 1000000007;

// Registers
reg [1:0] state;
reg [3:0] n_val;
reg [3:0] k_val;
reg [31:0] dp_prev1, dp_prev2;
reg [2:0] counter;
reg [29:0] result_reg;
reg done_reg;

// Assign outputs
assign result = result_reg;
assign done = done_reg;

// Reset and clock
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      n_val <= 0;
      k_val <= 0;
      dp_prev1 <= 0;
      dp_prev2 <= 0;
      counter <= 0;
      result_reg <= 0;
      done_reg <= 0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               n_val <= n;
               k_val <= k;
               if (n == 0) begin
                  result_reg <= 0;
                  done_reg <= 1;
                  state <= DONE;
               end else if (n == 1) begin
                  result_reg <= k_val;
                  done_reg <= 1;
                  state <= DONE;
               end else if (n == 2) begin
                  result_reg <= (k_val * k_val) % MOD;
                  done_reg <= 1;
                  state <= DONE;
               end else begin // n >=3
                  state <= CALC_INIT;
               end
            end else begin
               state <= IDLE;
            end
         end
         CALC_INIT: begin
            dp_prev2 <= k_val;
            dp_prev1 <= (k_val * k_val) % MOD;
            counter <= n_val - 2;
            state <= CALC_LOOP;
         end
         CALC_LOOP: begin
            if (counter > 0) begin
               // Compute new value
               reg [63:0] product;
               product = (k_val - 1) * (dp_prev1 + dp_prev2);
               reg [31:0] new_dp;
               new_dp = product % MOD;
               // Update the dp registers
               dp_prev2 <= dp_prev1;
               dp_prev1 <= new_dp;
               counter <= counter - 1;
               // Check if we're done
               if (counter == 0) begin
                  result_reg <= dp_prev1;
                  done_reg <= 1;
                  state <= DONE;
               end else begin
                  state <= CALC_LOOP;
               end
            end else begin
               // This should not happen, but to be safe
               state <= DONE;
            end
         end
         DONE: begin
            state <= DONE;
         end
      endcase
   end
endmodule