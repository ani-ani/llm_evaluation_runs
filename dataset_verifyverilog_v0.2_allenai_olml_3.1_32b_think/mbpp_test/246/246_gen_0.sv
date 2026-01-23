module babylonian_sqrt (
input clk,
input rst_n,
input start,
input [31:0] number,
output reg [31:0] sqrt_result,
output reg done
);

reg [2:0] state;
reg [31:0] g;
reg [4:0] counter;
reg start_pending;
reg [31:0] sqrt_result_reg;
reg done_reg;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam ITERATE = 3'd2;
localparam DONE = 3'd3;

initial begin
state <= IDLE;
g <= 32'd0;
counter <= 16'd16;
start_pending <= 1'b0;
sqrt_result_reg <= 32'd0;
done_reg <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
g <= 32'd0;
counter <= 16'd16;
start_pending <= 1'b0;
sqrt_result_reg <= 32'd0;
done_reg <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start_pending) begin
if (number == 0) begin
sqrt_result_reg <= 32'd0;
done_reg <= 1'b1;
state <= DONE;
end else begin
g <= number >> 1;
if (g == 0) g <= 1;
state <= INIT;
end
end else begin
if (start) begin
start_pending <= 1'b1;
end else begin
start_pending <= 1'b0;
end
state <= IDLE;
end
end
INIT: state <= ITERATE;
ITERATE: begin
if (counter > 0) begin
reg [31:0] n;
n = number / g;
reg [31:0] sum;
sum = g + n;
g <= sum >> 1;
counter <= counter - 1;
state <= ITERATE;
end else begin
sqrt_result_reg <= g;
done_reg <= 1'b1;
state <= DONE;
end
end
DONE: state <= DONE;
endcase
end
end

assign sqrt_result = sqrt_result_reg;
assign done = done_reg;

endmodule