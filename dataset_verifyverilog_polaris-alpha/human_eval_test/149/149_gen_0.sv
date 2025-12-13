module string_filter_sort #(
  parameter int NUM_WORDS = 8,
  parameter int WORD_LEN  = 8
)(
  input      [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] words,
  input      [WORD_LEN-1:0]                     word_length,
  output reg [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] sorted,
  output reg [3:0]                              valid_count
);

  // Internal variables
  integer i, j, k;
  integer cmp;
  reg [3:0] n_valid;
  reg [3:0] i_min;

  // Temporary storage for valid (filtered) words
  reg [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] valid_words;

  // Combinational logic block
  always @* begin
    // Default assignments
    n_valid = 0;

    // Clear valid_words and sorted
    for (i = 0; i < NUM_WORDS; i = i + 1) begin
      for (j = 0; j < WORD_LEN; j = j + 1) begin
        valid_words[i][j] = 8'h20; // space
        sorted[i][j]      = 8'h20; // space
      end
    end

    // Filtering: keep only even-length words based on common word_length
    if (word_length[0] == 1'b0) begin
      // All words are considered valid since they share common even length
      n_valid = NUM_WORDS[3:0];

      // Copy all words into valid_words
      for (i = 0; i < NUM_WORDS; i = i + 1) begin
        for (j = 0; j < WORD_LEN; j = j + 1) begin
          valid_words[i][j] = words[i][j];
        end
      end
    end
    else begin
      // Odd length: no valid words
      n_valid = 4'd0;
    end

    // Sorting: selection sort on valid_words[0 : n_valid-1]
    if (n_valid > 1) begin
      for (i = 0; i < NUM_WORDS; i = i + 1) begin
        for (j = 0; j < WORD_LEN; j = j + 1) begin
          sorted[i][j] = 8'h20; // default spaces
        end
      end

      for (i = 0; i < n_valid; i = i + 1) begin
        i_min = i[3:0];
        for (j = i + 1; j < n_valid; j = j + 1) begin
          // Lexicographical compare valid_words[j] vs valid_words[i_min]
          cmp = 0;
          for (k = 0; k < WORD_LEN; k = k + 1) begin
            if (cmp == 0) begin
              if (valid_words[j][k] < valid_words[i_min][k]) begin
                cmp = -1;
              end
              else if (valid_words[j][k] > valid_words[i_min][k]) begin
                cmp = 1;
              end
            end
          end
          if (cmp < 0)
            i_min = j[3:0];
        end

        // Place the selected minimum word at sorted[i]
        for (k = 0; k < WORD_LEN; k = k + 1) begin
          sorted[i][k] = valid_words[i_min][k];
        end

        // Mark used entry as max value (0x7F) to avoid re-selection
        for (k = 0; k < WORD_LEN; k = k + 1) begin
          valid_words[i_min][k] = 8'h7F;
        end
      end
    end
    else if (n_valid == 1) begin
      // Only one valid word, directly copy
      for (k = 0; k < WORD_LEN; k = k + 1) begin
        sorted[0][k] = valid_words[0][k];
      end
    end

    // Pack remaining entries (if any) with spaces already done above

    // Output valid_count
    valid_count = n_valid;
  end

endmodule