module last_digit (input clk, input rst_n, input start, input [31:0] number, output reg [3:0] last_digit, output reg done);
localparam IDLE = 2'd0, PROCESSING = 2'd1, DONE = 2'd2;
reg [31:0] stored_num;
reg [5:0] counter;
reg [2:0] state;
reg started;
always @(posedge clk) begin
   if (!rst_n) begin
      stored_num <= 32'd0;
      counter <= 6'd0;
      state <= IDLE;
      started <= 0;
      last_digit <= 4'd0;
   end else begin
      if (state == IDLE) begin
          if (!started && start) begin
              stored_num <= number;
              counter <= 6'd33;
              state <= PROCESSING;
              started <= 1;
              last_digit <= 4'd0;
          end
      end else if (state == PROCESSING) begin
          if (counter > 0) begin
              counter <= counter - 1;
          end else begin
              last_digit <= stored_num % 10;
              state <= DONE;
          end
      end else if (state == DONE) begin
          state <= IDLE;
          started <= 0;
      end
   end
   done <= (state == DONE);
end
endmodule