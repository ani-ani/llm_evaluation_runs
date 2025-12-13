module bit_range_count(
  input [15:0] n,   // Original number (0 to 65535)
  input [4:0] l,    // Range start (1-32, 1-indexed)
  input [4:0] r,    // Range end (>= l, <=32)
  output reg [4:0] count  // Number of 1s in positions [l:r]
);

  // Internal signals
  integer i;
  reg [5:0] total;           // Max sum is 16, fits in 5 bits; use 6 bits internal for safety
  reg [5:0] ones_i;          // Count for each bit i
  reg [5:0] period;          // 2^(i+1)
  reg [5:0] start_offset;    // 2^i - 1
  reg [5:0] L0, R0;          // Zero-based range [L0:R0]
  reg [5:0] first;           // First position in range matching condition
  reg [5:0] tmp;             // Temporary for division/rounding
  reg [5:0] div_val;         // Quotient for (R0 - first)/period

  always @* begin
    // Convert to 0-based indices for positions
    L0 = (l == 0) ? 6'd0 : (l - 1);
    R0 = (r == 0) ? 6'd0 : (r - 1);

    total = 6'd0;

    for (i = 0; i < 16; i = i + 1) begin
      // Compute period = 2^(i+1) and start_offset = 2^i - 1
      period       = (6'd1 << (i + 1));
      start_offset = (6'd1 << i) - 6'd1;

      // Default ones_i to 0
      ones_i = 6'd0;

      // Only if this bit of n is set and period within considered range
      if (n[i]) begin
        // Find first index >= L0 such that pos % period == start_offset
        if (R0 >= L0) begin
          if (L0 <= start_offset) begin
            // First candidate is start_offset if it's within range
            first = start_offset;
          end else begin
            // Compute the smallest k such that L0 <= start_offset + k*period
            // k = ceil((L0 - start_offset)/period)
            if (L0 > start_offset) begin
              tmp = L0 - start_offset;
              if (tmp == 0)
                div_val = 6'd0;
              else begin
                div_val = tmp / period;
                if ((tmp % period) != 0)
                  div_val = div_val + 6'd1;
              end
              first = start_offset + div_val * period;
            end else begin
              first = start_offset;
            end
          end

          // If first is within [L0, R0], compute count
          if (first <= R0 && first >= L0) begin
            // ones_i = floor((R0 - first) / period) + 1
            tmp = R0 - first;
            div_val = tmp / period;
            ones_i = div_val + 6'd1;
          end else begin
            ones_i = 6'd0;
          end
        end
      end

      total = total + ones_i;
    end

    // Assign lower 5 bits to output (sufficient for max value)
    count = total[4:0];
  end

endmodule