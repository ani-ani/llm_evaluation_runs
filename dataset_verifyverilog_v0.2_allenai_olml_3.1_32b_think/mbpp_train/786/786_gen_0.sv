module right_insertion(input clk, input rst_n, input start, input [3:0] value, input [7:0] sorted_data [7:0], output reg [3:0] position, output reg done);
logic [3:0] next_left, next_right;
logic [2:0] mid;
reg [3:0] left, right, position_reg;
reg [1:0] state;
reg [9:0] count_down;
localparam [1:0] IDLE = 2'b00, SEARCHING = 2'b01, DONE = 2'b10;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
left <= 4'd0;
right <= 4'd8;
position_reg <= 4'd0;
state <= IDLE;
count_down <= 10'd0;
end else begin
case (state)
IDLE: begin
if (start) begin
left <= 4'd0;
right <= 4'd8;
count_down <= 9'd9;
state <= SEARCHING;
end
end
SEARCHING: begin
next_left = left;
next_right = right;
mid = (left + right) >> 1;
if (sorted_data[mid] <= value) begin
next_left = mid + 1;
end else begin
next_right = mid;
end
if (next_left < next_right) begin
left <= next_left;
right <= next_right;
end else begin
position_reg <= next_left;
end
if (count_down > 0) begin
count_down <= count_down - 1;
end else begin
state <= DONE;
end
end
DONE: begin
endcase
end
end
assign position = position_reg;
assign done = (state == DONE);
endmodule