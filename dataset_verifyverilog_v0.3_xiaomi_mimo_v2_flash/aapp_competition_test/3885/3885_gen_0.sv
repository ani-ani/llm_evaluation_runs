module min_cost_ticket(
    input wire [16:0] n,
    output wire [15:0] result
);
    // Compute (n - 1) / 2 using right shift (floor division for unsigned)
    // Since n is 17 bits and result is 16 bits, we need to handle potential overflow
    // when n is 100000, (n-1) is 99999 which fits in 17 bits
    wire [16:0] n_minus_one;
    assign n_minus_one = n - 17'd1;
    assign result = n_minus_one[16:1];  // Right shift by 1 (divide by 2)
endmodule