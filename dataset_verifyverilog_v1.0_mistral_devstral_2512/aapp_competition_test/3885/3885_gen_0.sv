module min_cost_ticket(
    input wire [16:0] n,
    output wire [15:0] result
);
    // Compute (n - 1) / 2 using right shift (floor division for unsigned)
    assign result = (n - 1) >> 1;
endmodule