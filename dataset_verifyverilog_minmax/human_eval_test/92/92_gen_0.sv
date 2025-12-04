module any_int_check (
    input signed [7:0] x,
    input signed [7:0] y,
    input signed [7:0] z,
    output result
);
    assign result = (x == (y+z)[7:0]) | (y == (x+z)[7:0]) | (z == (x+y)[7:0]);
endmodule