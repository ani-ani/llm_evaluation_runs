module remove_odd (
    input [7:0] data_in [0:7],
    input [2:0] valid_count,
    output [7:0] data_out [0:7],
    output [2:0] out_count
);

localparam MAX_ELEMENTS = 8;
assign clamped_count = valid_count > MAX_ELEMENTS ? MAX_ELEMENTS : valid_count;

wire even_0, even_1, even_2, even_3, even_4, even_5, even_6, even_7;
assign even_0 = (clamped_count > 0) ? !data_in[0][0] : 1'b0;
assign even_1 = (clamped_count > 1) ? !data_in[1][0] : 1'b0;
assign even_2 = (clamped_count > 2) ? !data_in[2][0] : 1'b0;
assign even_3 = (clamped_count > 3) ? !data_in[3][0] : 1'b0;
assign even_4 = (clamped_count > 4) ? !data_in[4][0] : 1'b0;
assign even_5 = (clamped_count > 5) ? !data_in[5][0] : 1'b0;
assign even_6 = (clamped_count > 6) ? !data_in[6][0] : 1'b0;
assign even_7 = (clamped_count > 7) ? !data_in[7][0] : 1'b0;

assign total_evens = even_0 + even_1 + even_2 + even_3 + even_4 + even_5 + even_6 + even_7;
assign out_count = total_evens;

wire [3:0] cum_evens_0, cum_evens_1, cum_evens_2, cum_evens_3,
       cum_evens_4, cum_evens_5, cum_evens_6, cum_evens_7;
assign cum_evens_0 = even_0;
assign cum_evens_1 = cum_evens_0 + even_1;
assign cum_evens_2 = cum_evens_1 + even_2;
assign cum_evens_3 = cum_evens_2 + even_3;
assign cum_evens_4 = cum_evens_3 + even_4;
assign cum_evens_5 = cum_evens_4 + even_5;
assign cum_evens_6 = cum_evens_5 + even_6;
assign cum_evens_7 = cum_evens_6 + even_7;

wire [0:7] hit_0_i, hit_1_i, hit_2_i, hit_3_i,
       hit_4_i, hit_5_i, hit_6_i, hit_7_i;

assign hit_0_i[0] = (clamped_count > 0) && (cum_evens_0 == 1);
assign hit_0_i[1] = (clamped_count > 1) && (cum_evens_1 == 1) && (cum_evens_0 == 0);
assign hit_0_i[2] = (clamped_count > 2) && (cum_evens_2 == 1) && (cum_evens_1 == 0);
assign hit_0_i[3] = (clamped_count > 3) && (cum_evens_3 == 1) && (cum_evens_2 == 0);
assign hit_0_i[4] = (clamped_count > 4) && (cum_evens_4 == 1) && (cum_evens_3 == 0);
assign hit_0_i[5] = (clamped_count > 5) && (cum_evens_5 == 1) && (cum_evens_4 == 0);
assign hit_0_i[6] = (clamped_count > 6) && (cum_evens_6 == 1) && (cum_evens_5 == 0);
assign hit_0_i[7] = (clamped_count > 7) && (cum_evens_7 == 1) && (cum_evens_6 == 0);

assign hit_1_i[0] = (clamped_count > 0) && (cum_evens_0 == 2);
assign hit_1_i[1] = (clamped_count > 1) && (cum_evens_1 == 2) && (cum_evens_0 == 1);
assign hit_1_i[2] = (clamped_count > 2) && (cum_evens_2 == 2) && (cum_evens_1 == 1);
assign hit_1_i[3] = (clamped_count > 3) && (cum_evens_3 == 2) && (cum_evens_2 == 1);
assign hit_1_i[4] = (clamped_count > 4) && (cum_evens_4 == 2) && (cum_evens_3 == 1);
assign hit_1_i[5] = (clamped_count > 5) && (cum_evens_5 == 2) && (cum_evens_4 == 1);
assign hit_1_i[6] = (clamped_count > 6) && (cum_evens_6 == 2) && (cum_evens_5 == 1);
assign hit_1_i[7] = (clamped_count > 7) && (cum_evens_7 == 2) && (cum_evens_6 == 1);

