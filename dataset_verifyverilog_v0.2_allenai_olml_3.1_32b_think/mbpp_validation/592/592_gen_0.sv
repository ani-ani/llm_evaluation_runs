module binomial_sum_module (
    input [3:0] n,
    output [15:0] result
);
always @(*) begin
    int K, N;
    int binom [17][8];
    K = n - 1;
    N = 2 * n;
    for (int i=0; i <= N; i++) begin
        for (int j=0; j <= (i > K ? K : i); j++) begin
            if (j == 0)
                binom[i][j] = 1;
            else
                binom[i][j] = binom[i-1][j-1] + binom[i-1][j];
        end
    end
    result = binom[N][K];
end
endmodule