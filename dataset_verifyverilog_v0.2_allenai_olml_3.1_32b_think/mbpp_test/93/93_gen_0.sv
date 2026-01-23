module power_calculator (input clk, input rst_n, input start, input [31:0] a, input [15:0] b, output reg [31:0] result, output reg done);
localparam IDLE = 3'd0, CHECK_ZERO =1, CHECK_ONE=2, COMPUTE=3, DONE=4;
reg [2:0] state;
reg [31:0] result_reg;
reg [15:0] counter_reg;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
result_reg <= 32'd0;
counter_reg <= 16'd0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= CHECK_ZERO;
end else begin
state <= IDLE;
end
end
CHECK_ZERO: begin
if (b == 0) begin
result_reg <= 32'd1;
state <= DONE;
end else begin
state <= CHECK_ONE;
end
end
CHECK_ONE: begin
if (b == 1) begin
result_reg <= a;
state <= DONE;
end else if (a == 0) begin
result_reg <= 32'd0;
state <= DONE;
end else begin
result_reg <= a;
counter_reg <= b - 1;
state <= COMPUTE;
end
end
COMPUTE: begin
result_reg <= result_reg * a;
counter_reg <= counter_reg - 1;
if (counter_reg == 0) begin
state <= DONE;
end else begin
state <= COMPUTE;
end
end
DONE: begin
state <= DONE;
end
default: state <= IDLE;
endcase
end
end
assign result = result_reg;
assign done = (state == DONE);
endmodule