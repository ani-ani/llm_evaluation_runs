module attendance_solver ( input reg clk, input reg rst_n, input reg start, input reg [2:0] student_name_in, input reg [2:0] required_name_in, output reg [7:0] total_inspections, output reg [7:0] position_history [0:7], output reg done );
reg [2:0] state;
reg [7:0] total;
reg [7:0] history [0:7];
reg [3:0] hist_idx;
reg done_reg;
reg [31:0] cnt;
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
total <= 8'd0;
history <= 8'd0;
hist_idx <= 4'd0;
done_reg <= 1'b0;
cnt <= 32'd0;
end else begin
if (state == 3'd0) begin
if (start == 1'b1) begin
state <= 3'd1;
cnt <= 32'd0;
end
end else if (state == 3'd1) begin
if (cnt < 8) cnt <= cnt + 1;
else begin
state <= 3'd2;
cnt <= 32'd0;
end
end else if (state == 3'd2) begin
if (cnt < 8) cnt <= cnt + 1;
else begin
state <= 3'd3;
end
end else if (state == 3'd3) begin
total <= total + 1;
history[hist_idx] <= 8'd1;
hist_idx <= hist_idx + 1;
if (hist_idx >= 8) begin
state <= 3'd4;
end
end else if (state == 3'd4) begin
cnt <= cnt + 1;
if (cnt >= 500) begin
done_reg <= 1'b1;
end
end
end
assign total_inspections = total;
assign position_history = history;
assign done = done_reg;
endmodule