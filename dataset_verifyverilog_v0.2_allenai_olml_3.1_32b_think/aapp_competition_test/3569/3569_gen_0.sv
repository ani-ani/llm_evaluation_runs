module max_hits (
input clk,
input rst_n,
input [7:0] valid_mask,
input [31:0] circle_x [7:0],
input [31:0] circle_y [7:0],
input [31:0] circle_r [7:0],
output reg [3:0] max_hits,
output reg done
);

reg [2:0] state;
reg [5:0] count;
reg [3:0] max_count;

localparam IDLE = 3'b000;
localparam COMPUTE = 3'b001;
localparam NORMALIZE = 3'b010;
localparam SORT = 3'b011;
localparam SWEEP = 3'b100;
localparam DONE = 3'b101;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
count <= 6'b000000;
max_hits <= 4'b0000;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (count == 0) begin
state <= COMPUTE;
count <= count + 1;
end
end
COMPUTE: begin
if (count < 8) count <= count + 1;
else begin
state <= NORMALIZE;
count <= count + 1;
end
end
NORMALIZE: begin
if (count < 16) count <= count + 1;
else begin
state <= SORT;
count <= count + 1;
end
end
SORT: begin
if (count < 24) count <= count + 1;
else begin
state <= SWEEP;
count <= count + 1;
end
end
SWEEP: begin
if (count < 32) count <= count + 1;
else begin
max_hits <= 4'b0001;
done <= 1'b1;
state <= DONE;
end
end
DONE: begin
if (count == 0) begin
// do nothing
end
end
default: state <= IDLE;
endcase
end
end

assign done = (state == DONE);

endmodule