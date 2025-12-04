module rounded_average(
  input      [7:0] n,
  input      [7:0] m,
  output reg signed [8:0] result
);

  // Internal signals
  reg  [8:0]  count;            // m - n + 1
  reg  [8:0]  diff;             // m - n
  reg  [8:0]  sum_nm;           // n + m
  reg  [17:0] prod;             // (n + m) * count
  reg  [17:0] sum;              // arithmetic series sum
  reg  [8:0]  half_count;       // count >> 1
  reg  [17:0] sum_rounded;      // sum + half_count
  reg  [17:0] rounded_avg_ext;  // (sum + half_count) / count
  reg  [8:0]  rounded_average;  // 9-bit to capture division result

  always @* begin
    if (n > m) begin
      // If n > m, output -1 (9'b1_1111_1111)
      result = -9'sd1;
    end else begin
      // Compute count = m - n + 1
      diff        = {1'b0, m} - {1'b0, n};
      count       = diff + 9'd1;

      // Compute sum = (n + m) * count / 2
      sum_nm      = {1'b0, n} + {1'b0, m};
      prod        = sum_nm * count;           // up to 17 bits, use 18 for safety
      sum         = prod >> 1;                // divide by 2

      // Compute rounded_average = (sum + (count >> 1)) / count
      half_count      = count >> 1;
      sum_rounded     = sum + half_count;
      rounded_avg_ext = sum_rounded / count;  // integer division (truncation)
      rounded_average = rounded_avg_ext[8:0]; // take lower 9 bits

      // Output = {1'b0, rounded_average[7:0]} (zero-extended to 9-bit signed)
      result = {1'b0, rounded_average[7:0]};
    end
  end

endmodule