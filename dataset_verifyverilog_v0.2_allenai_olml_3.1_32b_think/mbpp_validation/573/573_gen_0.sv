module unique_product(input [7:0] data [0:7], output reg [31:0] product, output reg valid);
always @(*) begin
reg [31:0] acc;
reg overflow;
reg [7:0] current_data;
reg [63:0] product_temp;
integer i, j;
integer is_unique;
acc = 32'd1;
overflow = 1'b0;
for (i=0; i<8; i++) begin
is_unique = 1;
for (j=0; j<i; j++) begin
if (data[j] == data[i]) begin
is_unique = 0;
break;
end
end
if (is_unique) begin
current_data = data[i];
if (current_data == 8'd0) begin
acc = 32'd0;
end else begin
current_data = {24'b0, current_data};
product_temp = acc * current_data;
if (product_temp[63:32] != 64'd0) begin
overflow = 1'b1;
end
acc = product_temp[31:0];
end
end
end
product = acc;
valid = !overflow;
end
endmodule