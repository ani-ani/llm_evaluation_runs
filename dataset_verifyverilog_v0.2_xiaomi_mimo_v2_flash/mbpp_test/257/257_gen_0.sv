module swap_numbers(
    input [15:0] a,
    input [15:0] b,
    output [15:0] swapped_a,
    output [15:0] swapped_b
);
    assign swapped_a = b;
    assign swapped_b = a;
endmodule