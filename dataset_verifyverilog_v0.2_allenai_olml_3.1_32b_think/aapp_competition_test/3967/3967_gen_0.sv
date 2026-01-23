module bamboo_solver (
   input clk,
   input rst_n, // active low reset
   input start,
   input stop,
   input [7:0] a_0, a_1, a_2, a_3,
   input [11:0] k,
   output reg [11:0] best_d,
   output reg [11:0] current_waste,
   output reg searching,
   output reg done
);
parameter IDLE = 2'b00;
parameter SEARCHING = 2'b01;
parameter DONE = 2'b10;
reg [1:0] state, next_state;
reg [11:0] d;
reg [11:0] best_d;
reg [11:0] current_waste;
// searching and done are assigned from state.
assign searching = (state == SEARCHING);
assign done = (state == DONE);
// Default assignments for synthesis
always @(*) begin
   best_d = 12'd0;
   current_waste = 12'd0;
end
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      best_d <= 12'd0;
      current_waste <= 12'd0;
      d <= 12'd0;
      next_state <= IDLE;
   end else begin
      next_state = state;
      if (start) begin
         if (state != SEARCHING) begin
            next_state = SEARCHING;
            d <= 12'd1;
         end
      end
      if (state == SEARCHING) begin
         // Calculate waste for each bamboo
         integer waste0 = (d * ((a_0 + d - 1) / d)) - a_0;
         integer waste1 = (d * ((a_1 + d - 1) / d)) - a_1;
         integer waste2 = (d * ((a_2 + d - 1) / d)) - a_2;
         integer waste3 = (d * ((a_3 + d - 1) / d)) - a_3;
         integer total_waste = waste0 + waste1 + waste2 + waste3;
         current_waste <= total_waste;
         if (total_waste <= k) begin
            best_d <= d;
         end
         if (stop || (d == 4095)) begin
            next_state = DONE;
         end else begin
            if (d < 4095) begin
               d <= d + 1;
            end
         end
      end
      state <= next_state;
   end
endmodule