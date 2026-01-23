module prime_length (
    input [127:0] string_data,
    input [3:0] string_length,
    output is_prime
);

    // Combinational logic to check if string_length is a prime number
    // Primes in range [0, 15]: 2, 3, 5, 7, 11, 13
    // 0 and 1 are not prime.

    assign is_prime = (string_length == 4'd2) ||
                      (string_length == 4'd3) ||
                      (string_length == 4'd5) ||
                      (string_length == 4'd7) ||
                      (string_length == 4'd11) ||
                      (string_length == 4'd13);

endmodule