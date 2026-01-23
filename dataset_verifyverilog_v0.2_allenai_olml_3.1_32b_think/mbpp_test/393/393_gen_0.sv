module max_length_list (
    reg [3:0] valid_mask,
    reg [3:0][3:0][7:0] lists,
    output [1:0] max_length_idx,
    output [3:0][7:0] max_list,
    output [2:0] max_length
);

wire [3][2:0] lengths;
assign lengths[0] = valid_mask[0] ? ( (lists[0][0] ? 1 : 0) + (lists[0][1] ? 1 : 0) + (lists[0][2] ? 1 : 0) + (lists[0][3] ? 1 : 0) ) : 0;
assign lengths[1] = valid_mask[1] ? ( (lists[1][0] ? 1 : 0) + (lists[1][1] ? 1 : 0) + (lists[1][2] ? 1 : 0) + (lists[1][3] ? 1 : 0) ) : 0;
assign lengths[2] = valid_mask[2] ? ( (lists[2][0] ? 1 : 0) + (lists[2][1] ? 1 : 0) + (lists[2][2] ? 1 : 0) + (lists[2][3] ? 1 : 0) ) : 0;
assign lengths[3] = valid_mask[3] ? ( (lists[3][0] ? 1 : 0) + (lists[3][1] ? 1 : 0) + (lists[3][2] ? 1 : 0) + (lists[3][3] ? 1 : 0) ) : 0;

wire [2:0] temp_max0_1, temp_max0_2;
assign temp_max0_1 = (lengths[0] > lengths[1]) ? lengths[0] : lengths[1];
assign temp_max0_2 = (temp_max0_1 > lengths[2]) ? temp_max0_1 : lengths[2];
assign max_length = (temp_max0_2 > lengths[3]) ? temp_max0_2 : lengths[3];

wire [3] is_candidate;
assign is_candidate[0] = (lengths[0] == max_length);
assign is_candidate[1] = (lengths[1] == max_length);
assign is_candidate[2] = (lengths[2] == max_length);
assign is_candidate[3] = (lengths[3] == max_length);

assign max_length_idx = (is_candidate[0] ? 0 : (is_candidate[1] ? 1 : (is_candidate[2] ? 2 : 3)));
assign max_list = lists[max_length_idx];

endmodule