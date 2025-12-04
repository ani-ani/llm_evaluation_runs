module string_filter_sort #(
  parameter NUM_WORDS = 8,
  parameter WORD_LEN = 8
) (
  input [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] words,
  input [WORD_LEN-1:0] word_length,
  output reg [NUM_WORDS-1:0][WORD_LEN-1:0][7:0] sorted,
  output reg [3:0] valid_count
);

  typedef logic [WORD_LEN-1:0][7:0] word_t;
  
  function automatic logic word_gt(
    input word_t a,
    input word_t b
  );
    logic gt;
    gt = 1'b0;
    for (int i = 0; i < WORD_LEN; i++) begin
      if (a[i] > b[i]) begin
        gt = 1'b1;
        break;
      end else if (a[i] < b[i]) begin
        break;
      end
    end
    return gt;
  endfunction

  always_comb begin
    word_t [NUM_WORDS-1:0] temp;
    
    if (word_length[0] == 0) begin
      valid_count = NUM_WORDS;
      temp = words;
      
      for (int pass = 0; pass < NUM_WORDS-1; pass++) begin
        for (int i = 0; i < NUM_WORDS-1-pass; i++) begin
          if (word_gt(temp[i], temp[i+1])) begin
            word_t swap_word = temp[i];
            temp[i] = temp[i+1];
            temp[i+1] = swap_word;
          end
        end
      end
      
      sorted = temp;
    
    end else begin
      valid_count = 0;
      sorted = '0;
    end
  end

endmodule