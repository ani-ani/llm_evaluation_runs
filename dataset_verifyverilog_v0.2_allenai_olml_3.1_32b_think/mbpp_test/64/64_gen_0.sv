module sort_tuples(
    input [15:0] tuple_0,
    input [15:0] tuple_1,
    input [15:0] tuple_2,
    input [15:0] tuple_3,
    output [15:0] sorted_0,
    output [15:0] sorted_1,
    output [15:0] sorted_2,
    output [15:0] sorted_3
);
wire [15:0] s0_0, s0_1, s0_2, s0_3;
wire [15:0] s1_0, s1_1, s1_2, s1_3;
assign s0_0 = (tuple_0[15:8] > tuple_1[15:8]) ? tuple_1 : tuple_0;
assign s0_1 = (tuple_0[15:8] > tuple_1[15:8]) ? tuple_0 : tuple_1;
assign s0_2 = (tuple_2[15:8] > tuple_3[15:8]) ? tuple_3 : tuple_2;
assign s0_3 = (tuple_2[15:8] > tuple_3[15:8]) ? tuple_2 : tuple_3;
assign s1_0 = s0_0;
assign s1_1 = (s0_1[15:8] > s0_2[15:8]) ? s0_2 : s0_1;
assign s1_2 = (s0_1[15:8] > s0_2[15:8]) ? s0_1 : s0_2;
assign s1_3 = s0_3;
assign sorted_0 = (s1_0[15:8] > s1_1[15:8]) ? s1_1 : s1_0;
assign sorted_1 = (s1_0[15:8] > s1_1[15:8]) ? s1_0 : s1_1;
assign sorted_2 = (s1_2[15:8] > s1_3[15:8]) ? s1_3 : s1_2;
assign sorted_3 = (s1_2[15:8] > s1_3[15:8]) ? s1_2 : s1_3;
endmodule