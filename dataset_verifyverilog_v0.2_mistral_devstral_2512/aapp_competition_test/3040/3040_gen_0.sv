module longest_repeated_substring (
  input [127:0] char_array,
  input [3:0] valid_len,
  output [127:0] result_string,
  output [3:0] result_len
);

  reg [7:0] substring1 [0:15];
  reg [7:0] substring2 [0:15];
  reg [7:0] candidate [0:15];
  reg [3:0] candidate_len;
  reg [3:0] max_len;
  reg [3:0] i, j, k, l;
  reg match_found;
  reg [3:0] result_len_reg;
  reg [127:0] result_string_reg;

  // Initialize outputs
  assign result_string = result_string_reg;
  assign result_len = result_len_reg;

  // Extract characters from char_array
  always @* begin
    for (i = 0; i < 16; i = i + 1) begin
      substring1[i] = char_array[(i*8)+7 : i*8];
      substring2[i] = char_array[(i*8)+7 : i*8];
    end
  end

  // Main logic to find longest repeated substring
  always @* begin
    result_len_reg = 4'b0;
    result_string_reg = 128'b0;
    max_len = 4'b0;

    // Check all possible substring lengths from 15 down to 1
    for (i = 15; i >= 1; i = i - 1) begin
      if (i <= valid_len - 1) begin
        // Check all possible starting positions for substring of length i
        for (j = 0; j <= valid_len - i - 1; j = j + 1) begin
          // Compare with all subsequent substrings
          for (k = j + 1; k <= valid_len - i; k = k + 1) begin
            match_found = 1'b1;
            // Compare characters in the substring
            for (l = 0; l < i; l = l + 1) begin
              if (substring1[j + l] != substring2[k + l]) begin
                match_found = 1'b0;
              end
            end

            // If match found, check if it's the longest or lexicographically first
            if (match_found) begin
              if (i > max_len) begin
                max_len = i;
                result_len_reg = i;
                // Store the substring
                for (l = 0; l < i; l = l + 1) begin
                  candidate[l] = substring1[j + l];
                end
                // Pack the result
                result_string_reg = 128'b0;
                for (l = 0; l < i; l = l + 1) begin
                  result_string_reg[(l*8)+7 : l*8] = candidate[l];
                end
              end else if (i == max_len) begin
                // Lexicographical comparison
                reg [3:0] lex_result = 4'b0;
                for (l = 0; l < i; l = l + 1) begin
                  if (substring1[j + l] < candidate[l]) begin
                    lex_result = 4'b1;
                    break;
                  end else if (substring1[j + l] > candidate[l]) begin
                    lex_result = 4'b0;
                    break;
                  end
                end
                if (lex_result) begin
                  // Update candidate
                  for (l = 0; l < i; l = l + 1) begin
                    candidate[l] = substring1[j + l];
                  end
                  // Pack the result
                  result_string_reg = 128'b0;
                  for (l = 0; l < i; l = l + 1) begin
                    result_string_reg[(l*8)+7 : l*8] = candidate[l];
                  end
                end
              end
            end
          end
        end
      end
    end
  end

endmodule