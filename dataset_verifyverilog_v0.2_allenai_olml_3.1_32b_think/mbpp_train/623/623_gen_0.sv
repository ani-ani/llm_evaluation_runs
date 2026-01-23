module nth_power_array(input signed [7:0][15:0] nums_i, input [2:0] power_i, output signed [7:0][31:0] results_o);
always @(*) begin
for (int i=0; i<8; i++) begin
case (power_i)
0: results_o[i] = 1;
1: results_o[i] = nums_i[i];
2: results_o[i] = nums_i[i] * nums_i[i];
3: results_o[i] = nums_i[i] * nums_i[i] * nums_i[i];
4: results_o[i] = (nums_i[i] * nums_i[i]) * (nums_i[i] * nums_i[i]);
5: results_o[i] = (nums_i[i] * nums_i[i]) * (nums_i[i] * nums_i[i]) * nums_i[i];
endcase
end
end
endmodule