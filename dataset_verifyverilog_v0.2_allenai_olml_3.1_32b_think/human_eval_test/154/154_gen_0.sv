module cycpattern_check(input [63:0] a, input [63:0] b, input [3:0] len_a, input [3:0] len_b, output result);
wire [7:0] a_bytes [0:7];
wire [7:0] b_bytes [0:7];
assign a_bytes[0] = (len_a > 0) ? a[7:0] : 8'b0;
assign a_bytes[1] = (len_a > 1) ? a[15:8] : 8'b0;
assign a_bytes[2] = (len_a > 2) ? a[23:16] : 8'b0;
assign a_bytes[3] = (len_a > 3) ? a[31:24] : 8'b0;
assign a_bytes[4] = (len_a > 4) ? a[39:32] : 8'b0;
assign a_bytes[5] = (len_a > 5) ? a[47:40] : 8'b0;
assign a_bytes[6] = (len_a > 6) ? a[55:48] : 8'b0;
assign a_bytes[7] = (len_a > 7) ? a[63:56] : 8'b0;
assign b_bytes[0] = (len_b > 0) ? b[7:0] : 8'b0;
assign b_bytes[1] = (len_b > 1) ? b[15:8] : 8'b0;
assign b_bytes[2] = (len_b > 2) ? b[23:16] : 8'b0;
assign b_bytes[3] = (len_b > 3) ? b[31:24] : 8'b0;
assign b_bytes[4] = (len_b > 4) ? b[39:32] : 8'b0;
assign b_bytes[5] = (len_b > 5) ? b[47:40] : 8'b0;
assign b_bytes[6] = (len_b > 6) ? b[55:48] : 8'b0;
assign b_bytes[7] = (len_b > 7) ? b[63:56] : 8'b0;
assign result = 0;
generate
for (int i=0; i<8; i++) begin: gen_i
if (i < len_b) begin
wire [7:0] rotated_bytes [0:7];
generate
for (int k=0; k<8; k++) begin: gen_k
if (k < len_b) begin
int index;
if (i + k < len_b) begin
index = i + k;
end else begin
index = i + k - len_b;
end
rotated_bytes[k] = b_bytes[index];
end
end
endgenerate
if (len_a >= len_b) begin
for (int s=0; s < len_a - len_b +1; s++) begin: gen_s
int match=1;
for (int k=0; k<len_b; k++) begin: gen_k_match
if (a_bytes[s + k] != rotated_bytes[k]) begin
match=0;
break;
end
end
if (match) begin
result = 1;
end
end
end
end
endgenerate
endmodule