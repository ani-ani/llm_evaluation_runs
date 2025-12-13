module coprime_set_counter(
  input  [3:0]  N,       // Input N (max 15)
  output [29:0] count    // Result modulo 1000000000
);

  // Constants
  localparam int MOD = 1000000000;

  // Maximum pairs for N<=15 is C(15,2) = 105
  localparam int MAX_PAIRS = 105;

  // Storage for pair endpoints
  reg [3:0] pair_a [0:MAX_PAIRS-1];
  reg [3:0] pair_b [0:MAX_PAIRS-1];

  // Indexing and counters
  integer i, j, p, x;
  integer pair_count;

  // Main computation (purely combinational)
  reg [29:0] result;

  // GCD function for 4-bit operands
  function automatic [3:0] gcd4(input [3:0] a_in, input [3:0] b_in);
    integer a, b, t;
    begin
      a = a_in;
      b = b_in;
      while (b != 0) begin
        t = a % b;
        a = b;
        b = t;
      end
      gcd4 = a[3:0];
    end
  endfunction

  always @* begin
    // 1) Generate all coprime pairs (i,j), 1 <= i < j <= N
    pair_count = 0;
    for (i = 1; i <= N; i = i + 1) begin
      for (j = i + 1; j <= N; j = j + 1) begin
        if (gcd4(i[3:0], j[3:0]) == 4'd1) begin
          pair_a[pair_count] = i[3:0];
          pair_b[pair_count] = j[3:0];
          pair_count = pair_count + 1;
        end
      end
    end

    // 2-4) Enumerate all non-empty subsets of these pairs and
    //       count those with NO partition x in {2,...,N}
    result = 30'd0;

    if (pair_count == 0) begin
      // No pairs -> no non-empty subsets
      result = 30'd0;
    end else begin
      // Use an integer as subset mask: 1..(2^pair_count - 1)
      // Note: For synthesis with large pair_count this is huge;
      // here we follow the problem spec combinationally.
      integer subset;
      integer max_subset;
      max_subset = (1 << pair_count) - 1;

      for (subset = 1; subset <= max_subset; subset = subset + 1) begin
        // Check existence of a partition x such that
        // every selected pair is fully on one side of x
        // (both < x) or (both >= x).
        bit has_partition;
        has_partition = 1'b0;

        for (x = 2; x <= N; x = x + 1) begin
          bit ok;
          ok = 1'b1;

          for (p = 0; p < pair_count; p = p + 1) begin
            if (subset[p]) begin
              // Selected pair (a,b)
              bit left_a, left_b;
              left_a = (pair_a[p] < x[3:0]);
              left_b = (pair_b[p] < x[3:0]);
              // Check if pair is split by x
              if (left_a ^ left_b) begin
                ok = 1'b0;
                // Can break this loop for efficiency
                p = pair_count; // force exit
              end
            end
          end

          if (ok) begin
            has_partition = 1'b1;
            x = N + 1; // break outer x-loop
          end
        end

        // Count subsets with NO partition
        if (!has_partition) begin
          result = result + 1;
          if (result >= MOD[29:0])
            result = result - MOD[29:0];
        end
      end
    end
  end

  assign count = result;

endmodule