module any_int(
    input signed [15:0] x,
    input signed [15:0] y,
    input signed [15:0] z,
    output result
);

wire [15:0] sum_yz;
wire [15:0] sum_xz;
wire [15:0] sum_xy;

assign sum_yz = y + z;
assign sum_xz = x + z;
assign sum_xy = x + y;

wire cond1;
wire cond2;
wire cond3;
assign cond1 = (x == sum_yz);
assign cond2 = (y == sum_xz);
assign cond3 = (z == sum_xy);

assign result = cond1 | cond2 | cond3;

endmodule