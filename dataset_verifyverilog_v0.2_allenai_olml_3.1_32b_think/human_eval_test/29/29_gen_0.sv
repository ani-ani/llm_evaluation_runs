module filter_by_prefix (
input [63:0] strings [0:7],
input [63:0] prefix,
input [2:0] prefix_len,
output [63:0] matches [0:7],
output [2:0] match_count
);
wire [7:0] match_vector [0:7];
wire [2:0] count_before [0:7];
reg [63:0] matches [0:7];
always @(*) begin
int i, k;
for (i=0; i<8; i++) begin
match_vector[i] = 1'b1;
if (prefix_len !=0) begin
for (k=0; k < prefix_len; k++) begin
if ( ( (strings[i] >> (56 - 8*k)) & 0xFF ) != ( (prefix >> (56 -8*k)) & 0xFF ) ) begin
match_vector[i] =1'b0;
break;
end
end
end
end
end
end
always @(*) begin
int i, cnt;
cnt=0;
for (i=0; i<8; i++) begin
count_before[i] = cnt;
if (match_vector[i]) cnt++;
end
end
assign match_count = match_vector[0] + match_vector[1] + match_vector[2] + match_vector[3] + match_vector[4] + match_vector[5] + match_vector[6] + match_vector[7];
always @(*) begin
int j, i;
for (j=0; j<8; j++) begin
matches[j] = 64'b0;
for (i=0; i<8; i++) begin
if (match_vector[i] && (count_before[i] == j)) begin
matches[j] = strings[i];
break;
end
end
end
end
endmodule