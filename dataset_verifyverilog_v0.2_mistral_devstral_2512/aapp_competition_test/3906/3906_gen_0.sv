module random_picture_counter (
    input [3:0] N,
    input [3:0] M,
    output [29:0] result
);

    // Precompute Fibonacci numbers up to F[15]
    localparam [29:0] FIB = '{1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987};

    // Lookup F[N] and F[M]
    wire [29:0] fib_N = FIB[N];
    wire [29:0] fib_M = FIB[M];

    // Compute Sum = F[N] + F[M] - 1
    wire [29:0] sum = fib_N + fib_M - 1;

    // Compute 2 * Sum modulo 10^9 + 7
    wire [29:0] two_sum = sum << 1;
    wire [29:0] mod_result = two_sum % 1000000007;

    assign result = mod_result;

endmodule