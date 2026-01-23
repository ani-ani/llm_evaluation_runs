module iscube (
input clk,
input rst_n,
input start,
input signed [7:0] a,
output reg result,
output reg done
);

localparam ROOT_COUNT = 11;

reg [2:0] state;
reg [3:0] root_counter;
reg result, done;

reg [2:0] next_state;
reg [3:0] next_root_counter;
reg next_result;
reg next_done;

always @(*) begin
next_state = state;
next_root_counter = root_counter;
next_result = result;
next_done = done;

if (state == 3'b001) begin // CHECKING
if (a == ( ( (signed)root_counter - 5 ) * ( (signed)root_counter -5 ) * ( (signed)root_counter -5 ) )) begin
next_result = 1'b1;
next_done = 1'b1;
next_state = 3'b010; // DONE
end else begin
if (root_counter < ROOT_COUNT - 1) begin
next_root_counter = root_counter + 1;
end else begin
next_result = 1'b0;
next_done = 1'b1;
next_state = 3'b010;
end
end
end else if (state == 3'b000) begin // IDLE
if (start == 1'b1) begin
next_state = 3'b001;
next_root_counter = 4'd0;
end
end
end

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'b000;
root_counter <= 4'd0;
result <= 0;
done <= 0;
end else begin
state <= next_state;
root_counter <= next_root_counter;
result <= next_result;
done <= next_done;
end
end

endmodule