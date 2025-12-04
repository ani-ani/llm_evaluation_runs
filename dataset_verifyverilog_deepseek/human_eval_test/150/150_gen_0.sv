module prime_selector (input signed [15:0] n, x, y, output signed [15:0] result);

  reg is_prime;
  localparam int PRIMES[41] = '{3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181};

  always_comb begin
    if (n < 16'sd2 || n[15]) begin
      is_prime = 1'b0;
    end else if (n == 16'sd2 || n == 16'sd3) begin
      is_prime = 1'b1;
    end else if (n[0] == 1'b0) begin
      is_prime = 1'b0;
    end else begin
      is_prime = 1'b1;
      for (int i = 0; i < 41; i++) begin
        if ((unsigned'(n) % PRIMES[i]) == 0 && n != PRIMES[i]) begin
          is_prime = 1'b0;
        end
      end
    end
  end

  assign result = is_prime ? x : y;

endmodule