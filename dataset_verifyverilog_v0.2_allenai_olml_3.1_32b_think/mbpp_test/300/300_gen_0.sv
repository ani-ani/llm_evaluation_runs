module binary_seq_counter (
    input [3:0] n,
    input start,
    output [31:0] result
);
always_comb begin
    reg [31:0] nCr, temp;
    reg [31:0] r;
    reg [31:0] result_int;
    integer n_val;

    n_val = n; // n is 4 bits, but cast to integer

    nCr = 1;
    result_int = 1 << 16; // Initialize to 1.0

    r = 1;
    while (r <= n_val) begin
        temp = nCr * (n_val + 1 - r);
        nCr = temp / r; // Integer division
        result_int = result_int + (nCr * nCr) << 16;
        r = r + 1;
    end

    if (start)
        result = result_int;
    else
        result = 0;
end
endmodule