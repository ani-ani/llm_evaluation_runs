module lucky_permutation (
   input clk,
   input rst_n, 
   input start,
   input [7:0] n_in,
   output reg [3:0] a_out, b_out, c_out, index_out,
   output reg valid,
   output reg done
);

parameter MAX_N = 16;

parameter IDLE = 2'b00,
   PROCESSING = 2'b01,
   DONE = 2'b10;

reg [1:0] state;
reg [7:0] n_val;
reg [3:0] current_index;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      n_val <= 8'h00;
      current_index <= 4'd0;
      valid <= 1'b0;
      done <= 1'b0;
   end else begin
      if (state == IDLE) begin
          if (start) begin
             state <= PROCESSING;
             n_val <= n_in;
             current_index <= 4'd0;
             valid <= 1'b0;
             done <= 1'b0;
          end
      end else if (state == PROCESSING) begin
          if (current_index < n_val) begin
             a_out <= current_index;
             b_out <= current_index;
             if (2*current_index < n_val) begin
                 c_out <= 2*current_index;
             end else begin
                 c_out <= 2*current_index - n_val;
             end
             index_out <= current_index;
             valid <= 1'b1;
             done <= 1'b0;
             if (current_index == n_val - 1) begin
                 state <= DONE;
             end else begin
                 state <= PROCESSING;
             end
             current_index <= current_index + 1;
          end else begin
             state <= DONE;
             valid <= 1'b0;
             done <= 1'b1;
          end
      end else if (state == DONE) begin
          state <= DONE;
          valid <= 1'b0;
          done <= 1'b1;
      end
   end
endmodule