module count_same_pair (
    input [7:0] nums1,
    input [7:0] nums2,
    output [3:0] count
);
wire [7:0] xor = nums1 ^ nums2;
assign count = 8 - (xor[7] + xor[6] + xor[5] + xor[4] + xor[3] + xor[2] + xor[1] + xor[0]);
endmodule