module sorted_checker(input reg [39:0] flat_list, output wire is_sorted);

wire cmp0, cmp1, cmp2, cmp3, cmp4, cmp5, cmp6;

assign cmp0 = (flat_list[4:0] <= flat_list[9:5]);
assign cmp1 = (flat_list[9:5] <= flat_list[14:10]);
assign cmp2 = (flat_list[14:10] <= flat_list[19:15]);
assign cmp3 = (flat_list[19:15] <= flat_list[24:20]);
assign cmp4 = (flat_list[24:20] <= flat_list[29:25]);
assign cmp5 = (flat_list[29:25] <= flat_list[34:30]);
assign cmp6 = (flat_list[34:30] <= flat_list[39:35]);

assign is_sorted = (cmp0 & cmp1 & cmp2 & cmp3 & cmp4 & cmp5 & cmp6);

endmodule