module find_max_length(input [7:0] valid_mask, input [7:0][7:0] lengths, output [7:0] max_length);
reg [7:0] temp [0:7];
assign temp[0] = valid_mask[0] ? lengths[0] : 8'b0;
assign temp[1] = valid_mask[1] ? lengths[1] : 8'b0;
assign temp[2] = valid_mask[2] ? lengths[2] : 8'b0;
assign temp[3] = valid_mask[3] ? lengths[3] : 8'b0;
assign temp[4] = valid_mask[4] ? lengths[4] : 8'b0;
assign temp[5] = valid_mask[5] ? lengths[5] : 8'b0;
assign temp[6] = valid_mask[6] ? lengths[6] : 8'b0;
assign temp[7] = valid_mask[7] ? lengths[7] : 8'b0;
assign max01 = max(temp[0], temp[1]);
assign max23 = max(temp[2], temp[3]);
assign max45 = max(temp[4], temp[5]);
assign max67 = max(temp[6], temp[7]);
assign max03 = max(max01, max23);
assign max56 = max(max45, max67);
assign max_length = max(max03, max56);
endmodule