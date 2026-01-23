module elastic_band_area (
input clk,
input rst_n,
input start,
input [5:0] num_points,
input [5:0] num_removals,
input [31:0] points_x [0:15],
input [31:0] points_y [0:15],
input [3:0] removals [0:13],
output reg [31:0] area_out,
output reg [3:0] area_idx,
output reg area_valid,
output reg done
);

reg [15:0] active;
reg [3:0] removal_idx;
reg [31:0] current_area;
reg [3:0] area_counter;
reg [3:0] state;

always @(posedge clk) begin
if (!rst_n) begin
active <= 16'b1111111111111111;
removal_idx <= 4'b0000;
current_area <= 32'b0000000000000000;
area_counter <= 4'b0000;
state <= 4'b0000;
area_valid <= 1'b0;
done <= 1'b0;
end else begin
if (start) begin
if (state == 4'b0000) begin
state <= 4'b0001;
end
end
end
end

always @(posedge clk) begin
if (!rst_n) begin
// already handled
end else begin
case (state)
4'b0001: begin
if (1'b0) state <= 4'b0010; else state <= 4'b0001;
current_area <= 32'b0000;
area_valid <= 1'b0;
end
4'b0010: begin
area_valid <= 1'b1;
area_idx <= area_counter;
state <= 4'b0011;
area_counter <= area_counter + 1'b1;
end
4'b0011: begin
removal_idx <= removal_idx + 1'b1;
if (removal_idx == num_removals) begin
state <= 4'b0100;
done <= 1'b1;
end else begin
state <= 4'b0001;
end
end
4'b0100: state <= 4'b0100;
done <= 1'b1;
default: state <= 4'b0000;
endcase
end
end

assign area_out = current_area;
assign area_idx = area_counter;
assign area_valid = area_valid;
assign done = done;

endmodule