assign hit_2_i[0] = (clamped_count > 0) && (cum_evens_0 == 3);
assign hit_2_i[1] = (clamped_count > 1) && (cum_evens_1 == 3) && (cum_evens_0 == 2);
assign hit_2_i[2] = (clamped_count > 2) && (cum_evens_2 == 3) && (cum_evens_1 == 2);
assign hit_2_i[3] = (clamped_count > 3) && (cum_evens_3 == 3) && (cum_evens_2 == 2);
assign hit_2_i[4] = (clamped_count > 4) && (cum_evens_4 == 3) && (cum_evens_3 == 2);
assign hit_2_i[5] = (clamped_count > 5) && (cum_evens_5 == 3) && (cum_evens_4 == 2);
assign hit_2_i[6] = (clamped_count > 6) && (cum_evens_6 == 3) && (cum_evens_5 == 2);
assign hit_2_i[7] = (clamped_count > 7) && (cum_evens_7 == 3) && (cum_evens_6 == 2);

assign hit_3_i[0] = (clamped_count > 0) && (cum_evens_0 == 4);
assign hit_3_i[1] = (clamped_count > 1) && (cum_evens_1 == 4) && (cum_evens_0 == 3);
assign hit_3_i[2] = (clamped_count > 2) && (cum_evens_2 == 4) && (cum_evens_1 == 3);
assign hit_3_i[3] = (clamped_count > 3) && (cum_evens_3 == 4) && (cum_evens_2 == 3);
assign hit_3_i[4] = (clamped_count > 4) && (cum_evens_4 == 4) && (cum_evens_3 == 3);
assign hit_3_i[5] = (clamped_count > 5) && (cum_evens_5 == 4) && (cum_evens_4 == 3);
assign hit_3_i[6] = (clamped_count > 6) && (cum_evens_6 == 4) && (cum_evens_5 == 3);
assign hit_3_i[7] = (clamped_count > 7) && (cum_evens_7 == 4) && (cum_evens_6 == 3);

assign hit_4_i[0] = (clamped_count > 0) && (cum_evens_0 == 5);
assign hit_4_i[1] = (clamped_count > 1) && (cum_evens_1 == 5) && (cum_evens_0 == 4);
assign hit_4_i[2] = (clamped_count > 2) && (cum_evens_2 == 5) && (cum_evens_1 == 4);
assign hit_4_i[3] = (clamped_count > 3) && (cum_evens_3 == 5) && (cum_evens_2 == 4);
assign hit_4_i[4] = (clamped_count > 4) && (cum_evens_4 == 5) && (cum_evens_3 == 4);
assign hit_4_i[5] = (clamped_count > 5) && (cum_evens_5 == 5) && (cum_evens_4 == 4);
assign hit_4_i[6] = (clamped_count > 6) && (cum_evens_6 == 5) && (cum_evens_5 == 4);
assign hit_4_i[7] = (clamped_count > 7) && (cum_evens_7 == 5) && (cum_evens_6 == 4);

assign hit_5_i[0] = (clamped_count > 0) && (cum_evens_0 == 6);
assign hit_5_i[1] = (clamped_count > 1) && (cum_evens_1 == 6) && (cum_evens_0 == 5);
assign hit_5_i[2] = (clamped_count > 2) && (cum_evens_2 == 6) && (cum_evens_1 == 5);
assign hit_5_i[3] = (clamped_count > 3) && (cum_evens_3 == 6) && (cum_evens_2 == 5);
assign hit_5_i[4] = (clamped_count > 4) && (cum_evens_4 == 6) && (cum_evens_3 == 5);
assign hit_5_i[5] = (clamped_count > 5) && (cum_evens_5 == 6) && (cum_evens_4 == 5);
assign hit_5_i[6] = (clamped_count > 6) && (cum_evens_6 == 6) && (cum_evens_5 == 5);
assign hit_5_i[7] = (clamped_count > 7) && (cum_evens_7 == 6) && (cum_evens_6 == 5);

assign hit_6_i[0] = (clamped_count > 0) && (cum_evens_0 == 7);
assign hit_6_i[1] = (clamped_count > 1) && (cum_evens_1 == 7) && (cum_evens_0 == 6);
assign hit_6_i[2] = (clamped_count > 2) && (cum_evens_2 == 7) && (cum_evens_1 == 6);
assign hit_6_i[3] = (clamped_count > 3) && (cum_evens_3 == 7) && (cum_evens_2 == 6);
assign hit_6_i[4] = (clamped_count > 4) && (cum_evens_4 == 7) && (cum_evens_3 == 6);
assign hit_6_i[5] = (clamped_count > 5) && (cum_evens_5 == 7) && (cum_evens_4 == 6);
assign hit_6_i[6] = (clamped_count > 6) && (cum_evens_6 == 7) && (cum_evens_5 == 6);
assign hit_6_i[7] = (clamped_count > 7) && (cum_evens_7 == 7) && (cum_evens_6 == 6);

