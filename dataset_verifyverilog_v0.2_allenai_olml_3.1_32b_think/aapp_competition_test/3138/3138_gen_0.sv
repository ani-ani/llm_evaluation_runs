module arithmetic_book (
input [4:0] n,
input [31:0] numbers [0:15],
output reg [7:0] count
);
always @(*) begin
reg [63:0] sum, prod; reg i, j, k; count =0;
for (i=0; i <n; i = i +1) begin
for (j=i+1; j <n; j = j +1) begin
sum=0; prod=1;
for (k=i; k <=j; k = k +1) begin
sum = sum + numbers[k]; prod = prod * numbers[k];
end
if (sum == prod) count = count +1;
end
end
end
endmodule