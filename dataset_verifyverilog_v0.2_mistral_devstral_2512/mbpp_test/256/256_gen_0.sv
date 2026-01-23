module prime_counter(
    input [3:0] n,
    output [3:0] count
);

    // Generate is_prime signals for each k (0-15)
    wire is_prime_0 = 1'b0; // 0 is not prime
    wire is_prime_1 = 1'b0; // 1 is not prime
    wire is_prime_2 = 1'b1; // 2 is prime
    wire is_prime_3 = 1'b1; // 3 is prime
    wire is_prime_4 = 1'b0; // 4 is not prime (divisible by 2)
    wire is_prime_5 = 1'b1; // 5 is prime
    wire is_prime_6 = 1'b0; // 6 is not prime (divisible by 2,3)
    wire is_prime_7 = 1'b1; // 7 is prime
    wire is_prime_8 = 1'b0; // 8 is not prime (divisible by 2)
    wire is_prime_9 = 1'b0; // 9 is not prime (divisible by 3)
    wire is_prime_10 = 1'b0; // 10 is not prime (divisible by 2,5)
    wire is_prime_11 = 1'b1; // 11 is prime
    wire is_prime_12 = 1'b0; // 12 is not prime (divisible by 2,3)
    wire is_prime_13 = 1'b1; // 13 is prime
    wire is_prime_14 = 1'b0; // 14 is not prime (divisible by 2,7)
    wire is_prime_15 = 1'b0; // 15 is not prime (divisible by 3,5)

    // Generate count_contrib signals for each k (0-15)
    wire count_contrib_0 = is_prime_0 && (0 < n);
    wire count_contrib_1 = is_prime_1 && (1 < n);
    wire count_contrib_2 = is_prime_2 && (2 < n);
    wire count_contrib_3 = is_prime_3 && (3 < n);
    wire count_contrib_4 = is_prime_4 && (4 < n);
    wire count_contrib_5 = is_prime_5 && (5 < n);
    wire count_contrib_6 = is_prime_6 && (6 < n);
    wire count_contrib_7 = is_prime_7 && (7 < n);
    wire count_contrib_8 = is_prime_8 && (8 < n);
    wire count_contrib_9 = is_prime_9 && (9 < n);
    wire count_contrib_10 = is_prime_10 && (10 < n);
    wire count_contrib_11 = is_prime_11 && (11 < n);
    wire count_contrib_12 = is_prime_12 && (12 < n);
    wire count_contrib_13 = is_prime_13 && (13 < n);
    wire count_contrib_14 = is_prime_14 && (14 < n);
    wire count_contrib_15 = is_prime_15 && (15 < n);

    // Sum all contributions to get the final count
    assign count = count_contrib_0 + count_contrib_1 + count_contrib_2 + count_contrib_3 +
                   count_contrib_4 + count_contrib_5 + count_contrib_6 + count_contrib_7 +
                   count_contrib_8 + count_contrib_9 + count_contrib_10 + count_contrib_11 +
                   count_contrib_12 + count_contrib_13 + count_contrib_14 + count_contrib_15;

endmodule