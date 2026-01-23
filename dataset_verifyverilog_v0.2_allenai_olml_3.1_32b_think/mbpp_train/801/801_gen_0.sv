module three_equal_counter (
    input signed [7:0] x,
    input signed [7:0] y,
    input signed [7:0] z,
    output reg [2:0] count
);
assign eq_xy = (x == y);
assign eq_yz = (y == z);
assign eq_xz = (x == z);
assign eq_all = eq_xy && eq_yz;
assign count = eq_all ? 3 : (eq_xy || eq_yz || eq_xz) ? 2 : 0;
endmodule