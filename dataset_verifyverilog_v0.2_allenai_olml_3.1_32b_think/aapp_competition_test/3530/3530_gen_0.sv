module roller_coaster_fun (
input clk,
input rst_n,
input start,
input [7:0] coaster_a [0:7],
input [7:0] coaster_b [0:7],
input [7:0] coaster_t [0:7],
input [7:0] time_budget,
output reg [15:0] max_fun,
output reg done);

parameter IDLE = 2'd0;
parameter PREPARE_ITEMS = 2'd1;
parameter DP_COMPUTE = 2'd2;
parameter DONE = 2'd3;

reg [1:0] state;
reg [6:0] item_idx;
reg [15:0] dp [0:255];
reg [7:0] reg_coaster_a [0:7];
reg [7:0] reg_coaster_b [0:7];
reg [7:0] reg_coaster_t [0:7];
reg [7:0] reg_time_budget;

always @(negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      item_idx <= 8'd0;
      genvar i;
      generate
         for (i=0; i<256; i++) begin: init_dp
            dp[i] <= 16'd0;
         end
      endgenerate
      reg_coaster_a <= 8'd0;
      reg_coaster_b <= 8'd0;
      reg_coaster_t <= 8'd0;
      reg_time_budget <= 8'd0;
      done <= 1'b0;
      item_idx <= 8'd0;
   end
end

always @(posedge clk) begin
   if (!rst_n) state <= IDLE;
   else case (state)
      IDLE: begin
         if (start) begin
            reg_coaster_a <= coaster_a;
            reg_coaster_b <= coaster_b;
            reg_coaster_t <= coaster_t;
            reg_time_budget <= time_budget;
            state <= PREPARE_ITEMS;
            item_idx <= 8'd0;
            genvar i;
            generate
               for (i=0; i<256; i++) begin: reset_dp
                  dp[i] <= 16'd0;
               end
            endgenerate
         end
         else state <= IDLE;
      end
      PREPARE_ITEMS: state <= DP_COMPUTE;
      DP_COMPUTE: begin
         if (item_idx < 64) begin
            state <= DP_COMPUTE;
            item_idx <= item_idx + 1;
            integer i = item_idx / 8;
            integer k = item_idx % 8 + 1;
            integer temp = (k-1) * (k-1);
            integer current_fun = reg_coaster_a[i] - temp * reg_coaster_b[i];
            integer item_time_val = reg_coaster_t[i];
            reg [15:0] next_dp [0:255];
            genvar time;
            generate
               for (time=0; time<256; time++) begin: assign
                  next_dp[time] = dp[time];
                  if (current_fun > 0 && time >= item_time_val) begin
                     integer candidate = dp[time - item_time_val] + current_fun;
                     if (candidate > next_dp[time]) next_dp[time] = candidate;
                  end
               end
            endgenerate
            dp <= next_dp;
         end
         else begin
            state <= DONE;
            max_fun <= dp[reg_time_budget];
            done <= 1'b1;
         end
      end
      DONE: state <= DONE;
   endcase
end

endmodule