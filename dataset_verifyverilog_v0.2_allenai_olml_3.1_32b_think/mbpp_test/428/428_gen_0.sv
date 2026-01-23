module shell_sort_8 (
input clk,
input rst_n, // active-low reset
input start,
input [7:0] data_in [0:7], // 8 elements, each 8 bits
output reg [7:0] result [0:7],
output reg done
);

reg [7:0] array [0:7];
reg [2:0] state;
reg [2:0] gap4_count;
reg [2:0] gap2_count;
reg [2:0] gap1_count;
reg [7:0] temp;

localparam IDLE = 3'b000, GAP4 = 3'b001, GAP2 = 3'b010, GAP1 = 3'b011, DONE = 3'b100;

always @(posedge clk) begin
if (!rst_n) begin
array <= 8'b0;
state <= IDLE;
done <= 1'b0;
gap4_count <= 3'b000;
gap2_count <= 3'b000;
gap1_count <= 3'b000;
end else begin
if (state == IDLE) begin
if (start) begin
array <= data_in;
state <= GAP4;
gap4_count <= 3'b000;
end
end else if (state == GAP4) begin
if (gap4_count < 4) begin
gap4_count <= gap4_count + 1;
int i = 4 + gap4_count - 1;
if (i < 8 && array[i] < array[i - 4]) begin
temp = array[i];
array[i] = array[i - 4];
array[i - 4] = temp;
end
end else begin
state <= GAP2;
gap2_count <= 3'b000;
end
end else if (state == GAP2) begin
if (gap2_count < 4) begin
gap2_count <= gap2_count + 1;
int i = 2 + gap2_count - 1;
if (i < 8 && array[i] < array[i - 2]) begin
temp = array[i];
array[i] = array[i - 2];
array[i - 2] = temp;
end
end else begin
state <= GAP1;
gap1_count <= 3'b000;
end
end else if (state == GAP1) begin
if (gap1_count < 4) begin
gap1_count <= gap1_count + 1;
int i = 1 + gap1_count - 1;
if (i < 8 && array[i] < array[i - 1]) begin
temp = array[i];
array[i] = array[i - 1];
array[i - 1] = temp;
end
end else begin
state <= DONE;
done <= 1'b1;
result <= array;
end
end else if (state == DONE) begin
end
end
end
endmodule