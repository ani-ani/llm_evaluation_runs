module monotonic_check (
input clk,
input rst_n,
input start,
input [2:0] length,
input [7:0] data [0:7],
output reg result,
output reg done
);

reg [1:0] state;
reg [3:0] cycle_counter;
reg [2:0] index;
reg [1:0] direction;
reg [2:0] length_reg;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 2'b00;
cycle_counter <=4'd0;
index <=3'd0;
direction <=2'b00;
length_reg <=3'd0;
result <=1'b0;
done <=1'b0;
end else begin
case (state)
2'b00: begin
if (start) begin
state <= 2'b01;
cycle_counter <=4'd0;
index <=3'd0;
direction <=2'b00;
length_reg <= length;
result <=1'b1;
done <=1'b0;
end
end
2'b01: begin
if (cycle_counter <4'd10) begin
if (index < length_reg -1) begin
if (data[index] > data[index+1]) begin
if (direction ==2'b00) begin
direction <=2'b10;
end else if (direction ==2'b01) begin
result <=1'b0;
end
end else if (data[index] < data[index+1]) begin
if (direction ==2'b00) begin
direction <=2'b01;
end else if (direction ==2'b10) begin
result <=1'b0;
end
end
end
if (index < length_reg -1) begin
index <= index +1;
end
cycle_counter <= cycle_counter +1;
end else begin
state <=2'b10;
done <=1'b1;
end
end
2'b10: begin
state <=2'b10;
done <=1'b1;
end
endcase
end
endmodule