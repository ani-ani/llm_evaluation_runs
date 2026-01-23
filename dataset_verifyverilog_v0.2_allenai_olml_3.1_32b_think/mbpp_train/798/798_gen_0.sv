module array_sum (
input clk,
input rst_n,
input start,
input [2:0] array_length,
input [7:0] array_data [7:0],
output reg [15:0] result,
output reg done
);

reg [15:0] accum;
reg [2:0] index;
reg [2:0] n_elements;
reg [2:0] state;

localparam IDLE = 3'd0,
LOAD = 3'd1,
PROCESSING = 3'd2,
DONE = 3'd3;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
accum <= 16'd0;
index <= 3'd0;
n_elements <= 3'd0;
state <= IDLE;
result <= 16'd0;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= LOAD;
end else begin
state <= IDLE;
end
end
LOAD: begin
n_elements <= (array_length == 3'd0) ? 8 : array_length;
accum <= 16'd0;
index <= 3'd0;
state <= PROCESSING;
end
PROCESSING: begin
if (index < n_elements) begin
accum <= accum + array_data[index];
end
index <= index + 1;
if (index == 8) begin
state <= DONE;
end else begin
state <= PROCESSING;
end
end
DONE: begin
state <= DONE;
end
endcase
result <= accum;
done <= (state == DONE);
end
end
endmodule