module string_splitter (
  input clk,
  input rst_n,
  input start,
  input [7:0] input_string [15:0],
  output reg [7:0] word1 [15:0],
  output reg [7:0] word2 [15:0],
  output reg [7:0] word3 [15:0],
  output reg [2:0] word_count,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] SCAN = 2'b01;
  localparam [1:0] EXTRACT = 2'b10;
  localparam [1:0] DONE = 2'b11;

  reg [1:0] state, next_state;

  // Counters
  reg [3:0] char_idx; // 0-15
  reg [1:0] word_idx; // 0-2
  reg [3:0] word_pos; // 0-15

  // Internal registers
  reg [7:0] current_word [15:0];
  reg [2:0] internal_word_count;

  // Initialize outputs
  integer i, j;
  initial begin
    for (i = 0; i < 16; i = i + 1) begin
      word1[i] = 8'h20;
      word2[i] = 8'h20;
      word3[i] = 8'h20;
    end
    word_count = 3'b000;
    done = 1'b0;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_idx <= 0;
      word_idx <= 0;
      word_pos <= 0;
      internal_word_count <= 0;
      done <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        current_word[i] <= 8'h20;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SCAN;
      end
      SCAN: begin
        if (char_idx == 15) next_state = EXTRACT;
      end
      EXTRACT: begin
        if (word_idx == 2 || (word_idx == 1 && internal_word_count == 1) || (word_idx == 0 && internal_word_count == 0)) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // SCAN state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_idx <= 0;
      word_idx <= 0;
      word_pos <= 0;
      internal_word_count <= 0;
    end else if (state == SCAN) begin
      if (input_string[char_idx] != 8'h20) begin
        current_word[word_pos] <= input_string[char_idx];
        word_pos <= word_pos + 1;
      end else if (word_pos > 0) begin
        // End of word detected
        internal_word_count <= internal_word_count + 1;
        word_idx <= word_idx + 1;
        word_pos <= 0;
      end
      char_idx <= char_idx + 1;
    end
  end

  // EXTRACT state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        word1[i] <= 8'h20;
        word2[i] <= 8'h20;
        word3[i] <= 8'h20;
      end
    end else if (state == EXTRACT) begin
      case (word_idx)
        0: begin
          for (i = 0; i < 16; i = i + 1) begin
            if (i < word_pos) word1[i] <= current_word[i];
            else word1[i] <= 8'h20;
          end
        end
        1: begin
          for (i = 0; i < 16; i = i + 1) begin
            if (i < word_pos) word2[i] <= current_word[i];
            else word2[i] <= 8'h20;
          end
        end
        2: begin
          for (i = 0; i < 16; i = i + 1) begin
            if (i < word_pos) word3[i] <= current_word[i];
            else word3[i] <= 8'h20;
          end
        end
      endcase
      word_idx <= word_idx + 1;
    end
  end

  // DONE state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      word_count <= 0;
    end else if (state == DONE) begin
      done <= 1;
      word_count <= internal_word_count;
    end else begin
      done <= 0;
    end
  end

endmodule