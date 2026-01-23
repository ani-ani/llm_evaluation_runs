module count_up_to (
  input [5:0] n,
  output [5:0] primes [0:17],
  output [4:0] count
);

  // Define the constant array of all primes < 64
  localparam [5:0] primes_full [0:17] = '{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61};

  // Determine the count of primes less than n
  integer i;
  always_comb begin
    count = 0;
    for (i = 0; i < 18; i = i + 1) begin
      if (primes_full[i] < n) begin
        count = i + 1;
      end
    end
  end

  // Populate the primes output array
  genvar j;
  generate
    for (j = 0; j < 18; j = j + 1) begin : gen_primes
      assign primes[j] = (j < count) ? primes_full[j] : 0;
    end
  endgenerate

endmodule