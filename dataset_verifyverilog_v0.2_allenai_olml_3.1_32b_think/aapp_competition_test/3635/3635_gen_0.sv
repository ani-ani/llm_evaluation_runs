module executive_reward (
   input clk,
   input rst_n,
   input start,
   input [2:0] num_briefcases,
   input [23:0] bananas [0:7],
   output reg [7:0] max_executives,
   output reg done
);
reg [2:0] local_num;
reg [23:0] bananas_reg [0:7];
reg [31:0] current_sum, prev_sum, new_current_sum, new_prev_sum;
reg [2:0] exec_count, new_exec_count, index, new_index;
localparam IDLE = 3'd0, COMPUTE = 3'd1, DONE = 3'd2;
always_ff @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      local_num <= 3'd0;
      bananas_reg <= {'d0, 'd0, 'd0, 'd0, 'd0, 'd0, 'd0, 'd0};
      current_sum <= 32'd0;
      prev_sum <= 32'd0;
      new_current_sum <= 32'd0;
      new_prev_sum <= 32'd0;
      exec_count <= 3'd0;
      new_exec_count <= 3'd0;
      index <= 3'd0;
      new_index <= 3'd0;
      done <= 1'b0;
      max_executives <= 8'd0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               local_num <= num_briefcases;
               bananas_reg[0] <= bananas[0];
               if (num_briefcases > 1) bananas_reg[1] <= bananas[1];
               if (num_briefcases > 2) bananas_reg[2] <= bananas[2];
               if (num_briefcases > 3) bananas_reg[3] <= bananas[3];
               if (num_briefcases > 4) bananas_reg[4] <= bananas[4];
               if (num_briefcases > 5) bananas_reg[5] <= bananas[5];
               if (num_briefcases > 6) bananas_reg[6] <= bananas[6];
               if (num_briefcases > 7) bananas_reg[7] <= bananas[7];
               state <= COMPUTE;
               index <= 3'd0;
               current_sum <= 32'd0;
               prev_sum <= 32'd0;
               new_current_sum <= 32'd0;
               new_prev_sum <= 32'd0;
               exec_count <= 3'd0;
               new_exec_count <= 3'd0;
            end
         end
         COMPUTE: begin
            if (index < local_num) begin
               current_sum <= new_current_sum;
               exec_count <= new_exec_count;
               prev_sum <= new_prev_sum;
               index <= new_index;
            end else begin
               state <= DONE;
               done <= 1'b1;
            end
         end
         DONE: begin
            // stay in DONE
         end
      endcase
   end
end
always_comb begin
   new_current_sum = current_sum;
   new_exec_count = exec_count;
   new_prev_sum = prev_sum;
   new_index = index;
   if (state == COMPUTE && index < local_num) begin
      new_current_sum = current_sum + bananas_reg[index];
      if (new_current_sum >= prev_sum) begin
          new_exec_count = exec_count + 1;
          new_prev_sum = new_current_sum;
          new_current_sum = 0;
      end
      new_index = index + 1;
   end
end
assign done = (state == DONE);
assign max_executives = (state == DONE) ? exec_count : 8'd0;
endmodule