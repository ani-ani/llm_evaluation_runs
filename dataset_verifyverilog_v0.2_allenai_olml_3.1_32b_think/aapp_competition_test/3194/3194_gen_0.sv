module photo_scheduler (input clk, input rst_n, input start, input [7:0] n, input [15:0] t, input [7:0] photo_idx, input [15:0] a_i, input [15:0] b_i, input load, output reg result, output reg done);
reg [15:0] buffer_a [8:0];
reg [15:0] buffer_b [8:0];
reg [2:0] state;
reg [7:0] loaded_count;
reg [7:0] num_photos;
reg [2:0] i;
reg [2:0] j;
reg [15:0] current_end;
reg [7:0] process_idx;
reg failure;
reg [15:0] temp_a;
reg [15:0] temp_b;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'd0;
loaded_count <= 3'd0;
um_photos <= 3'd0;
i <= 3'd0;
j <= 3'd0;
current_end <= 16'd0;
process_idx <= 3'd0;
failure <= 1'b0;
result <= 1'b0;
done <= 1'b0;
end else begin
if (state == 3'd0) begin
if (start) begin
state <= 3'd1;
end
end else if (state == 3'd1) begin
if (load) begin
buffer_a[photo_idx] <= a_i;
buffer_b[photo_idx] <= b_i;
loaded_count <= loaded_count + 1;
end
if (loaded_count == n) begin
num_photos <= n;
state <= 3'd2;
i <= 3'd0;
j <= 3'd0;
end
end else if (state == 3'd2) begin
if (num_photos == 3'd0) begin
result <= 1'b1;
done <= 1'b1;
state <= 3'd4;
end else begin
if (i < num_photos) begin
if (j < (num_photos - i - 1)) begin
if (buffer_b[j] > buffer_b[j+1]) begin
temp_a = buffer_a[j];
temp_b = buffer_b[j];
buffer_a[j] = buffer_a[j+1];
buffer_b[j] = buffer_b[j+1];
buffer_a[j+1] = temp_a;
buffer_b[j+1] = temp_b;
end
j <= j + 1;
end else begin
j <= 3'd0;
i <= i + 1;
end
end else begin
state <= 3'd3;
end
end
end else if (state == 3'd3) begin
if (process_idx < num_photos) begin
[15:0] a = buffer_a[process_idx];
[15:0] b = buffer_b[process_idx];
[15:0] es = (current_end > a) ? current_end : a;
[15:0] ft = es + t;
if (ft > b) begin
failure <= 1'b1;
end
current_end <= ft;
process_idx <= process_idx + 1;
end else begin
result <= !failure;
done <= 1'b1;
state <= 3'd4;
end
end else if (state == 3'd4) begin
end
end
end
endmodule