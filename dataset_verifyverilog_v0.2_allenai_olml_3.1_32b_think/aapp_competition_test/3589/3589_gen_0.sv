module digit_product_distribution (
   input clk,
   input rst_n,
   input start,
   input [15:0] L,
   input [15:0] R,
   output reg [15:0] result,
   output reg done
);

reg [15:0] current_x;
reg [15:0] temp_val;
reg [3:0] cnt [1:9];
reg [15:0] reg_L, reg_R;
reg [2:0] state;
reg [3:0] final_digit_reg;
reg done_reg;

localparam IDLE = 3'd0,
ITERATE = 1,
PROCESS_NUMBER = 2,
UPDATE_COUNT =3,
CHECK_DONE=4,
DONE_STATE=5;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      reg_L <= 16'b0;
      reg_R <= 16'b0;
      current_x <= 16'b0;
      temp_val <= 16'b0;
      cnt[1:9] <= 16'b0;
      final_digit_reg <= 4'b0;
      done_reg <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               reg_L <= L;
               reg_R <= R;
               state <= ITERATE;
            end else begin
               state <= IDLE;
            end
         end
         ITERATE: begin
            current_x <= reg_L;
            state <= PROCESS_NUMBER;
         end
         PROCESS_NUMBER: begin
            final_digit_reg <= current_x[3:0];
            state <= UPDATE_COUNT;
         end
         UPDATE_COUNT: begin
            if (final_digit_reg > 0 && final_digit_reg < 10) begin
               cnt[final_digit_reg] <= cnt[final_digit_reg] + 1;
            end
            state <= CHECK_DONE;
         end
         CHECK_DONE: begin
            if (current_x < reg_R) begin
               current_x <= current_x + 1;
               state <= PROCESS_NUMBER;
            end else begin
               done_reg <= 1'b1;
               state <= DONE_STATE;
            end
         end
         DONE_STATE: begin
            if (done_reg) begin
               state <= DONE_STATE;
            end else begin
               state <= CHECK_DONE;
            end
         end
      endcase
   end
end

assign result = {cnt[1], cnt[2], cnt[3], cnt[4]};
assign done = done_reg;
endmodule