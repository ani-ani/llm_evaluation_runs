module swap_digits_max (
input clk,
input rst_n,
input start,
input [15:0] number_in,
input [3:0] k,
output reg [15:0] result,
output reg done);

reg [15:0] original_num;
reg [3:0] k_reg;
reg [15:0] current_max;
reg [15:0] count;
reg [2:0] state;
reg done_out;

parameter IDLE = 3'd0,
INIT = 3'd1,
PROCESSING = 3'd2,
DONE = 3'd3;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      original_num <= 16'd0;
      k_reg <= 4'd0;
      current_max <= 16'd0;
      count <= 16'd0;
      state <= IDLE;
      done_out <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start == 1'b1) state <= INIT;
         end
         INIT: begin
            original_num <= number_in;
            k_reg <= k;
            count <= 16'd0;
            state <= PROCESSING;
         end
         PROCESSING: begin
            count <= count + 1;
            if (count > 1) state <= DONE;
         end
         DONE: begin
            done_out <= 1'b1;
         end
      endcase
   end
end

// Assign outputs
assign result = current_max;
assign done = done_out;

endmodule