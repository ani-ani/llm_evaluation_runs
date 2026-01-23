module cable_car_planner(input [3:0] n, input [2:0] k, output valid, output [3:0] ms_0, me_0, ms_1, me_1, ms_2, me_2, ms_3, me_3, output [3:0] vs_0, ve_0, vs_1, ve_1, vs_2, ve_2, vs_3, ve_3);
assign valid = (2*k <= n - 1);
assign ms_0 = (k > 0) ? 1 : 0;
assign me_0 = (k > 0) ? 2 : 0;
assign ms_1 = (k > 1) ? 3 : 0;
assign me_1 = (k > 1) ? 4 : 0;
assign ms_2 = (k > 2) ? 5 : 0;
assign me_2 = (k > 2) ? 6 : 0;
assign ms_3 = (k > 3) ? 7 : 0;
assign me_3 = (k > 3) ? 8 : 0;
assign vs_0 = (k > 0) ? 1 : 0;
assign ve_0 = (k > 0) ? n : 0;
assign vs_1 = (k > 1) ? 2 : 0;
assign ve_1 = (k > 1) ? (n - 1) : 0;
assign vs_2 = (k > 2) ? 3 : 0;
assign ve_2 = (k > 2) ? (n - 2) : 0;
assign vs_3 = (k > 3) ? 4 : 0;
assign ve_3 = (k > 3) ? (n - 3) : 0;
endmodule