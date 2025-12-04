module bit_range_count(
  input [15:0] n,
  input [4:0] l,
  input [4:0] r,
  output reg [4:0] count
);

integer a, b;
integer total;
integer period, residue, first_occurrence, count_i;

always_comb begin
  a = l - 1;   // Convert to 0-indexed
  b = r - 1;
  total = 0;

  for (int i = 0; i < 16; i++) begin
    period = 1 << (i + 1);    // 2^(i+1)
    residue = (1 << i) - 1;   // 2^i - 1

    if (residue < a) 
      first_occurrence = residue + ((a - residue + period - 1) / period) * period;
    else
      first_occurrence = residue;

    if (first_occurrence > b) 
      count_i = 0;
    else
      count_i = (b - first_occurrence) / period + 1;

    if (n[i])
      total = total + count_i;
  end

  if (total > 31)
    count = 5'd31;
  else
    count = total[4:0];
end

endmodule