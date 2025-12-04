module string_filter_palindrome (
  input clk,
  input rst_n,
  input start,
  input [7:0] s_chars [7:0],
  input [7:0] c_chars [7:0],
  input [2:0] s_len,
  input [2:0] c_len,
  output reg [7:0] result_chars [7:0],
  output reg [2:0] result_len,
  output reg is_palindrome,
  output reg done
);
  reg [3:0] counter;
  reg processing;
  reg [7:0] internal_chars [7:0];
  reg [2:0] internal_len;
  reg internal_pal;
  
  logic [7:0] comb_filtered_chars [7:0];
  logic [2:0] comb_filtered_len;
  
  always_comb begin
    // Filtering logic
    comb_filtered_len = 0;
    comb_filtered_chars = '{default:0};
    if (start) begin
      int idx = 0;
      for (int i = 0; i < 8; i++) begin
        if (i < s_len) begin
          logic keep;
          keep = 1'b1;
          for (int j = 0; j < 8; j++) begin
            if (j < c_len && s_chars[i] == c_chars[j]) begin
              keep = 1'b0;
              break;
            end
          end
          if (keep) begin
            comb_filtered_chars[idx] = s_chars[i];
            idx++;
          end
        end
      end
      comb_filtered_len = idx;
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      result_chars <= '{default:0};
      result_len <= 0;
      is_palindrome <= 0;
      done <= 0;
      counter <= 0;
      processing <= 0;
      internal_pal <= 0;
      internal_len <= 0;
      internal_chars <= '{default:0};
    end else begin
      if (processing) begin
        counter <= counter + 1;
        if (counter >= 1 && counter <= 8) begin
          int k = counter - 1;
          if (k < (internal_len >> 1)) begin
            if (internal_chars[k] != internal_chars[internal_len - 1 - k]) begin
              internal_pal <= 1'b0;
            end
          end
        end
        if (counter == 9) begin
          done <= 1'b1;
          result_chars <= internal_chars;
          result_len <= internal_len;
          is_palindrome <= internal_pal || (internal_len == 0);
          processing <= 1'b0;
          counter <= 0;
        end else begin
          done <= 1'b0;
        end
      end else if (start) begin
        processing <= 1'b1;
        internal_chars <= comb_filtered_chars;
        internal_len <= comb_filtered_len;
        internal_pal <= (comb_filtered_len == 0) ? 1 : 1;
        counter <= 1;
        done <= 1'b0;
      end else begin
        done <= 1'b0;
      end
    end
  end
endmodule