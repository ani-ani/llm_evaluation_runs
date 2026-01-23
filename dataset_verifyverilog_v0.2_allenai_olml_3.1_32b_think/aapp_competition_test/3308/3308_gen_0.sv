module polygon_kernel_area (
input clk,
input rst_n,
input start,
input [2:0] vertex_count,
input [31:0] vertex_x [0:7],
input [31:0] vertex_y [0:7],
output reg [31:0] area,
output reg done,
output reg error
);

reg [2:0] state;
localparam IDLE = 3'd0;
localparam INIT_KERNEL = 3'd1;
localparam PROCESS_EDGE = 3'd2;
localparam CLIP_KERNEL = 3'd3;
localparam CALC_AREA = 3'd4;
localparam DONE = 3'd5;

reg [15:0] edge_index;
reg [15:0] kernel_vertex_count;
reg [31:0] kernel_x [0:15];
reg [31:0] kernel_y [0:15];
reg [31:0] area_reg;

// Next edge index
wire [2:0] next_edge_index;
always @(*) begin
if (edge_index == vertex_count -1) begin
next_edge_index = 3'd0;
end else begin
next_edge_index = edge_index + 3'd1;
end
end

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
edge_index <= 16'd0;
kernel_vertex_count <= 16'd0;
area_reg <= 32'd0;
done <= 1'b0;
error <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) state <= INIT_KERNEL;
end
INIT_KERNEL: begin
if (vertex_count >= 3) begin
kernel_x[0] <= vertex_x[0];
kernel_y[0] <= vertex_y[0];
kernel_x[1] <= vertex_x[1];
kernel_y[1] <= vertex_y[1];
kernel_x[2] <= vertex_x[2];
kernel_y[2] <= vertex_y[2];
kernel_vertex_count <= 3;
state <= PROCESS_EDGE;
end else begin
error <= 1'b1;
state <= DONE;
end
PROCESS_EDGE: begin
if (edge_index < vertex_count) state <= CLIP_KERNEL;
else state <= CALC_AREA;
end
CLIP_KERNEL: begin
state <= PROCESS_EDGE;
edge_index <= edge_index + 1;
end
CALC_AREA: begin
wire [63:0] sum1 = kernel_x[0] * kernel_y[1] + kernel_x[1] * kernel_y[2] + kernel_x[2] * kernel_y[0];
wire [63:0] sum2 = kernel_y[0] * kernel_x[1] + kernel_y[1] * kernel_x[2] + kernel_y[2] * kernel_x[0];
wire [63:0] area_val = sum1 - sum2;
area_reg <= area_val >> 32;
done <= 1'b1;
state <= DONE;
end
DONE: state <= DONE;
endcase
end
end

assign area = area_reg;
assign done = done;
assign error = error;

endmodule