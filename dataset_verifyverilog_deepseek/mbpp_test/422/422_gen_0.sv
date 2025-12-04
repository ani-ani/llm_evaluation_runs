module average_of_cubes(
    input wire [3:0] n,
    output wire [31:0] average_q16_16
);
    assign average_q16_16 = ( n * (n + 4'd1) * (n + 4'd1) ) << 14;
endmodule