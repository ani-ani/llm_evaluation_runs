module prime_selector(input reg signed [15:0] n, x, y, output logic signed [15:0] result);
  const bit [8:0] PRIMES [40] = '{5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181};
  logic prime;

  always_comb begin
    prime = 1'b1;
    if (n < 2)
      prime = 1'b0;
    else if (n == 2)
      prime = 1'b1;
    else if (n[0] == 1'b0)
      prime = 1'b0;
    else if (n <= 181) begin
      case (n)
        3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181: prime = 1'b1;
        default: prime = 1'b0;
      endcase
    end
    else begin
      prime = 1'b1;
      for (int i = 0; i < 40; i++) begin
        if (n % PRIMES[i] == 0)
          prime = 1'b0;
      end
    end
    result = prime ? x : y;
  end
endmodule