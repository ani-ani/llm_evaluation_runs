module drink_partitions (
  input [7:0] bad_pairs_ingredient_a,
  input [7:0] bad_pairs_ingredient_b,
  input [2:0] num_bad_pairs,
  output reg [15:0] num_partitions
);

  reg [7:0][7:0] bad_pair_matrix;
  integer i, j, k, m;
  reg [6:0] mask;
  reg [15:0] count;
  reg [7:0] segment_start, segment_end;
  reg valid_segment;
  reg [7:0] ingredient_a, ingredient_b;

  // Initialize bad pair matrix to all zeros
  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      bad_pair_matrix[i][j] = 1'b0;
    end
  end

  // Build the bad pair matrix (symmetric)
  for (k = 0; k < num_bad_pairs; k = k + 1) begin
    ingredient_a = bad_pairs_ingredient_a[k] - 1;
    ingredient_b = bad_pairs_ingredient_b[k] - 1;
    bad_pair_matrix[ingredient_a][ingredient_b] = 1'b1;
    bad_pair_matrix[ingredient_b][ingredient_a] = 1'b1;
  end

  // Initialize count to zero
  count = 16'd0;

  // Iterate through all possible masks (0 to 127)
  for (mask = 0; mask < 128; mask = mask + 1) begin
    // Check all segments in the current partition
    segment_start = 0;
    valid_segment = 1'b1;

    // Iterate through each segment
    for (m = 0; m < 7; m = m + 1) begin
      if (mask[m]) begin
        segment_end = m;
        // Check all pairs in the current segment
        for (i = segment_start; i <= segment_end; i = i + 1) begin
          for (j = i + 1; j <= segment_end; j = j + 1) begin
            if (bad_pair_matrix[i][j]) begin
              valid_segment = 1'b0;
            end
          end
        end
        segment_start = m + 1;
      end
    end

    // Check the last segment
    segment_end = 7;
    for (i = segment_start; i <= segment_end; i = i + 1) begin
      for (j = i + 1; j <= segment_end; j = j + 1) begin
        if (bad_pair_matrix[i][j]) begin
          valid_segment = 1'b0;
        end
      end
    end

    // If all segments are valid, increment count
    if (valid_segment) begin
      count = count + 1;
    end
  end

  // Output result modulo 1024
  num_partitions = count % 1024;

endmodule