module table_tennis_sets(
    input [15:0] k,
    input [15:0] a,
    input [15:0] b,
    output [15:0] result
);

    // Internal signals for division and modulo
    wire [15:0] count_a;
    wire [15:0] rem_a;
    wire [15:0] count_b;
    wire [15:0] rem_b;

    // Combinational logic to calculate quotient and remainder
    // Assume k is non-zero (as per problem statement k >= 1)
    assign count_a = a / k;
    assign rem_a   = a % k;
    assign count_b = b / k;
    assign rem_b   = b % k;

    // Conditions for validity
    // rem_a > 0 implies Vanya must have at least 1 win (count_b > 0)
    // rem_b > 0 implies Misha must have at least 1 win (count_a > 0)
    // If k=1, rem is always 0, so conditions are satisfied.
    // However, if k=1, count_a = a, count_b = b. If a>0, rem_a=0 -> ok. If b>0, rem_b=0 -> ok.
    // The problem says 0 to k-1 points for loser. If k=1, loser has 0.
    // So if a>0, Misha won sets. If b>0, Vanya won sets.
    // If a=0 and b=0 is excluded.
    // If k=1, and a=1, b=0: count_a=1, rem_a=0, count_b=0, rem_b=0. Valid. Total sets 1.
    // If k=1, and a=1, b=1: count_a=1, count_b=1. Valid. Total sets 2.
    // The logic below handles k=1 correctly because rem_a and rem_b will be 0.

    wire invalid_a = (rem_a > 0) && (count_b == 0);
    wire invalid_b = (rem_b > 0) && (count_a == 0);
    wire impossible = invalid_a || invalid_b;

    // If impossible, output 65535 (represents -1)
    // Else output count_a + count_b
    wire [15:0] total_sets;
    assign total_sets = count_a + count_b;

    assign result = impossible ? 16'd65535 : total_sets;

endmodule