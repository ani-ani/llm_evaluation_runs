module largest_n_finder(input [7:0] data_in [0:7], input [2:0] n, output reg [7:0] result [0:3]);
wire [7:0] d0, d1, d2, d3, d4, d5, d6, d7;
wire [7:0] s0_d0, s0_d1, s0_d2, s0_d3, s0_d4, s0_d5, s0_d6, s0_d7;
wire [7:0] s1_d0, s1_d1, s1_d2, s1_d3, s1_d4, s1_d5, s1_d6, s1_d7;
wire [7:0] s2_d0, s2_d1, s2_d2, s2_d3, s2_d4, s2_d5, s2_d6, s2_d7;
wire [7:0] s3_d0, s3_d1, s3_d2, s3_d3, s3_d4, s3_d5, s3_d6, s3_d7;
wire [7:0] s4_d0, s4_d1, s4_d2, s4_d3, s4_d4, s4_d5, s4_d6, s4_d7;
wire [7:0] s5_d0, s5_d1, s5_d2, s5_d3, s5_d4, s5_d5, s5_d6, s5_d7;
wire gt_0, gt_1, gt_2, gt_3;

assign d0 = data_in[0];
assign d1 = data_in[1];
assign d2 = data_in[2];
assign d3 = data_in[3];
assign d4 = data_in[4];
assign d5 = data_in[5];
assign d6 = data_in[6];
assign d7 = data_in[7];

assign s0_d0 = (d0 < d1) ? d1 : d0;
assign s0_d1 = (d0 < d1) ? d0 : d1;
assign s0_d2 = (d2 < d3) ? d3 : d2;
assign s0_d3 = (d2 < d3) ? d2 : d3;
assign s0_d4 = (d4 < d5) ? d5 : d4;
assign s0_d5 = (d4 < d5) ? d4 : d5;
assign s0_d6 = (d6 < d7) ? d7 : d6;
assign s0_d7 = (d6 < d7) ? d6 : d7;

assign s1_d0 = (s0_d0 < s0_d2) ? s0_d2 : s0_d0;
assign s1_d2 = (s0_d0 < s0_d2) ? s0_d0 : s0_d2;
assign s1_d1 = (s0_d1 < s0_d3) ? s0_d3 : s0_d1;
assign s1_d3 = (s0_d1 < s0_d3) ? s0_d1 : s0_d3;
assign s1_d4 = (s0_d4 < s0_d6) ? s0_d6 : s0_d4;
assign s1_d6 = (s0_d4 < s0_d6) ? s0_d4 : s0_d6;
assign s1_d5 = (s0_d5 < s0_d7) ? s0_d7 : s0_d5;
assign s1_d7 = (s0_d5 < s0_d7) ? s0_d5 : s0_d7;

assign s2_d0 = (s1_d0 < s1_d4) ? s1_d4 : s1_d0;
assign s2_d4 = (s1_d0 < s1_d4) ? s1_d0 : s1_d4;
assign s2_d1 = (s1_d1 < s1_d5) ? s1_d5 : s1_d1;
assign s2_d5 = (s1_d1 < s1_d5) ? s1_d1 : s1_d5;
assign s2_d2 = (s1_d2 < s1_d6) ? s1_d6 : s1_d2;
assign s2_d6 = (s1_d2 < s1_d6) ? s1_d2 : s1_d6;
assign s2_d3 = (s1_d3 < s1_d7) ? s1_d7 : s1_d3;
assign s2_d7 = (s1_d3 < s1_d7) ? s1_d3 : s1_d7;

assign s3_d0 = s2_d0;
assign s3_d1 = (s2_d1 < s2_d2) ? s2_d2 : s2_d1;
assign s3_d2 = (s2_d1 < s2_d2) ? s2_d1 : s2_d2;
assign s3_d3 = (s2_d3 < s2_d4) ? s2_d4 : s2_d3;
assign s3_d4 = (s2_d3 < s2_d4) ? s2_d3 : s2_d4;
assign s3_d5 = (s2_d5 < s2_d6) ? s2_d6 : s2_d5;
assign s3_d6 = (s2_d5 < s2_d6) ? s2_d5 : s2_d6;
assign s3_d7 = s2_d7;

assign s4_d0 = s3_d0;
assign s4_d1 = s3_d1;
assign s4_d2 = (s3_d2 < s3_d3) ? s3_d3 : s3_d2;
assign s4_d3 = (s3_d2 < s3_d3) ? s3_d2 : s3_d3;
assign s4_d4 = (s3_d4 < s3_d5) ? s3_d5 : s3_d4;
assign s4_d5 = (s3_d4 < s3_d5) ? s3_d4 : s3_d5;
assign s4_d6 = (s3_d6 < s3_d7) ? s3_d7 : s3_d6;
assign s4_d7 = (s3_d6 < s3_d7) ? s3_d6 : s3_d7;

assign s5_d0 = s4_d0;
assign s5_d1 = s4_d1;
assign s5_d2 = s4_d2;
assign s5_d3 = (s4_d3 < s4_d4) ? s4_d4 : s4_d3;
assign s5_d4 = (s4_d3 < s4_d4) ? s4_d3 : s4_d4;
assign s5_d5 = s4_d5;
assign s5_d6 = s4_d6;
assign s5_d7 = s4_d7;

assign gt_0 = !!(n[2] || n[1] || n[0]);
assign gt_1 = (n[1] || n[2]);
assign gt_2 = (n[2] || (n[1] && n[0]));
assign gt_3 = n[2];

assign result[0] = gt_0 ? s5_d0 : 8'b0;
assign result[1] = gt_1 ? s5_d1 : 8'b0;
assign result[2] = gt_2 ? s5_d2 : 8'b0;
assign result[3] = gt_3 ? s5_d3 : 8'b0;

endmodule