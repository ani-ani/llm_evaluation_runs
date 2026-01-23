module count_up_to (
    input [5:0] n,
    output reg [5:0] primes [0:17],
    output reg [4:0] count
);

    integer i;
    integer prime_idx;

    // All primes strictly less than 64
    // 18 total primes
    wire [5:0] primes_full [0:17];
    assign primes_full = '{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61};

    always @(*) begin
        // Initialize defaults
        count = 0;
        for (i = 0; i < 18; i = i + 1) begin
            primes[i] = 6'b000000;
        end

        prime_idx = 0;
        for (i = 0; i < 18; i = i + 1) begin
            if (primes_full[i] < n) begin
                primes[prime_idx] = primes_full[i];
                prime_idx = prime_idx + 1;
            end
        end
        count = prime_idx;
    end

endmodule
