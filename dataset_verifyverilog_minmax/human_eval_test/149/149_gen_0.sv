module string_filter_sort #(
  parameter NUM_WORDS = 8,
  parameter WORD_LEN = 8
)(
  input [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] words,
  input [WORD_LEN-1:0] word_length,
  output reg [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] sorted,
  output reg [3:0] valid_count
);

  // Temporary storage for filtered words
  logic [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] temp;
  logic [3:0] tcount;

  integer i, j, k;
  logic [7:0] a_char, b_char;
  int       cmp;

  // Filtering: keep only even-length words and pack to start of temp
  always_comb begin
    // Initialize temp to all spaces to avoid latches
    for (i = 0; i < NUM_WORDS; i++) begin
      for (k = 0; k < WORD_LEN; k++) begin
        temp[i][k] = 8'h20; // space
      end
    end
    tcount = 0;
    for (i = 0; i < NUM_WORDS; i++) begin
      if (word_length[WORD_LEN-1:0] % 2 == 0) begin
        temp[tcount] = words[i];
        tcount = tcount + 1;
      end
    end

    // Initialize output to spaces
    for (i = 0; i < NUM_WORDS; i++) begin
      for (k = 0; k < WORD_LEN; k++) begin
        sorted[i][k] = 8'h20; // space
      end
    end
    valid_count = tcount;

    // Simple insertion sort (ascending ASCII) on the tcount valid words
    for (i = 1; i < tcount; i++) begin
      j = i - 1;
      while (j >= 0) begin
        // Compare two words up to WORD_LEN
        cmp = 0;
        for (k = 0; k < WORD_LEN; k++) begin
          a_char = temp[j][k];
          b_char = temp[j+1][k];
          if (a_char < b_char) begin
            cmp = -1;
            break;
          end else if (a_char > b_char) begin
            cmp = 1;
            break;
          end else begin
            // chars equal; continue to next position
            cmp = 0;
          end
        end
        if (cmp > 0) begin
          // Swap temp[j] and temp[j+1]
          for (k = 0; k < WORD_LEN; k++) begin
            a_char = temp[j][k];
            temp[j][k] = temp[j+1][k];
            temp[j+1][k] = a_char;
          end
          j = j - 1;
        end else begin
          break; // already in order
        end
      end
    end

    // Pack sorted valid words at the start of the output
    for (i = 0; i < tcount; i++) begin
      sorted[i] = temp[i];
    end
  end

endmodule