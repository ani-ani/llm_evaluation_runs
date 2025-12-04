module typo_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input word_end,
  output reg done,
  output reg [15:0] matches [15:0][15:0]
);

reg [7:0] words [0:15][0:7];
reg [2:0] word_lengths [0:15];
reg [3:0] word_count;
reg [2:0] char_count;
reg input_done;
reg [3:0] process_counter;
reg processing;
wire [15:0] matches_next [15:0][15:0];

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    input_done <= 0;
    word_count <= 0;
    char_count <= 0;
    processing <= 0;
    process_counter <= 0;
    for (int i=0; i<16; i=i+1) begin
      word_lengths[i] <= 0;
      for (int j=0; j<8; j=j+1) words[i][j] <= 0;
      for (int j=0; j<16; j=j+1) matches[i][j] <= 0;
    end
  end else begin
    done <= 0;
    if (!input_done) begin
      if (word_end) begin
        if (char_in == 8'b0) begin
          input_done <= 1;
        end else begin
          words[word_count][char_count] <= char_in;
          word_lengths[word_count] <= char_count + 1;
          if (word_count != 15) word_count <= word_count + 1;
          char_count <= 0;
        end
      end else if (char_count < 8) begin
        words[word_count][char_count] <= char_in;
        char_count <= char_count + 1;
      end
    end
    
    if (processing) begin
      if (process_counter == 15) begin
        processing <= 0;
        done <= 1;
        for (int i=0; i<16; i=i+1)
          for (int j=0; j<16; j=j+1)
            matches[i][j] <= matches_next[i][j];
      end else process_counter <= process_counter + 1;
    end else if (input_done && start) begin
      processing <= 1;
      process_counter <= 0;
    end
  end
end

function automatic logic is_similar(
  input [7:0] wordA [0:7],
  input [2:0] lenA,
  input [7:0] wordB [0:7],
  input [2:0] lenB
);
  int len_diff = (lenA > lenB) ? (lenA - lenB) : (lenB - lenA);
  if (len_diff > 1) return 0;
  
  if (len_diff == 0) begin
    int num_diff = 0;
    for (int k=0; k<lenA; k=k+1) num_diff += (wordA[k] != wordB[k]);
    
    logic transpose_ok = 0;
    for (int k=0; k<lenA-1; k=k+1) begin
      if (wordA[k] == wordB[k+1] && wordA[k+1] == wordB[k]) begin
        logic rest_ok = 1;
        for (int m=0; m<lenA; m=m+1)
          if (m !=k && m!=k+1 && wordA[m] != wordB[m]) rest_ok = 0;
        if (rest_ok) transpose_ok = 1;
      end
    end
    return (num_diff == 1) || transpose_ok;
  end else begin
    logic [7:0] longer[0:7], shorter[0:7];
    int len_long = (lenA > lenB) ? lenA : lenB;
    int len_short = (lenA > lenB) ? lenB : lenA;
    
    if (lenA > lenB) begin
      for (int k=0; k<8; k=k+1) begin longer[k] = wordA[k]; shorter[k] = wordB[k]; end
    end else begin
      for (int k=0; k<8; k=k+1) begin longer[k] = wordB[k]; shorter[k] = wordA[k]; end
    end
    
    logic valid_skip;
    for (int skip=0; skip<len_long; skip=skip+1) begin
      valid_skip = 1;
      for (int m=0; m<len_short; m=m+1) begin
        if (m < skip) begin
          if (longer[m] != shorter[m]) valid_skip = 0;
        end else begin
          if (longer[m+1] != shorter[m]) valid_skip = 0;
        end
      end
      if (valid_skip) return 1;
    end
    return 0;
  end
endfunction

generate
for (genvar i=0; i<16; i=i+1) begin
  for (genvar j=0; j<16; j=j+1) begin
    if (i < j) assign matches_next[i][j] = is_similar(words[i], word_lengths[i], words[j], word_lengths[j]) ? 16'b1 : 16'b0;
    else assign matches_next[i][j] = 16'b0;
  end
end
endgenerate

endmodule