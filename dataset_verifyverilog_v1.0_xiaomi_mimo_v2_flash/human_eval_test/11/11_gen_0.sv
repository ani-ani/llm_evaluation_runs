module string_xor(
    input [15:0] a,
    input [15:0] b,
    output [15:0] result
);
    // Combinational bitwise XOR operation
    assign result = a ^ b;
endmodule