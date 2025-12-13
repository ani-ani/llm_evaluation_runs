module z_position_checker (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [63:0] char_pack,
  output logic        result,
  output logic        done
);

  // Internal registers
  logic [2:0] idx;                 // 0..7 index
  logic       processing;          // indicates active processing window
  logic       result_reg;
  logic       done_reg;

  // Sliding window characters and word flags
  logic [7:0] c_prev, c_curr, c_next;
  logic       is_word_prev, is_word_curr, is_word_next;

  // Character extraction from packed input (little-endian: byte 0 = lowest bits)
  function automatic logic [7:0] get_char(input logic [63:0] pack, input logic [2:0] i);
    get_char = pack[8*i +: 8];
  endfunction

  // Alphanumeric check: [0-9A-Za-z]
  function automatic logic is_word_char(input logic [7:0] c);
    is_word_char = ((c >= 8'h30 && c <= 8'h39) ||
                    (c >= 8'h41 && c <= 8'h5A) ||
                    (c >= 8'h61 && c <= 8'h7A));
  endfunction

  // Combinational checks for middle 'z'
  logic is_valid_middle_z;

  always_comb begin
    // default
    is_valid_middle_z = 1'b0;

    // Only check when current index is 1..6 where we have both prev and next
    if (idx >= 3'd1 && idx <= 3'd6) begin
      // 'z' middle criteria:
      //  - current is 'z'
      //  - prev and next are word chars
      //  - prev is not a separator -> ensures not first of word
      //  - next is not a separator -> ensures not last of word
      // Because word boundaries are defined solely by word/separator,
      // having word chars on both sides already guarantees mid-word.
      if ((c_curr == 8'h7A) && is_word_prev && is_word_curr && is_word_next)
        is_valid_middle_z = 1'b1;
    end
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx          <= 3'd0;
      processing   <= 1'b0;
      result_reg   <= 1'b0;
      done_reg     <= 1'b0;
      c_prev       <= 8'd0;
      c_curr       <= 8'd0;
      c_next       <= 8'd0;
      is_word_prev <= 1'b0;
      is_word_curr <= 1'b0;
      is_word_next <= 1'b0;
    end else begin
      done_reg <= 1'b0; // default: done asserted for one cycle only

      // Start a new processing sequence on start high when idle
      if (start && !processing) begin
        processing   <= 1'b1;
        idx          <= 3'd0;
        result_reg   <= 1'b0;

        // Initialize the window for idx=0
        c_prev       <= 8'd0;                         // treat as separator
        is_word_prev <= 1'b0;

        c_curr       <= get_char(char_pack, 3'd0);
        is_word_curr <= is_word_char(get_char(char_pack, 3'd0));

        c_next       <= get_char(char_pack, 3'd1);
        is_word_next <= is_word_char(get_char(char_pack, 3'd1));
      end else if (processing) begin
        // During processing: evaluate current position and advance window

        // Check current position for valid middle 'z'
        if (is_valid_middle_z)
          result_reg <= 1'b1;

        // Advance index and sliding window
        if (idx < 3'd7) begin
          idx          <= idx + 3'd1;

          // shift window: next becomes curr, curr becomes prev
          c_prev       <= c_curr;
          is_word_prev <= is_word_curr;

          c_curr       <= c_next;
          is_word_curr <= is_word_next;

          // Load new next character or separator beyond end
          if (idx + 3'd2 <= 3'd7) begin
            c_next       <= get_char(char_pack, idx + 3'd2);
            is_word_next <= is_word_char(get_char(char_pack, idx + 3'd2));
          end else begin
            c_next       <= 8'd0;       // separator beyond string
            is_word_next <= 1'b0;
          end
        end else begin
          // idx == 7 processed in this cycle; finish
          processing <= 1'b0;
          done_reg   <= 1'b1;
        end
      end
    end
  end

  // Outputs
  assign result = result_reg;
  assign done   = done_reg;

endmodule