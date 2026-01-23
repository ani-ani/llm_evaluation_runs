module random_picture_counter (
    input [3:0] N,
    input [3:0] M,
    output [29:0] result
);

    // Define the modulus
    localparam MOD = 30'd1000000007;

    // Define the Fibonacci lookup table wire array
    // F[0] = 1, F[1] = 1, ... F[15] = 987
    wire [9:0] fib [0:15];

    // Assign Fibonacci values (combinational)
    assign fib[0]  = 10'd1;
    assign fib[1]  = 10'd1;
    assign fib[2]  = 10'd2;
    assign fib[3]  = 10'd3;
    assign fib[4]  = 10'd5;
    assign fib[5]  = 10'd8;
    assign fib[6]  = 10'd13;
    assign fib[7]  = 10'd21;
    assign fib[8]  = 10'd34;
    assign fib[9]  = 10'd55;
    assign fib[10] = 10'd89;
    assign fib[11] = 10'd144;
    assign fib[12] = 10'd233;
    assign fib[13] = 10'd377;
    assign fib[14] = 10'd610;
    assign fib[15] = 10'd987;

    // Determine F[N] and F[M] based on inputs
    wire [9:0] val_N;
    wire [9:0] val_M;

    assign val_N = fib[N];
    assign val_M = fib[M];

    // Intermediate calculations
    // Sum = F[N] + F[M] - 1
    // Max sum = 987 + 987 - 1 = 1973 (fits in 11 bits, use 30 bits for safety)
    wire [29:0] sum;
    assign sum = val_N + val_M - 1;

    // Result = 2 * Sum mod (10^9 + 7)
    // Since sum is small (< 2000), 2*sum < 4000, which is much smaller than MOD.
    // No explicit modulo logic is needed for reduction, just multiplication.
    assign result = (sum << 1) % MOD;

endmodule