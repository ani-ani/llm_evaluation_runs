module unsorted_permutations(input [3:0] n, input [7:0][31:0] data, output [31:0] count);
reg [31:0] count;
reg [3:0] i,j,k,l;
reg [31:0] a,b,c,d;
reg valid;
always @(*) begin
count =0;
valid = 0;
if (n==4) begin
for (i=0; i<4; i++)
for (j=0; j<4; j++)
if (j !=i)
for (k=0; k<4; k++)
if (k !=i && k !=j)
for (l=0; l<4; l++)
if (l !=i && l !=j && l !=k) begin
a = data[i][31:0];
b = data[j][31:0];
c = data[k][31:0];
d = data[l][31:0];
valid = 1;
// Position0: a
if (b>=a && c>=a && d>=a) valid=0;
else begin
// Position1: b
if (c>=b && d>=b && a<=b) valid=0;
else begin
// Position2: c
if (d>=c && a<=c && b<=c) valid=0;
else begin
// Position3: d
if (a<=d && b<=d && c<=d) valid=0;
end
end
end
end
if (valid) count++;
end
end
end
count = count % 1000000009;
end
assign count = count;
endmodule