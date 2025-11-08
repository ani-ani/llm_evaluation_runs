module TopModule(
input clk,
input load,
input [255:0] data,
output [255:0] q
);
reg [15:0] grid [0:15];
assign q = {grid[15], grid[14], grid[13], grid[12], grid[11], grid[10], grid[9], grid[8], grid[7], grid[6], grid[5], grid[4], grid[3], grid[2], grid[1], grid[0]};
reg [15:0] next_grid [0:15];
always @(posedge clk) begin
if (load) begin
grid[0] <= data[15:0];
grid[1] <= data[31:16];
grid[2] <= data[47:32];
grid[3] <= data[63:48];
grid[4] <= data[79:64];
grid[5] <= data[95:80];
grid[6] <= data[111:96];
grid[7] <= data[127:112];
grid[8] <= data[143:128];
grid[9] <= data[159:144];
grid[10] <= data[175:160];
grid[11] <= data[191:176];
grid[12] <= data[207:192];
grid[13] <= data[223:208];
grid[14] <= data[239:224];
grid[15] <= data[255:240];
end else begin
integer r, c;
integer nr1, nr2, nc1, nc2;
integer sum_val;
for (r=0; r<16; r=r+1) begin
nr1 = (r-1 +16)%16;
nr2 = (r+1)%16;
for (c=0; c<16; c=c+1) begin
nc1 = (c-1 +16)%16;
nc2 = (c+1)%16;
sum_val = 0;
sum_val += grid[nr1][nc1];
sum_val += grid[nr1][c];
sum_val += grid[nr1][nc2];
sum_val += grid[r][nc1];
sum_val += grid[r][nc2];
sum_val += grid[nr2][nc1];
sum_val += grid[nr2][c];
sum_val += grid[nr2][nc2];
next_grid[r][c] = (sum_val == 3) || (sum_val == 2 && grid[r][c]);
end
end
grid[0] <= next_grid[0];
grid[1] <= next_grid[1];
grid[2] <= next_grid[2];
grid[3] <= next_grid[3];
grid[4] <= next_grid[4];
grid[5] <= next_grid[5];
grid[6] <= next_grid[6];
grid[7] <= next_grid[7];
grid[8] <= next_grid[8];
grid[9] <= next_grid[9];
grid[10] <= next_grid[10];
grid[11] <= next_grid[11];
grid[12] <= next_grid[12];
grid[13] <= next_grid[13];
grid[14] <= next_grid[14];
grid[15] <= next_grid[15];
end
end
endmodule