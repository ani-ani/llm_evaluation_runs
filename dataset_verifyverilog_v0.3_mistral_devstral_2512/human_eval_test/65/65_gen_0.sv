module circular_shift(
    input [31:0] x,
    input [4:0] shift,
    output [31:0] result
);
    assign result = {x[shift - 1:0], x[31:shift]};
endmodule