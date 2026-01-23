module gcd_distinct_counter (
   input [3:0] n,
   input [15:0] a [0:3],
   output reg [3:0] distinct_count
);

localparam [3:0] i_list [0:9] = '{3'd0,0,0,0,1,1,1,2,2,3';
localparam [3:0] j_list [0:9] = '{3'd0,1,2,3,1,2,3,2,3,3';

assign valid[0] = 1'b1;
assign valid[1] = (n > 1);
assign valid[2] = (n > 2);
assign valid[3] = (n == 4);
assign valid[4] = (n > 1);
assign valid[5] = (n > 2);
assign valid[6] = (n == 4);
assign valid[7] = (n > 2);
assign valid[8] = (n == 4);
assign valid[9] = (n == 4);

reg [15:0] gcd_values [0:9];

gcd_values[0] = a[i_list[0]];
gcd_values[1] = valid[1] ? gcd_2(a[i_list[1]], a[i_list[1]+1]) : 0;
gcd_values[2] = valid[2] ? gcd_2(a[i_list[2]], gcd_2(a[i_list[2]+1], a[i_list[2]+2])) : 0;
gcd_values[3] = valid[3] ? gcd_2(a[i_list[3]], gcd_2(a[i_list[3]+1], gcd_2(a[i_list[3]+2], a[i_list[3]+3]))) : 0;
gcd_values[4] = valid[4] ? a[i_list[4]] : 0;
gcd_values[5] = valid[5] ? gcd_2(a[i_list[5]], a[i_list[5]+1]) : 0;
gcd_values[6] = valid[6] ? gcd_2(a[i_list[6]], gcd_2(a[i_list[6]+1], a[i_list[6]+2])) : 0;
gcd_values[7] = valid[7] ? a[i_list[7]] : 0;
gcd_values[8] = valid[8] ? gcd_2(a[i_list[8]], a[i_list[8]+1]) : 0;
gcd_values[9] = valid[9] ? a[i_list[9]] : 0;

wire [1:0] is_unique [0:9];

is_unique[0] = valid[0] & (!valid[0] | 1);
is_unique[1] = valid[1] & (!valid[0] | (gcd_values[1] != gcd_values[0]));
is_unique[2] = valid[2] & ((!valid[0] | gcd_values[2] != gcd_values[0]) & (!valid[1] | gcd_values[2] != gcd_values[1]));
is_unique[3] = valid[3] & ((!valid[0] | gcd_values[3] != gcd_values[0]) & (!valid[1] | gcd_values[3] != gcd_values[1]) & (!valid[2] | gcd_values[3] != gcd_values[2]));
is_unique[4] = valid[4] & ((!valid[0] | gcd_values[4] != gcd_values[0]) & (!valid[1] | gcd_values[4] != gcd_values[1]) & (!valid[2] | gcd_values[4] != gcd_values[2]) & (!valid[3] | gcd_values[4] != gcd_values[3]));
is_unique[5] = valid[5] & ((!valid[0] | gcd_values[5] != gcd_values[0]) & (!valid[1] | gcd_values[5] != gcd_values[1]) & (!valid[2] | gcd_values[5] != gcd_values[2]) & (!valid[3] | gcd_values[5] != gcd_values[3]) & (!valid[4] | gcd_values[5] != gcd_values[4]));
is_unique[6] = valid[6] & ((!valid[0] | gcd_values[6] != gcd_values[0]) & (!valid[1] | gcd_values[6] != gcd_values[1]) & (!valid[2] | gcd_values[6] != gcd_values[2]) & (!valid[3] | gcd_values[6] != gcd_values[3]) & (!valid[4] | gcd_values[6] != gcd_values[4]) & (!valid[5] | gcd_values[6] != gcd_values[5]));
is_unique[7] = valid[7] & ((!valid[0] | gcd_values[7] != gcd_values[0]) & (!valid[1] | gcd_values[7] != gcd_values[1]) & (!valid[2] | gcd_values[7] != gcd_values[2]) & (!valid[3] | gcd_values[7] != gcd_values[3]) & (!valid[4] | gcd_values[7] != gcd_values[4]) & (!valid[5] | gcd_values[7] != gcd_values[5]) & (!valid[6] | gcd_values[7] != gcd_values[6]));
is_unique[8] = valid[8] & ((!valid[0] | gcd_values[8] != gcd_values[0]) & (!valid[1] | gcd_values[8] != gcd_values[1]) & (!valid[2] | gcd_values[8] != gcd_values[2]) & (!valid[3] | gcd_values[8] != gcd_values[3]) & (!valid[4] | gcd_values[8] != gcd_values[4]) & (!valid[5] | gcd_values[8] != gcd_values[5]) & (!valid[6] | gcd_values[8] != gcd_values[6]) & (!valid[7] | gcd_values[8] != gcd_values[7]));
is_unique[9] = valid[9] & ((!valid[0] | gcd_values[9] != gcd_values[0]) & (!valid[1] | gcd_values[9] != gcd_values[1]) & (!valid[2] | gcd_values[9] != gcd_values[2]) & (!valid[3] | gcd_values[9] != gcd_values[3]) & (!valid[4] | gcd_values[9] != gcd_values[4]) & (!valid[5] | gcd_values[9] != gcd_values[5]) & (!valid[6] | gcd_values[9] != gcd_values[6]) & (!valid[7] | gcd_values[9] != gcd_values[7]) & (!valid[8] | gcd_values[9] != gcd_values[8]));

assign distinct_count = is_unique[0] + is_unique[1] + is_unique[2] + is_unique[3] + is_unique[4] + is_unique[5] + is_unique[6] + is_unique[7] + is_unique[8] + is_unique[9];

function [15:0] gcd_2;
input [15:0] a, b;
begin
   if (b == 0) return a;
   return gcd_2(b, a % b);
endfunction

endmodule