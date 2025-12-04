module sum_odds_range (
    input wire [7:0] l, r,
    output wire [15:0] sum
);

    // Compute half_r and half_l
    wire [7:0] half_r = (r + 1) >> 1;
    wire [7:0] half_l = l >> 1;

    // Compute r_sum and l_sum
    wire [15:0] r_sum = half_r * half_r;
    wire [15:0] l_sum = half_l * half_l;

    assign sum = r_sum - l_sum;

endmodule