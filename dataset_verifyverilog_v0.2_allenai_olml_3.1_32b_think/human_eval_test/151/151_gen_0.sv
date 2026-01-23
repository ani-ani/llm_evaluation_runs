module double_the_difference (
    input [7:0] nums [0:7],
    output reg [15:0] result
);
assign term0 = ( (nums[0] >= 0) & (nums[0] & 1) ) ? (nums[0] * nums[0]) : 0;
assign term1 = ( (nums[1] >= 0) & (nums[1] & 1) ) ? (nums[1] * nums[1]) : 0;
assign term2 = ( (nums[2] >= 0) & (nums[2] & 1) ) ? (nums[2] * nums[2]) : 0;
assign term3 = ( (nums[3] >= 0) & (nums[3] & 1) ) ? (nums[3] * nums[3]) : 0;
assign term4 = ( (nums[4] >= 0) & (nums[4] & 1) ) ? (nums[4] * nums[4]) : 0;
assign term5 = ( (nums[5] >= 0) & (nums[5] & 1) ) ? (nums[5] * nums[5]) : 0;
assign term6 = ( (nums[6] >= 0) & (nums[6] & 1) ) ? (nums[6] * nums[6]) : 0;
assign term7 = ( (nums[7] >= 0) & (nums[7] & 1) ) ? (nums[7] * nums[7]) : 0;
assign result = term0 + term1 + term2 + term3 + term4 + term5 + term6 + term7;
endmodule