module tuple_union_sorted(
  input  [4:0] tuple1 [0:7],
  input  [4:0] tuple2 [0:7],
  output reg [4:0] union_result [0:15],
  output reg [4:0] valid_count
);

  // Internal arrays
  reg [4:0] merged      [0:15];
  reg       is_unique   [0:15];
  reg [4:0] unique_vals [0:15];
  reg [4:0] sorted      [0:15];

  integer i, j;

  always @* begin
    // 1) Merge both tuples into merged[0:15]
    for (i = 0; i < 8; i = i + 1) begin
      merged[i] = tuple1[i];
    end
    for (i = 0; i < 8; i = i + 1) begin
      merged[8 + i] = tuple2[i];
    end

    // 2) Determine uniqueness using parallel comparison
    //    is_unique[i] = 1 if merged[i] is first occurrence of that value
    for (i = 0; i < 16; i = i + 1) begin
      is_unique[i] = 1'b1;
      for (j = 0; j < i; j = j + 1) begin
        if (merged[i] == merged[j]) begin
          is_unique[i] = 1'b0;
        end
      end
    end

    // 3) Collect unique elements into unique_vals (packed left, others zeroed)
    valid_count = 5'd0;
    for (i = 0; i < 16; i = i + 1) begin
      if (is_unique[i]) begin
        unique_vals[valid_count] = merged[i];
        valid_count = valid_count + 1'b1;
      end
    end
    // Zero-fill remaining entries
    for (i = valid_count; i < 16; i = i + 1) begin
      unique_vals[i] = 5'd0;
    end

    // 4) Sort the first valid_count elements using bubble sort (ascending)
    //    Operate on 'sorted' as a working array.
    for (i = 0; i < 16; i = i + 1) begin
      sorted[i] = unique_vals[i];
    end

    if (valid_count > 1) begin
      for (i = 0; i < 15; i = i + 1) begin
        for (j = 0; j < 15 - i; j = j + 1) begin
          if (j + 1 < valid_count) begin
            if (sorted[j] > sorted[j+1]) begin
              // swap
              reg [4:0] tmp;
              tmp         = sorted[j];
              sorted[j]   = sorted[j+1];
              sorted[j+1] = tmp;
            end
          end
        end
      end
    end

    // 5) Shift valid sorted elements to start (already packed), and pad rest with zeros
    for (i = 0; i < valid_count; i = i + 1) begin
      union_result[i] = sorted[i];
    end
    for (i = valid_count; i < 16; i = i + 1) begin
      union_result[i] = 5'd0;
    end
  end

endmodule