module boomerang_solver (input clk, input rst_n, input start, input [1:0] a_in, output reg [4:0] target_r, output reg [2:0] target_c, output reg valid, output reg done, output reg error);

reg [1:0] state;
reg [2:0] column_count;
reg [2:0] current_row;
reg [2:0] current_col;
reg [2:0] pending_top;
reg [2:0] two_top;
reg [2:0] pending_data [3:0];
reg [2:0] two_data [3:0];
reg [4:0] target_buf_r [1:0];
reg [2:0] target_buf_c [1:0];
reg [1:0] target_buf_count;
reg [4:0] dummy;

parameter IDLE = 2'b00;
parameter PROCESS = 2'b01;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      column_count <= 0;
      pending_top <=0;
      two_top <=0;
      target_buf_count <=0;
      error <=0;
      done <=0;
      current_row <=0;
      current_col <=0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            state <= PROCESS;
            column_count <=0;
         end
      end else if (state == PROCESS) begin
         current_col <= 4 - column_count;
         current_row <= column_count +1;
         if (column_count == 3) begin
            done <=1;
            state <= IDLE;
         end else if (column_count <3) begin
            column_count <= column_count +1;
         end
         case (a_in)
            2'b01: begin
               if (pending_top <4) begin
                  pending_data[pending_top] <= current_row;
                  pending_top <= pending_top +1;
                  target_buf_r[target_buf_count] <= current_row;
                  target_buf_c[target_buf_count] <= current_col;
                  target_buf_count <= target_buf_count +1;
               end else begin
                  error <=1;
               end
            end
         endcase
      end
   end
end

always @(*) begin
   if (target_buf_count >0) begin
      target_r <= target_buf_r[0];
      target_c <= target_buf_c[0];
      valid = 1'b1;
   end else begin
      target_r <=4'd0;
      target_c <=2'd0;
      valid =1'b0;
   end
end

endmodule