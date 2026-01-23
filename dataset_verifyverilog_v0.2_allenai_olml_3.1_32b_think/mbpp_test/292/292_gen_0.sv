module integer_division (
input [15:0] dividend,
input [15:0] divisor,
output [15:0] quotient
);

wire [15:0] next_remainder_15, next_remainder_14, next_remainder_13, next_remainder_12, next_remainder_11, next_remainder_10, next_remainder_9, next_remainder_8, next_remainder_7, next_remainder_6, next_remainder_5, next_remainder_4, next_remainder_3, next_remainder_2, next_remainder_1, next_remainder_0;
wire [1:0] q_15, q_14, q_13, q_12, q_11, q_10, q_9, q_8, q_7, q_6, q_5, q_4, q_3, q_2, q_1, q_0;

assign q_15 = (dividend[15] >= divisor) ? 1'b1 : 1'b0;
assign next_remainder_15 = (dividend[15] >= divisor) ? (dividend[15] - divisor) : dividend[15];

assign q_14 = ((next_remainder_15 << 1) | dividend[14]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_14 = ((next_remainder_15 << 1) | dividend[14]) >= divisor ? ((next_remainder_15 << 1) | dividend[14] - divisor) : ((next_remainder_15 << 1) | dividend[14]);

assign q_13 = ((next_remainder_14 << 1) | dividend[13]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_13 = ((next_remainder_14 << 1) | dividend[13]) >= divisor ? ((next_remainder_14 << 1) | dividend[13] - divisor) : ((next_remainder_14 << 1) | dividend[13]);

assign q_12 = ((next_remainder_13 << 1) | dividend[12]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_12 = ((next_remainder_13 << 1) | dividend[12]) >= divisor ? ((next_remainder_13 << 1) | dividend[12] - divisor) : ((next_remainder_13 << 1) | dividend[12]);

assign q_11 = ((next_remainder_12 << 1) | dividend[11]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_11 = ((next_remainder_12 << 1) | dividend[11]) >= divisor ? ((next_remainder_12 << 1) | dividend[11] - divisor) : ((next_remainder_12 << 1) | dividend[11]);

assign q_10 = ((next_remainder_11 << 1) | dividend[10]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_10 = ((next_remainder_11 << 1) | dividend[10]) >= divisor ? ((next_remainder_11 << 1) | dividend[10] - divisor) : ((next_remainder_11 << 1) | dividend[10]);

assign q_9 = ((next_remainder_10 << 1) | dividend[9]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_9 = ((next_remainder_10 << 1) | dividend[9]) >= divisor ? ((next_remainder_10 << 1) | dividend[9] - divisor) : ((next_remainder_10 << 1) | dividend[9]);

assign q_8 = ((next_remainder_9 << 1) | dividend[8]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_8 = ((next_remainder_9 << 1) | dividend[8]) >= divisor ? ((next_remainder_9 << 1) | dividend[8] - divisor) : ((next_remainder_9 << 1) | dividend[8]);

assign q_7 = ((next_remainder_8 << 1) | dividend[7]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_7 = ((next_remainder_8 << 1) | dividend[7]) >= divisor ? ((next_remainder_8 << 1) | dividend[7] - divisor) : ((next_remainder_8 << 1) | dividend[7]);

assign q_6 = ((next_remainder_7 << 1) | dividend[6]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_6 = ((next_remainder_7 << 1) | dividend[6]) >= divisor ? ((next_remainder_7 << 1) | dividend[6] - divisor) : ((next_remainder_7 << 1) | dividend[6]);

assign q_5 = ((next_remainder_6 << 1) | dividend[5]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_5 = ((next_remainder_6 << 1) | dividend[5]) >= divisor ? ((next_remainder_6 << 1) | dividend[5] - divisor) : ((next_remainder_6 << 1) | dividend[5]);

assign q_4 = ((next_remainder_5 << 1) | dividend[4]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_4 = ((next_remainder_5 << 1) | dividend[4]) >= divisor ? ((next_remainder_5 << 1) | dividend[4] - divisor) : ((next_remainder_5 << 1) | dividend[4]);

assign q_3 = ((next_remainder_4 << 1) | dividend[3]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_3 = ((next_remainder_4 << 1) | dividend[3]) >= divisor ? ((next_remainder_4 << 1) | dividend[3] - divisor) : ((next_remainder_4 << 1) | dividend[3]);

assign q_2 = ((next_remainder_3 << 1) | dividend[2]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_2 = ((next_remainder_3 << 1) | dividend[2]) >= divisor ? ((next_remainder_3 << 1) | dividend[2] - divisor) : ((next_remainder_3 << 1) | dividend[2]);

assign q_1 = ((next_remainder_2 << 1) | dividend[1]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_1 = ((next_remainder_2 << 1) | dividend[1]) >= divisor ? ((next_remainder_2 << 1) | dividend[1] - divisor) : ((next_remainder_2 << 1) | dividend[1]);

assign q_0 = ((next_remainder_1 << 1) | dividend[0]) >= divisor ? 1'b1 : 1'b0;
assign next_remainder_0 = ((next_remainder_1 << 1) | dividend[0]) >= divisor ? ((next_remainder_1 << 1) | dividend[0] - divisor) : ((next_remainder_1 << 1) | dividend[0]);

assign quotient = { q_15, q_14, q_13, q_12, q_11, q_10, q_9, q_8, q_7, q_6, q_5, q_4, q_3, q_2, q_1, q_0 };
endmodule