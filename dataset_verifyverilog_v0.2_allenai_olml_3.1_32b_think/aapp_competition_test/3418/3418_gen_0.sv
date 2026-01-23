module lucky_numbers_supply(input clk, input rst_n, input start, input [3:0] n, output reg [31:0] supply, output reg done);
localparam [31:0] lut [4:1] = {4'd1: 32'd9, 4'd2: 32'd45, 4'd3: 32'd150, 4'd4: 32'd375, 4'd5: 32'd750, 4'd6: 32'd1200, 4'd7: 32'd1710, 4'd8: 32'd1950};
reg [3:0] state;
reg [3:0] count;
reg [3:0] target_n;
reg [3:0] current_n;
initial state = 0;
always @(posedge clk) begin
if (!rst_n) begin
state <= 0;
supply <= 32'd0;
done <= 0;
target_n <= 4'd0;
current_n <= 4'd0;
count <= 4'd0;
end else begin
if (start) begin
if (state == 0) begin
target_n <= n;
current_n <= n;
state <= 1;
count <= 4'd0;
end
end
if (state == 1) begin
if (count < 64'd64) begin
count <= count + 1;
if (count == 64'd64) begin
if (target_n >= 1 && target_n <= 8) begin
supply <= lut[target_n];
end else begin
supply <= 32'd0;
end
done <= 1;
state <= 2;
end
end
end
end
endmodule