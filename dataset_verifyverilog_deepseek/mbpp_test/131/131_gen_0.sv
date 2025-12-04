module reverse_vowels (
  input [7:0] string_length,
  input [7:0][7:0] chars_in,
  output logic [7:0][7:0] chars_out
);

  function automatic logic is_vowel_char(input [7:0] c);
    return ((c == "a") || (c == "e") || (c == "i") || (c == "o") || (c == "u") ||
            (c == "A") || (c == "E") || (c == "I") || (c == "O") || (c == "U"));
  endfunction

  always_comb begin
    logic [7:0] vowel_count;
    logic [7:0] is_vowel [0:7];
    logic [2:0] count_before_j [0:7];
    logic [7:0] vowel_list [0:7];
    
    // Calculate is_vowel flags
    for (int j = 0; j < 8; j++) begin
      is_vowel[j] = (j < string_length) ? is_vowel_char(chars_in[j]) : 1'b0;
    end
    
    // Calculate vowel_count
    vowel_count = 0;
    for (int j = 0; j < 8; j++) begin
      vowel_count += is_vowel[j];
    end
    
    // Calculate count_before_j
    count_before_j[0] = 0;
    for (int j = 1; j < 8; j++) begin
      count_before_j[j] = count_before_j[j-1] + is_vowel[j-1];
    end
    
    // Populate vowel_list
    for (int j = 0; j < 8; j++) begin
      vowel_list[j] = 8'b0;
    end
    for (int j = 0; j < 8; j++) begin
      if (is_vowel[j]) begin
        vowel_list[count_before_j[j]] = chars_in[j];
      end
    end
    
    // Generate output
    for (int k = 0; k < 8; k++) begin
      if (k >= string_length) begin
        chars_out[k] = chars_in[k];
      end else if (!is_vowel[k]) begin
        chars_out[k] = chars_in[k];
      end else begin
        automatic logic [2:0] rev_idx = vowel_count - 1 - count_before_j[k];
        chars_out[k] = vowel_list[rev_idx];
      end
    end
  end

endmodule