module media_companies_counter(
  input  [2:0] k, // Minimum consecutive sectors [1-8]
  input  [2:0] c, // Minimum distinct colors [1-8]
  input  [7:0] sectors [0:7], // Team IDs (8-bit each)
  output reg [3:0] company_count // Maximum companies (0-4 possible)
);

  integer start_idx;
  integer end_idx;
  integer i;
  integer j;
  integer next_start;
  integer seg_count;
  integer len;
  integer distinct_cnt;
  reg found;
  reg is_dup;

  always @* begin
    seg_count = 0;
    start_idx = 0;

    // Greedy left-to-right selection of non-overlapping valid segments
    while (start_idx < 8) begin
      found = 1'b0;
      next_start = start_idx + 1; // default advance if no segment found

      // Try all possible end indices from start_idx to 7
      for (end_idx = start_idx; end_idx < 8; end_idx = end_idx + 1) begin
        // Compute segment length
        len = end_idx - start_idx + 1;

        // Only consider if length >= k
        if (!found && (len >= k)) begin
          // Count distinct colors in [start_idx, end_idx]
          distinct_cnt = 0;
          for (i = start_idx; i <= end_idx; i = i + 1) begin
            is_dup = 1'b0;
            for (j = start_idx; j < i; j = j + 1) begin
              if (sectors[i] == sectors[j]) begin
                is_dup = 1'b1;
              end
            end
            if (!is_dup) begin
              distinct_cnt = distinct_cnt + 1;
            end
          end

          // Check distinct count constraint
          if (distinct_cnt >= c) begin
            found = 1'b1;
            seg_count = seg_count + 1;
            // Next search starts after this segment
            next_start = end_idx + 1;
          end
        end
      end

      // Advance start index (either past chosen segment or by one)
      start_idx = next_start;
    end

    // Cap at 4 since maximum non-overlapping segments with N=8, k>=1 is 4
    if (seg_count > 4)
      company_count = 4;
    else
      company_count = seg_count[3:0];
  end

endmodule