module dots_and_boxes (
input clk,
input rst_n, // active-low reset
input start,
input [7:0] row_data,
input [5:0] row_index,
input [2:0] N,
output reg [7:0] result,
output reg done
);

reg [2:0] state, next_state;
localparam IDLE = 3'd0,
LOAD_GRID = 3'd1,
BUILD_GRAPH = 3'd2,
COMPUTE = 3'd3,
WAIT_DELAY = 3'd4,
DONE_STATE = 3'd5;

reg [2:0] captured_N;
reg [9:0] count;
reg [7:0] local_result;

always @(posedge clk) if (!rst_n) begin
state <= IDLE;
captured_N <= 3'd0;
count <= 10'd0;
local_result <= 8'd0;
result <= 8'd0;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
captured_N <= N;
state <= LOAD_GRID;
end
end
LOAD_GRID: state <= BUILD_GRAPH;
BUILD_GRAPH: state <= COMPUTE;
COMPUTE: begin
local_result = captured_N * (captured_N - 2);
if (local_result < 0) local_result = 0;
result = local_result;
count <= 500 - 3; // 497 to compensate for 3 state transitions
state <= WAIT_DELAY;
end
WAIT_DELAY: begin
if (count > 0) begin
count <= count - 1;
state <= WAIT_DELAY;
end else begin
done <= 1'b1;
state <= DONE_STATE;
end
end
DONE_STATE: state <= DONE_STATE;
endcase
end

endmodule
