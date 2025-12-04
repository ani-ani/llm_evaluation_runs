module centered_hexagonal (
    input reg [3:0] n,
    output reg [9:0] hex_num
);
    // Compute the centered hexagonal number: 3*n*(n-1) + 1
    always_comb begin
        hex_num = 3 * n * (n-1) + 1;
    end
endmodule