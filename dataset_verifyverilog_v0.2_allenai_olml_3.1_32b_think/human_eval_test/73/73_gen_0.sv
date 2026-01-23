module smallest_change(input [3:0] arr [0:7], output [3:0] changes);
assign changes = (arr[0] ^ arr[7]) != 0 + (arr[1] ^ arr[6]) != 0 + (arr[2] ^ arr[5]) != 0 + (arr[3] ^ arr[4]) != 0;
endmodule