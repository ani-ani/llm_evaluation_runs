module best_subsequence(
  input [7:0] k,
  input [63:0] data,
  input [5:0] n,
  output reg [5:0] start_index,
  output reg [5:0] length
);

  integer i, j;
  integer best_start, best_len;
  integer best_sum, best_rate_num, best_rate_den;
  integer current_sum, current_rate_num, current_rate_den;

  always @* begin
    best_start = 0;
    best_len = k;
    best_sum = $countones(data[best_len-1:0]);
    best_rate_num = best_sum;
    best_rate_den = best_len;

    for (i = 0; i < n; i = i + 1) begin
      for (j = i + k; j <= n; j = j + 1) begin
        current_sum = $countones(data[j-1:i]);
        current_rate_num = current_sum;
        current_rate_den = j - i;

        if ((current_rate_num * best_rate_den) > (best_rate_num * current_rate_den) ||
            ((current_rate_num * best_rate_den) == (best_rate_num * current_rate_den) &&
             (i < best_start || (i == best_start && (j - i) > best_len)))) begin
          best_start = i;
          best_len = j - i;
          best_sum = current_sum;
          best_rate_num = current_rate_num;
          best_rate_den = current_rate_den;
        end
      end
    end

    start_index = best_start;
    length = best_len;
  end

endmodule