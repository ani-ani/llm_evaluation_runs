module fib_seq_solver(
    input [19:0] n,
    input [19:0] a,
    input [19:0] d,
    output [63:0] b,
    output [63:0] e
);

    // Constants
    wire [63:0] CONST = 64'd368131125;
    wire [63:0] MOD = 64'd1000000000;
    wire [63:0] SCALE = 64'd12000000000;

    // Compute b and e
    assign b = ((CONST * a) % MOD) * SCALE + 64'd1;
    assign e = ((CONST * d) % MOD) * SCALE;

endmodule