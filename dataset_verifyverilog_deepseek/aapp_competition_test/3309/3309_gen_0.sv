module media_companies_counter(
  input [2:0] k,
  input [2:0] c,
  input [7:0] sectors [0:7],
  output reg [3:0] company_count
);
  function automatic bit is_valid_segment(input [2:0] start, input [2:0] length);
    if (start + length > 8) return 0;
    begin
      bit [7:0] found_colors = 0;
      int distinct_count = 0;
      for (int i = 0; i < length; i = i + 1) begin
        if (found_colors[sectors[start+i]] == 0) begin
          found_colors[sectors[start+i]] = 1;
          distinct_count = distinct_count + 1;
        end
      end
      return (length >= k) && (distinct_count >= c);
    end
  endfunction
  always_comb begin
    company_count = 0;
    int pos = 0;
    int step;
    for (step = 0; step < 4; step = step + 1) begin
      if (pos >= 8) break;
      int found = 0;
      int best_l = 0;
      for (int l = k; l <= 8 - pos; l = l + 1) begin
        if (l < k) continue;
        if (is_valid_segment(pos, l)) begin
          found = 1;
          best_l = l;
          break;
        end
      end
      if (found) begin
        company_count = company_count + (pos + best_l <= 8);
        pos = pos + best_l;
      end else begin
        pos = pos + 1;
      end
    end
  end
endmodule