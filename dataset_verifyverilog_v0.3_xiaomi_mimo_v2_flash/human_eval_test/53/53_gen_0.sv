module adder (
    input [31:0] x,
    input [31:0] y,
    output [31:0] result
);

    assign result = x + y;

endmodule