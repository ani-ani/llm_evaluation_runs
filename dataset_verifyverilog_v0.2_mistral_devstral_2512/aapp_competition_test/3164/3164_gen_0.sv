module find_max_even_pairs (
  input [7:0] n_i,
  input [7:0][7:0] arr_i,
  output reg [7:0] max_length
);

  integer i, j, k, m;
  integer freq [0:255];
  integer current_length;
  integer valid;

  always @* begin
    max_length = 8'd0;

    if (n_i == 0) begin
      max_length = 8'd0;
    end else begin
      for (i = 0; i < n_i; i = i + 1) begin
        for (j = i; j < n_i; j = j + 1) begin
          // Initialize frequency array
          for (k = 0; k <= 255; k = k + 1) begin
            freq[k] = 0;
          end

          // Count frequencies in sub-array arr[i..j]
          for (m = i; m <= j; m = m + 1) begin
            freq[arr_i[m]] = freq[arr_i[m]] + 1;
          end

          // Check if all frequencies are exactly 2
          valid = 1;
          for (k = 0; k <= 255; k = k + 1) begin
            if (freq[k] != 0 && freq[k] != 2) begin
              valid = 0;
            end
          end

          // Update max_length if valid
          if (valid) begin
            current_length = j - i + 1;
            if (current_length > max_length) begin
              max_length = current_length;
            end
          end
        end
      end
    end
  end

endmodule