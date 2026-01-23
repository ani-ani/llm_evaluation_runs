module diff_even_odd (
    input [7:0] list1 [0:7],
    output [7:0] diff
);

wire is_even [0:7];
wire prev_all_odd [0:7];
wire prev_all_even [0:7];
wire cond_first_even [0:7];
wire cond_first_odd [0:7];

assign is_even[0] = !(list1[0] & 1);
assign is_even[1] = !(list1[1] & 1);
assign is_even[2] = !(list1[2] & 1);
assign is_even[3] = !(list1[3] & 1);
assign is_even[4] = !(list1[4] & 1);
assign is_even[5] = !(list1[5] & 1);
assign is_even[6] = !(list1[6] & 1);
assign is_even[7] = !(list1[7] & 1);

assign prev_all_odd[0] = 1'b1;
assign prev_all_odd[1] = prev_all_odd[0] & (!is_even[0]);
assign prev_all_odd[2] = prev_all_odd[1] & (!is_even[1]);
assign prev_all_odd[3] = prev_all_odd[2] & (!is_even[2]);
assign prev_all_odd[4] = prev_all_odd[3] & (!is_even[3]);
assign prev_all_odd[5] = prev_all_odd[4] & (!is_even[4]);
assign prev_all_odd[6] = prev_all_odd[5] & (!is_even[5]);
assign prev_all_odd[7] = prev_all_odd[6] & (!is_even[6]);

assign prev_all_even[0] = 1'b1;
assign prev_all_even[1] = prev_all_even[0] & is_even[0];
assign prev_all_even[2] = prev_all_even[1] & is_even[1];
assign prev_all_even[3] = prev_all_even[2] & is_even[2];
assign prev_all_even[4] = prev_all_even[3] & is_even[3];
assign prev_all_even[5] = prev_all_even[4] & is_even[4];
assign prev_all_even[6] = prev_all_even[5] & is_even[5];
assign prev_all_even[7] = prev_all_even[6] & is_even[6];

assign cond_first_even[0] = is_even[0] & prev_all_odd[0];
assign cond_first_even[1] = is_even[1] & prev_all_odd[1];
assign cond_first_even[2] = is_even[2] & prev_all_odd[2];
assign cond_first_even[3] = is_even[3] & prev_all_odd[3];
assign cond_first_even[4] = is_even[4] & prev_all_odd[4];
assign cond_first_even[5] = is_even[5] & prev_all_odd[5];
assign cond_first_even[6] = is_even[6] & prev_all_odd[6];
assign cond_first_even[7] = is_even[7] & prev_all_odd[7];

assign cond_first_odd[0] = (!is_even[0]) & prev_all_even[0];
assign cond_first_odd[1] = (!is_even[1]) & prev_all_even[1];
assign cond_first_odd[2] = (!is_even[2]) & prev_all_even[2];
assign cond_first_odd[3] = (!is_even[3]) & prev_all_even[3];
assign cond_first_odd[4] = (!is_even[4]) & prev_all_even[4];
assign cond_first_odd[5] = (!is_even[5]) & prev_all_even[5];
assign cond_first_odd[6] = (!is_even[6]) & prev_all_even[6];
assign cond_first_odd[7] = (!is_even[7]) & prev_all_even[7];

assign first_even_val = cond_first_even[0] ? list1[0] : cond_first_even[1] ? list1[1] : cond_first_even[2] ? list1[2] : cond_first_even[3] ? list1[3] : cond_first_even[4] ? list1[4] : cond_first_even[5] ? list1[5] : cond_first_even[6] ? list1[6] : cond_first_even[7] ? list1[7] : 8'hFF;

assign first_odd_val = cond_first_odd[0] ? list1[0] : cond_first_odd[1] ? list1[1] : cond_first_odd[2] ? list1[2] : cond_first_odd[3] ? list1[3] : cond_first_odd[4] ? list1[4] : cond_first_odd[5] ? list1[5] : cond_first_odd[6] ? list1[6] : cond_first_odd[7] ? list1[7] : 8'hFF;

assign diff = first_even_val - first_odd_val;

endmodule