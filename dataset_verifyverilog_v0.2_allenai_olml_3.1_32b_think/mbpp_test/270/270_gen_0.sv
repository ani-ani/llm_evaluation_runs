module sum_even_even_pos (
input [7:0] arr [0:7],
output [15:0] sum
);
assign sum = (arr[0][0] == 0 ? (16'd0 + arr[0]) : 16'd0) + (arr[2][0] == 0 ? (16'd0 + arr[2]) : 16'd0) + (arr[4][0] == 0 ? (16'd0 + arr[4]) : 16'd0) + (arr[6][0] == 0 ? (16'd0 + arr[6]) : 16'd0);
endmodule