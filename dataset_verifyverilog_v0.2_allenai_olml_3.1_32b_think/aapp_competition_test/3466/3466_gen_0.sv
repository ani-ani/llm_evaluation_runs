module sweet_diet (input clk, input rst_n, input start, input [2:0] m, input [15:0] a [0:7], input [15:0] s [0:7], input [15:0] n, output reg [15:0] additional_count, output reg forever_flag, output reg done);
reg [2:0] state, next_state;
reg [15:0] additional_count_reg;
reg forever_flag_reg, done_reg;
localparam IDLE = 3'd0, CHECK_BALANCE = 3'd1, UPDATE_COUNT = 3'd2, DONE = 3'd3;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
additional_count_reg <= 16'd0;
forever_flag_reg <= 1'b0;
done_reg <= 1'b0;
end else begin
state <= next_state;
additional_count <= additional_count_reg;
forever_flag <= forever_flag_reg;
done <= done_reg;
end
end
always @(*) begin
next_state = state;
forever_flag_reg = 1'b0;
done_reg = 1'b0;
case (state)
IDLE: begin
if (start) begin
next_state = CHECK_BALANCE;
end
end
CHECK_BALANCE: begin
next_state = UPDATE_COUNT;
end
UPDATE_COUNT: begin
additional_count_reg <= additional_count_reg + 1;
if (additional_count_reg == 256) begin
forever_flag_reg <= 1'b1;
next_state = DONE;
end else begin
next_state = CHECK_BALANCE;
end
end
DONE: begin
end
endcase
end
endmodule