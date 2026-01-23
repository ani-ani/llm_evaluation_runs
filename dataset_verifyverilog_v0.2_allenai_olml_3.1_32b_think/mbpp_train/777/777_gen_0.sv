module sum_non_repeated (
input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
output [15:0] sum
);

wire [7:0] stage0 [0:7];
wire [7:0] stage1 [0:7];
wire [7:0] stage2 [0:7];
wire [7:0] stage3 [0:7];

wire sw0;
wire [7:0] temp0_0, temp0_1;
wire sw2;
wire [7:0] temp2_0, temp2_1;
wire sw4;
wire [7:0] temp4_0, temp4_1;
wire sw6;
wire [7:0] temp6_0, temp6_1;

wire sw1;
wire [7:0] temp1_1, temp1_2;
wire sw3;
wire [7:0] temp3_3, temp3_4;
wire sw5;
wire [7:0] temp5_5, temp5_6;

wire sw2_stage3;
wire [7:0] temp2s_2, temp2s_3;
wire sw4_stage3;
wire [7:0] temp4s_4, temp4s_5;
wire sw6_stage3;
wire [7:0] temp6s_6, temp6s_7;

assign stage0[0] = arr_0;
assign stage0[1] = arr_1;
assign stage0[2] = arr_2;
assign stage0[3] = arr_3;
assign stage0[4] = arr_4;
assign stage0[5] = arr_5;
assign stage0[6] = arr_6;
assign stage0[7] = arr_7;

assign sw0 = stage0[0] > stage0[1];
assign temp0_0 = sw0 ? stage0[1] : stage0[0];
assign temp0_1 = sw0 ? stage0[0] : stage0[1];

assign sw2 = stage0[2] > stage0[3];
assign temp2_0 = sw2 ? stage0[3] : stage0[2];
assign temp2_1 = sw2 ? stage0[2] : stage0[3];

assign sw4 = stage0[4] > stage0[5];
assign temp4_0 = sw4 ? stage0[5] : stage0[4];
assign temp4_1 = sw4 ? stage0[4] : stage0[5];

assign sw6 = stage0[6] > stage0[7];
assign temp6_0 = sw6 ? stage0[7] : stage0[6];
assign temp6_1 = sw6 ? stage0[6] : stage0[7];

assign stage1[0] = temp0_0;
assign stage1[1] = temp0_1;
assign stage1[2] = temp2_0;
assign stage1[3] = temp2_1;
assign stage1[4] = temp4_0;
assign stage1[5] = temp4_1;
assign stage1[6] = temp6_0;
assign stage1[7] = temp6_1;

assign sw1 = stage1[1] > stage1[2];
assign temp1_1 = sw1 ? stage1[2] : stage1[1];
assign temp1_2 = sw1 ? stage1[1] : stage1[2];

assign sw3 = stage1[3] > stage1[4];
assign temp3_3 = sw3 ? stage1[4] : stage1[3];
assign temp3_4 = sw3 ? stage1[3] : stage1[4];

assign sw5 = stage1[5] > stage1[6];
assign temp5_5 = sw5 ? stage1[6] : stage1[5];
assign temp5_6 = sw5 ? stage1[5] : stage1[6];

assign stage2[0] = stage1[0];
assign stage2[1] = temp1_1;
assign stage2[2] = temp1_2;
assign stage2[3] = temp3_3;
assign stage2[4] = temp3_4;
assign stage2[5] = temp5_5;
assign stage2[6] = temp5_6;
assign stage2[7] = stage1[7];

assign sw2_stage3 = stage2[2] > stage2[3];
assign temp2s_2 = sw2_stage3 ? stage2[3] : stage2[2];
assign temp2s_3 = sw2_stage3 ? stage2[2] : stage2[3];

assign sw4_stage3 = stage2[4] > stage2[5];
assign temp4s_4 = sw4_stage3 ? stage2[5] : stage2[4];
assign temp4s_5 = sw4_stage3 ? stage2[4] : stage2[5];

assign sw6_stage3 = stage2[6] > stage2[7];
assign temp6s_6 = sw6_stage3 ? stage2[7] : stage2[6];
assign temp6s_7 = sw6_stage3 ? stage2[6] : stage2[7];

assign stage3[0] = stage2[0];
assign stage3[1] = stage2[1];
assign stage3[2] = temp2s_2;
assign stage3[3] = temp2s_3;
assign stage3[4] = temp4s_4;
assign stage3[5] = temp4s_5;
assign stage3[6] = temp6s_6;
assign stage3[7] = temp6s_7;

assign add[0] = 1'b1;
assign add[1] = stage3[1] != stage3[0];
assign add[2] = stage3[2] != stage3[1];
assign add[3] = stage3[3] != stage3[2];
assign add[4] = stage3[4] != stage3[3];
assign add[5] = stage3[5] != stage3[4];
assign add[6] = stage3[6] != stage3[5];
assign add[7] = stage3[7] != stage3[6];

assign sum =
    (add[0] ? stage3[0] : 0) +
    (add[1] ? stage3[1] : 0) +
    (add[2] ? stage3[2] : 0) +
    (add[3] ? stage3[3] : 0) +
    (add[4] ? stage3[4] : 0) +
    (add[5] ? stage3[5] : 0) +
    (add[6] ? stage3[6] : 0) +
    (add[7] ? stage3[7] : 0);

endmodule