module tuple_union_sorted(
  input [4:0] tuple1 [0:7],
  input [4:0] tuple2 [0:7],
  output reg [4:0] union_result [0:15],
  output reg [4:0] valid_count
);

  // Local variables
  logic [4:0] merged [0:15];
  logic [4:0] unique_vals [0:15];
  integer i, j, k;

  always_comb begin
    // 1) Merge both tuples into a 16-element array
    for (i = 0; i < 8; i = i + 1) begin
      merged[i] = tuple1[i];
      merged[i + 8] = tuple2[i];
    end

    // 2) Remove duplicates using parallel comparison (mark and filter)
    for (i = 0; i < 16; i = i + 1) begin
      unique_vals[i] = merged[i];
      for (j = 0; j < i; j = j + 1) begin
        if (merged[i] == merged[j]) begin
          unique_vals[i] = 5'b11111; // mark as duplicate (sentinel)
        end
      end
    end

    // Compact marked duplicates by shifting valid elements to the start
    k = 0;
    for (i = 0; i < 16; i = i + 1) begin
      if (unique_vals[i] != 5'b11111) begin
        merged[k] = unique_vals[i];
        k = k + 1;
      end
    end
    valid_count = k;

    // Initialize full output to 0
    for (i = 0; i < 16; i = i + 1) begin
      union_result[i] = 5'b0;
    end

    // Write valid elements to output (already shifted to start)
    for (i = 0; i < valid_count; i = i + 1) begin
      union_result[i] = merged[i];
    end

    // 3) Sort remaining elements using bubble sort (ascending)
    for (i = 0; i < valid_count; i = i + 1) begin
      for (j = 0; j < (valid_count - i - 1); j = j + 1) begin
        if (union_result[j] > union_result[j + 1]) begin
          k = union_result[j];
          union_result[j] = union_result[j + 1];
          union_result[j + 1] = k;
        end
      end
    end
  end

endmodule