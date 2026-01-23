module move_one_ball (
input clk,
input rst_n,
input start,
input [7:0][7:0] arr,
output reg result,
output reg done);

parameter IDLE = 2'b00,
CHECK_SORTED = 2'b01,
VALIDATE = 2'b10;

reg [1:0] state;
reg [3:0] counter, drop_count;

always @(posedge clk) begin
if (!rst_n) begin
   state <= IDLE;
   counter <= 4'd0;
   drop_count <= 4'd0;
   result <= 1'b0;
   done <= 1'b0;
end else begin
   case (state)
   IDLE: begin
      if (start) begin
         state <= CHECK_SORTED;
         counter <= 4'd0;
         drop_count <= 4'd0;
      end else begin
         state <= IDLE;
      end
   end
   CHECK_SORTED: begin
      if (counter < 8) begin
         if (arr[counter][7:0] > arr[(counter +1) %8][7:0]) begin
            drop_count <= drop_count +1;
         end
         counter <= counter +1;
         state <= CHECK_SORTED;
      end else begin
         state <= VALIDATE;
      end
   end
   VALIDATE: begin
      result <= (drop_count == 0) || (drop_count ==1);
      done <= 1'b1;
      state <= VALIDATE;
   end
   default: state <= IDLE;
   endcase
end

endmodule
