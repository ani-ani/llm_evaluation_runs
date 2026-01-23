module octagonal_number (
    input [7:0] n,
    output [15:0] result
);

    // Internal signals for intermediate calculations
    wire [15:0] n_squared;
    wire [15:0] three_times_n_squared;
    wire [15:0] two_times_n;

    // Calculate n^2 (8-bit * 8-bit = 16-bit)
    assign n_squared = n * n;

    // Calculate 3 * n^2
    assign three_times_n_squared = n_squared + (n_squared << 1);

    // Calculate 2 * n (zero-extended to 16 bits)
    assign two_times_n = {8'b0, n} << 1;

    // Calculate result: (3 * n^2) - (2 * n)
    assign result = three_times_n_squared - two_times_n;

endmodule
