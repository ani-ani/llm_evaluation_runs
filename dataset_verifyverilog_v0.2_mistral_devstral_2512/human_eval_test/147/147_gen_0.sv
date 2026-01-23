module max_triples (
  input [3:0] n,
  output [15:0] count
);

  // Pre-computed values of a[i] for i=1 to 8
  localparam [5:0] a [1:8] = '{1, 3, 7, 13, 21, 31, 43, 57};

  // Initialize count to 0
  wire [15:0] count = 0;

  // Generate all possible triplets (i, j, k) where i < j < k
  genvar i, j, k;
  for (i = 1; i <= 8; i = i + 1) begin : gen_i
    for (j = i + 1; j <= 8; j = j + 1) begin : gen_j
      for (k = j + 1; k <= 8; k = k + 1) begin : gen_k
        // Check if the triplet is valid and within the given n
        wire valid_triplet = (i <= n) && (j <= n) && (k <= n) && ((a[i] + a[j] + a[k]) % 3 == 0);
        // Add 1 to count if the triplet is valid
        assign count = count + valid_triplet;
      end
    end
  end

endmodule