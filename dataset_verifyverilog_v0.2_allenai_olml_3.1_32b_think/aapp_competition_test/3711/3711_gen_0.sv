module chocolate_cutter (
input clk,
input rst_n, // Active-low reset
input start,
input [9:0] n,
input [9:0] m,
input [9:0] k,
output reg [39:0] result,
output reg done
);
assign done = (state == DONE_STATE);
localparam IDLE = 3'd0,
CHECK_VALIDITY = 1,
ITERATE = 2,
DONE_STATE =3;
reg [2:0] state;
reg [31:0] current_max;
reg [15:0] x_max, current_x;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
current_max <= 32'd0;
x_max <= 16'd0;
current_x <= 16'd0;
end else begin
case (state)
IDLE: begin
if (start) state <= CHECK_VALIDITY;
// else remain in IDLE, no changes
end
CHECK_VALIDITY: begin
// Calculate total_max_cuts = (n-1)+(m-1)
integer total_max = (n-1) + (m-1);
if (k > total_max) begin
result <= 40'hFFFFFFFFFFFF;
state <= DONE_STATE;
end else begin
// Compute x_max = min(k, n-1)
x_max <= ( ({32'd0, k} < {32'd0, n}) ) ? k : ( ({32'd0, n} - 1) );
state <= ITERATE;
current_x <= 16'd0;
current_max <= 32'd0;
end
end
ITERATE: begin
if (current_x <= x_max) begin
// Calculate y = k - current_x (unsigned)
integer y_val = ({32'd0, k}) - ({32'd0, current_x});
// Check y is <= m-1
if (y_val <= ( ({32'd0, m} - 1) )) begin
// Calculate width and height
integer width = ({32'd0, n}) / (current_x + 1);
integer height = ({32'd0, m}) / (y_val + 1);
integer area = width * height;
if (area > current_max) current_max <= area;
end
// Increment current_x
current_x <= current_x + 1;
end else begin
// All x processed, move to done
state <= DONE_STATE;
result <= {8'd0, current_max};
end
end
endcase
end
end
endmodule