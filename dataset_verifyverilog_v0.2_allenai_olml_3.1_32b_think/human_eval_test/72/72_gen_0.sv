module will_it_fly(input [7:0] w, input [2:0] q_len, input [7:0] q [0:7], output result);

assign cond0 = (q_len <= 1) ? 1'b1 : (q[0] == q[q_len - 1]);
assign cond1 = (q_len < 4) ? 1'b1 : (q[1] == q[q_len - 2]);
assign cond2 = (q_len < 6) ? 1'b1 : (q[2] == q[q_len - 3]);
assign cond3 = (q_len != 8) ? 1'b1 : (q[3] == q[q_len - 4]);
assign is_pal = cond0 & cond1 & cond2 & cond3;

assign sum = (q_len >0 ? {12{0}}q[0] : 12'b0) + (q_len >1 ? {12{0}}q[1] : 12'b0) + (q_len >2 ? {12{0}}q[2] : 12'b0) + (q_len >3 ? {12{0}}q[3] : 12'b0) + (q_len >4 ? {12{0}}q[4] : 12'b0) + (q_len >5 ? {12{0}}q[5] : 12'b0) + (q_len >6 ? {12{0}}q[6] : 12'b0) + (q_len >7 ? {12{0}}q[7] : 12'b0);
assign w_ext = {4{0}} w;
assign sum_le_w = sum <= w_ext;
assign result = is_pal & sum_le_w;
endmodule