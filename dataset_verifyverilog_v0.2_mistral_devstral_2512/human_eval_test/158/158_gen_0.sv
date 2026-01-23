module find_max_words (
  input clk,
  input rst_n,
  input start,
  input [7:0] word0,
  input [7:0] word1,
  input [7:0] word2,
  input [7:0] word3,
  input [7:0] word4,
  input [7:0] word5,
  input [7:0] word6,
  input [7:0] word7,
  output reg [7:0] result_word,
  output reg done
);

  // State definitions
  localparam [4:0] IDLE = 5'd0;
  localparam [4:0] UNIQUE_COUNT_START = 5'd1;
  localparam [4:0] CHAR_CHECK_LOOP = 5'd2;
  localparam [4:0] COUNT_COMPLETE = 5'd10;
  localparam [4:0] NEXT_WORD = 5'd11;
  localparam [4:0] DONE = 5'd12;

  // State machine
  reg [4:0] state = IDLE;
  reg [2:0] word_idx = 3'd0;
  reg [2:0] char_idx = 3'd0;
  reg [2:0] prev_char_idx = 3'd0;
  reg [25:0] unique_chars = 26'd0;
  reg [5:0] unique_count = 6'd0;
  reg [5:0] max_unique = 6'd0;
  reg [2:0] best_word_idx = 3'd0;
  reg [63:0] current_word = 64'd0;
  reg [63:0] words [0:7];
  reg [7:0] char_byte = 8'd0;
  reg [7:0] prev_char_byte = 8'd0;
  reg is_unique = 1'd0;
  reg [5:0] cycle_count = 6'd0;

  // Load words into array
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      words[0] <= {word0[7:0], word0[15:8], word0[23:16], word0[31:24], word0[39:32], word0[47:40], word0[55:48], word0[63:56]};
      words[1] <= {word1[7:0], word1[15:8], word1[23:16], word1[31:24], word1[39:32], word1[47:40], word1[55:48], word1[63:56]};
      words[2] <= {word2[7:0], word2[15:8], word2[23:16], word2[31:24], word2[39:32], word2[47:40], word2[55:48], word2[63:56]};
      words[3] <= {word3[7:0], word3[15:8], word3[23:16], word3[31:24], word3[39:32], word3[47:40], word3[55:48], word3[63:56]};
      words[4] <= {word4[7:0], word4[15:8], word4[23:16], word4[31:24], word4[39:32], word4[47:40], word4[55:48], word4[63:56]};
      words[5] <= {word5[7:0], word5[15:8], word5[23:16], word5[31:24], word5[39:32], word5[47:40], word5[55:48], word5[63:56]};
      words[6] <= {word6[7:0], word6[15:8], word6[23:16], word6[31:24], word6[39:32], word6[47:40], word6[55:48], word6[63:56]};
      words[7] <= {word7[7:0], word7[15:8], word7[23:16], word7[31:24], word7[39:32], word7[47:40], word7[55:48], word7[63:56]};
    end
  end

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      word_idx <= 3'd0;
      char_idx <= 3'd0;
      prev_char_idx <= 3'd0;
      unique_chars <= 26'd0;
      unique_count <= 6'd0;
      max_unique <= 6'd0;
      best_word_idx <= 3'd0;
      current_word <= 64'd0;
      char_byte <= 8'd0;
      prev_char_byte <= 8'd0;
      is_unique <= 1'd0;
      cycle_count <= 6'd0;
      result_word <= 8'd0;
      done <= 1'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= UNIQUE_COUNT_START;
            done <= 1'd0;
          end
        end
        UNIQUE_COUNT_START: begin
          current_word <= words[word_idx];
          unique_chars <= 26'd0;
          unique_count <= 6'd0;
          char_idx <= 3'd0;
          prev_char_idx <= 3'd0;
          state <= CHAR_CHECK_LOOP;
          cycle_count <= 6'd0;
        end
        CHAR_CHECK_LOOP: begin
          if (cycle_count < 6'd8) begin
            cycle_count <= cycle_count + 6'd1;
            if (cycle_count == 6'd0) begin
              char_byte <= current_word[(char_idx+1)*8-1:char_idx*8];
              if (char_byte != 8'd0) begin
                is_unique <= 1'd1;
                for (int i = 0; i < char_idx; i = i + 1) begin
                  prev_char_byte <= current_word[(i+1)*8-1:i*8];
                  if (char_byte == prev_char_byte) begin
                    is_unique <= 1'd0;
                  end
                end
                if (is_unique && char_byte >= 8'h61 && char_byte <= 8'h7A) begin
                  unique_chars[char_byte - 8'h61] <= 1'd1;
                end
              end
            end
            if (cycle_count == 6'd7) begin
              char_idx <= char_idx + 3'd1;
              if (char_idx == 3'd8) begin
                state <= COUNT_COMPLETE;
                char_idx <= 3'd0;
              end
            end
          end
        end
        COUNT_COMPLETE: begin
          unique_count <= 0;
          for (int i = 0; i < 26; i = i + 1) begin
            if (unique_chars[i]) begin
              unique_count <= unique_count + 6'd1;
            end
          end
          if (unique_count > max_unique || (unique_count == max_unique && current_word < words[best_word_idx])) begin
            max_unique <= unique_count;
            best_word_idx <= word_idx;
          end
          state <= NEXT_WORD;
        end
        NEXT_WORD: begin
          word_idx <= word_idx + 3'd1;
          if (word_idx == 3'd8) begin
            state <= DONE;
          end else begin
            state <= UNIQUE_COUNT_START;
          end
        end
        DONE: begin
          result_word <= words[best_word_idx][7:0];
          done <= 1'd1;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule