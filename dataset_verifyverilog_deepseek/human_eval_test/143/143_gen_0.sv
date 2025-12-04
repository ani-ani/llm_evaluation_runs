module prime_length_filter (
  input clk,
  input rst_n,
  input start,
  input [2:0] word_count,
  input [7:0][7:0] words [0:7],
  output reg [63:0] filtered_sentence,
  output reg [2:0] word_lengths [0:7],
  output reg done
);

  reg [3:0] counter; // counter for 0-8 cycles (inclusive)
  reg processing;
  reg [3:0] fill_ptr; // tracks bytes filled (0-8)
  reg [2:0] valid_ptr; // tracks valid word entries (0-7)
  
  // Prime check function
  function automatic logic is_prime(input [2:0] len);
    return (len == 2) || (len == 3) || (len == 5) || (len == 7);
  endfunction
  
  // Count non-zero bytes in word
  function automatic [2:0] calc_len(input [7:0][7:0] word);
    calc_len = 0;
    for (int i=0; i<8; i++) begin
      if (word[i] != 0) calc_len++;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      filtered_sentence <= 64'b0;
      for (int i=0; i<8; i++) word_lengths[i] <= 3'b0;
      done <= 1'b0;
      counter <= 4'b0;
      processing <= 1'b0;
      fill_ptr <= 4'b0;
      valid_ptr <= 3'b0;
    end else begin
      done <= 1'b0; // default
      if (processing) begin
        // Process current word (counter-1) if in range
        if (counter >= 1 && counter <= 8) begin
          if (counter-1 < word_count) begin
            automatic bit [2:0] len = calc_len(words[counter-1]);
            if (is_prime(len) && (fill_ptr + len) <= 8) begin
              filtered_sentence[fill_ptr*8 +: len*8] <= {words[counter-1][0],words[counter-1][1],words[counter-1][2],words[counter-1][3],words[counter-1][4],words[counter-1][5],words[counter-1][6],words[counter-1][7]} >> (8*(8-len));
              word_lengths[valid_ptr] <= len;
              valid_ptr <= valid_ptr + 1;
              fill_ptr <= fill_ptr + len;
            end
          end
        end
      
        if (counter == 8) begin
          processing <= 1'b0;
          done <= 1'b1;
          counter <= 4'b0;
        end else begin
          counter <= counter + 1;
        end
      end else begin
        if (start) begin // start processing
          processing <= 1'b1;
          counter <= 4'b1; // start counting from 1 (next clk)
          filtered_sentence <= 64'b0;
          for (int i=0; i<8; i++) word_lengths[i] <= 3'b0;
          valid_ptr <= 3'b0;
          fill_ptr <= 4'b0;
        end
      end
    end
  end

endmodule