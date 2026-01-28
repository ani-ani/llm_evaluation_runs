module iscube(
    input signed [7:0] a,
    output is_cube
);
    wire is_cube;
    assign is_cube = (a == -64) || (a == -27) || (a == -8) || (a == -1) || (a == 0) || (a == 1) || (a == 8) || (a == 27) || (a == 64);
endmodule