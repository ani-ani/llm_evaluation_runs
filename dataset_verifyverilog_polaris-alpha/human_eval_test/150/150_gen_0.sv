module prime_selector(
  input  signed [15:0] n,
  input  signed [15:0] x,
  input  signed [15:0] y,
  output signed [15:0] result
);

  // Internal signals
  wire is_prime;
  wire [15:0] n_abs;
  wire [15:0] n_u;         // Unsigned magnitude of n for prime checking
  reg  prime_reg;

  // Treat negative n as non-prime: use absolute value for range logic, but explicit check below
  assign n_abs = n[15] ? (~n + 16'd1) : n;
  assign n_u   = n_abs;

  // Combinational prime check
  always @* begin
    // Default: not prime
    prime_reg = 1'b0;

    // Negative or < 2 -> not prime
    if (!n[15]) begin
      if (n_u < 16'd2) begin
        prime_reg = 1'b0;
      end else if (n_u == 16'd2 || n_u == 16'd3) begin
        prime_reg = 1'b1;
      end else if ((n_u[0] == 1'b0)) begin
        // Even numbers greater than 2 are not prime
        prime_reg = 1'b0;
      end else begin
        // Check odd divisors from 3 upwards until d*d > n_u
        // Upper bound sqrt(65535) < 256, so limit divisor to 255
        integer d;
        reg is_divisor_found;
        is_divisor_found = 1'b0;

        for (d = 3; d <= 255; d = d + 2) begin
          if (!is_divisor_found) begin
            if ((d * d) > n_u) begin
              // No divisor found up to sqrt(n_u), n is prime
              // Mark prime and stop further checks
              prime_reg = 1'b1;
              is_divisor_found = 1'b1; // Use as loop stop flag
            end else if ((n_u % d) == 0) begin
              // Found a divisor, not prime
              prime_reg = 1'b0;
              is_divisor_found = 1'b1;
            end
          end
        end

        // If loop completes without is_divisor_found being set and without d*d > n_u,
        // it means n_u is larger than (255)^2 and we did not find a divisor in range.
        // For 16-bit inputs this cannot happen (since max is 65535),
        // but ensure prime_reg is set correctly if still undetermined.
        if (!is_divisor_found) begin
          // At this point, d wrapped past 255 without (d*d > n_u) or divisor; for safety, treat as prime.
          prime_reg = 1'b1;
        end
      end
    end else begin
      // Negative numbers are not prime
      prime_reg = 1'b0;
    end
  end

  assign is_prime = prime_reg;

  // Output selection based on primality
  assign result = is_prime ? x : y;

endmodule