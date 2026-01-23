module intersperse(input reg [3:0] in_valid, input reg [3:0][7:0] in_data, input reg [7:0] delimiter, output reg [3:0] out_valid, output reg [7:0] out_data [7:0]);
always @(*) begin
integer i;
out_valid = (in_valid == 0) ? 4'd0 : 2*in_valid -1;
for (i=0; i<8; i=i+1) begin
if (i >= out_valid) begin
out_data[i] = 8'dX;
end else begin
if (i % 2 == 0) begin
integer element_idx;
element_idx = i / 2;
if (element_idx < in_valid) begin
out_data[i] = in_data[element_idx];
end else begin
out_data[i] = 8'dX;
end
end
end
end else begin
integer k;
k = (i - 1) / 2;
if (k < in_valid - 1) begin
out_data[i] = delimiter;
end else begin
out_data[i] = 8'dX;
end
end
end
end
end
endmodule