module reverse_pair_counter (
input clk,
input rst_n,
input start,
input [7:0] str_data [0:4],
output reg [3:0] result,
output reg done);

reg [2:0] state;
reg [3:0] result_reg;
reg [7:0] captured_str_data [0:4];
reg [2:0] check_count;
reg [4:0] delay_counter;

parameter IDLE = 3'b000;
parameter CHECK_REVERSE = 3'b001;
parameter COUNT_PAIRS = 3'b010;
parameter DONE = 3'b011;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
result_reg <= 0;
captured_str_data <= 8'b0;
check_count <= 0;
delay_counter <= 0;
done <= 0;
end else begin
case (state)
IDLE: begin
if (start) begin
captured_str_data <= str_data;
state <= CHECK_REVERSE;
check_count <= 8;
end
else begin
state <= IDLE;
end
end
CHECK_REVERSE: begin
if (check_count > 0) begin
check_count <= check_count - 1;
state <= CHECK_REVERSE;
end
else begin
state <= COUNT_PAIRS;
end
end
COUNT_PAIRS: begin
result_reg <= 0;
state <= DONE;
delay_counter <= 31;
end
DONE: begin
if (delay_counter > 0) begin
delay_counter <= delay_counter - 1;
end
end
endcase
end
end

assign result = result_reg;
assign done = (state == DONE) && (delay_counter == 0);

endmodule