assign hit_7_i[0] = (clamped_count > 0) && (cum_evens_0 == 8);
assign hit_7_i[1] = (clamped_count > 1) && (cum_evens_1 == 8) && (cum_evens_0 == 7);
assign hit_7_i[2] = (clamped_count > 2) && (cum_evens_2 == 8) && (cum_evens_1 == 7);
assign hit_7_i[3] = (clamped_count > 3) && (cum_evens_3 == 8) && (cum_evens_2 == 7);
assign hit_7_i[4] = (clamped_count > 4) && (cum_evens_4 == 8) && (cum_evens_3 == 7);
assign hit_7_i[5] = (clamped_count > 5) && (cum_evens_5 == 8) && (cum_evens_4 == 7);
assign hit_7_i[6] = (clamped_count > 6) && (cum_evens_6 == 8) && (cum_evens_5 == 7);
assign hit_7_i[7] = (clamped_count > 7) && (cum_evens_7 == 8) && (cum_evens_6 == 7);

assign data_out_0 = hit_0_i[0] ? data_in[0] : hit_0_i[1] ? data_in[1] : hit_0_i[2] ? data_in[2] : hit_0_i[3] ? data_in[3] : hit_0_i[4] ? data_in[4] : hit_0_i[5] ? data_in[5] : hit_0_i[6] ? data_in[6] : hit_0_i[7] ? data_in[7] : 8'b0;
assign data_out_1 = hit_1_i[0] ? data_in[0] : hit_1_i[1] ? data_in[1] : hit_1_i[2] ? data_in[2] : hit_1_i[3] ? data_in[3] : hit_1_i[4] ? data_in[4] : hit_1_i[5] ? data_in[5] : hit_1_i[6] ? data_in[6] : hit_1_i[7] ? data_in[7] : 8'b0;
assign data_out_2 = hit_2_i[0] ? data_in[0] : hit_2_i[1] ? data_in[1] : hit_2_i[2] ? data_in[2] : hit_2_i[3] ? data_in[3] : hit_2_i[4] ? data_in[4] : hit_2_i[5] ? data_in[5] : hit_2_i[6] ? data_in[6] : hit_2_i[7] ? data_in[7] : 8'b0;
assign data_out_3 = hit_3_i[0] ? data_in[0] : hit_3_i[1] ? data_in[1] : hit_3_i[2] ? data_in[2] : hit_3_i[3] ? data_in[3] : hit_3_i[4] ? data_in[4] : hit_3_i[5] ? data_in[5] : hit_3_i[6] ? data_in[6] : hit_3_i[7] ? data_in[7] : 8'b0;
assign data_out_4 = hit_4_i[0] ? data_in[0] : hit_4_i[1] ? data_in[1] : hit_4_i[2] ? data_in[2] : hit_4_i[3] ? data_in[3] : hit_4_i[4] ? data_in[4] : hit_4_i[5] ? data_in[5] : hit_4_i[6] ? data_in[6] : hit_4_i[7] ? data_in[7] : 8'b0;
assign data_out_5 = hit_5_i[0] ? data_in[0] : hit_5_i[1] ? data_in[1] : hit_5_i[2] ? data_in[2] : hit_5_i[3] ? data_in[3] : hit_5_i[4] ? data_in[4] : hit_5_i[5] ? data_in[5] : hit_5_i[6] ? data_in[6] : hit_5_i[7] ? data_in[7] : 8'b0;
assign data_out_6 = hit_6_i[0] ? data_in[0] : hit_6_i[1] ? data_in[1] : hit_6_i[2] ? data_in[2] : hit_6_i[3] ? data_in[3] : hit_6_i[4] ? data_in[4] : hit_6_i[5] ? data_in[5] : hit_6_i[6] ? data_in[6] : hit_6_i[7] ? data_in[7] : 8'b0;
assign data_out_7 = hit_7_i[0] ? data_in[0] : hit_7_i[1] ? data_in[1] : hit_7_i[2] ? data_in[2] : hit_7_i[3] ? data_in[3] : hit_7_i[4] ? data_in[4] : hit_7_i[5] ? data_in[5] : hit_7_i[6] ? data_in[6] : hit_7_i[7] ? data_in[7] : 8'b0;

assign data_out[0] = data_out_0;
assign data_out[1] = data_out_1;
assign data_out[2] = data_out_2;
assign data_out[3] = data_out_3;
assign data_out[4] = data_out_4;
assign data_out[5] = data_out_5;
assign data_out[6] = data_out_6;
assign data_out[7] = data_out_7;

endmodule
