module power_substring_counter(input [15:0] n, input [3:0] e, output [15:0] count);
reg [15:0] power;
assign power = 1 << e;

// Compute digits_p
reg [4:0] digits_p [4:0];
assign digits_p[0] = power / 10000;
assign digits_p[1] = (power / 1000) % 10;
assign digits_p[2] = (power / 100) % 10;
assign digits_p[3] = (power / 10) % 10;
assign digits_p[4] = power % 10;

// Compute start_p
reg [2:0] start_p;
assign start_p = (digits_p[0] !=0) ? 3'd0 : (digits_p[1] !=0) ? 3'd1 : (digits_p[2] !=0) ? 3'd2 : (digits_p[3] !=0) ? 3'd3 : 3'd4;

localparam length_p = 5 - start_p;

// Initialize total to 0
reg [15:0] total;
always @(*) total = 0;

// Iterate all k from 0 to 65535
always_comb begin
for (int k=0; k <= 65535; k++) begin
// Compute digits_k
reg [4:0] digits_k [4:0];
digits_k[0] = k / 10000;
digits_k[1] = (k / 1000) % 10;
digits_k[2] = (k / 100) % 10;
digits_k[3] = (k / 10) % 10;
digits_k[4] = k % 10;

// Compute match_k
reg [15:0] match_k;
match_k = 0;
case (length_p)
1: match_k = (digits_k[0] == digits_p[start_p] || digits_k[1] == digits_p[start_p] || digits_k[2] == digits_p[start_p] || digits_k[3] == digits_p[start_p] || digits_k[4] == digits_p[start_p]);
break;
2: match_k = ( (digits_k[0] == digits_p[start_p] && digits_k[1] == digits_p[start_p+1]) || (digits_k[1] == digits_p[start_p] && digits_k[2] == digits_p[start_p+1]) || (digits_k[2] == digits_p[start_p] && digits_k[3] == digits_p[start_p+1]) || (digits_k[3] == digits_p[start_p] && digits_k[4] == digits_p[start_p+1]) );
break;
3: match_k = ( (digits_k[0] == digits_p[start_p] && digits_k[1] == digits_p[start_p+1] && digits_k[2] == digits_p[start_p+2]) || (digits_k[1] == digits_p[start_p] && digits_k[2] == digits_p[start_p+1] && digits_k[3] == digits_p[start_p+2]) || (digits_k[2] == digits_p[start_p] && digits_k[3] == digits_p[start_p+1] && digits_k[4] == digits_p[start_p+2]) );
break;
4: match_k = ( (digits_k[0] == digits_p[start_p] && digits_k[1] == digits_p[start_p+1] && digits_k[2] == digits_p[start_p+2] && digits_k[3] == digits_p[start_p+3]) || (digits_k[1] == digits_p[start_p] && digits_k[2] == digits_p[start_p+1] && digits_k[3] == digits_p[start_p+2] && digits_k[4] == digits_p[start_p+3]) );
break;
5: match_k = (digits_k[0] == digits_p[start_p] && digits_k[1] == digits_p[start_p+1] && digits_k[2] == digits_p[start_p+2] && digits_k[3] == digits_p[start_p+3] && digits_k[4] == digits_p[start_p+4]);
break;
default: match_k = 0;
endcase

// Check if k <=n
if (k <= n) begin
total = total + match_k[0]; // match_k is treated as 1 bit, taking LSB
end
end
end

assign count = total;
endmodule