module tuple_divisible_filter (
input [7:0] tuple_0_elem_0,
input [7:0] tuple_0_elem_1,
input [7:0] tuple_0_elem_2,
input [7:0] tuple_1_elem_0,
input [7:0] tuple_1_elem_1,
input [7:0] tuple_1_elem_2,
input [7:0] tuple_2_elem_0,
input [7:0] tuple_2_elem_1,
input [7:0] tuple_2_elem_2,
input [7:0] K,
output [2:0] valid
);
wire [7:0] mod0_0 = tuple_0_elem_0 % K;
wire [7:0] mod0_1 = tuple_0_elem_1 % K;
wire [7:0] mod0_2 = tuple_0_elem_2 % K;
wire valid0 = (mod0_0 == 8'd0) && (mod0_1 == 8'd0) && (mod0_2 == 8'd0);
wire [7:0] mod1_0 = tuple_1_elem_0 % K;
wire [7:0] mod1_1 = tuple_1_elem_1 % K;
wire [7:0] mod1_2 = tuple_1_elem_2 % K;
wire valid1 = (mod1_0 == 8'd0) && (mod1_1 == 8'd0) && (mod1_2 == 8'd0);
wire [7:0] mod2_0 = tuple_2_elem_0 % K;
wire [7:0] mod2_1 = tuple_2_elem_1 % K;
wire [7:0] mod2_2 = tuple_2_elem_2 % K;
wire valid2 = (mod2_0 == 8'd0) && (mod2_1 == 8'd0) && (mod2_2 == 8'd0);
assign valid[0] = valid0;
assign valid[1] = valid1;
assign valid[2] = valid2;
endmodule