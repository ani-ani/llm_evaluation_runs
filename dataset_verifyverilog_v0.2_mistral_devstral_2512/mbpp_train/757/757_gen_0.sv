module reverse_pair_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] str_data [0:4][0:7],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_REVERSE,
    COUNT_PAIRS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Temporary storage for reversed strings
  reg [7:0] reversed_str [0:4][0:7];

  // Counters and control signals
  reg [2:0] char_pos; // 0-7 for character position
  reg [2:0] pair_i;   // 0-4 for first string index
  reg [2:0] pair_j;   // 0-4 for second string index
  reg [3:0] pair_count;
  reg [3:0] temp_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 4'b0;
      char_pos <= 3'b0;
      pair_i <= 3'b0;
      pair_j <= 3'b0;
      pair_count <= 4'b0;
      temp_count <= 4'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_REVERSE;
      end
      CHECK_REVERSE: begin
        if (char_pos == 7) begin
          next_state = COUNT_PAIRS;
        end
      end
      COUNT_PAIRS: begin
        if (pair_i == 4 && pair_j == 4) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) next_state = CHECK_REVERSE;
      end
    endcase
  end

  // Character position counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_pos <= 3'b0;
    end else if (current_state == CHECK_REVERSE && char_pos < 7) begin
      char_pos <= char_pos + 1;
    end else if (current_state == COUNT_PAIRS) begin
      char_pos <= 3'b0;
    end
  end

  // Pair counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pair_i <= 3'b0;
      pair_j <= 3'b0;
    end else if (current_state == COUNT_PAIRS) begin
      if (pair_j == 4) begin
        pair_i <= pair_i + 1;
        pair_j <= pair_i + 1;
      end else if (pair_j < 4) begin
        pair_j <= pair_j + 1;
      end
    end else if (current_state == DONE) begin
      pair_i <= 3'b0;
      pair_j <= 3'b0;
    end
  end

  // Reverse computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < 8; j++) begin
          reversed_str[i][j] <= 8'b0;
        end
      end
    end else if (current_state == CHECK_REVERSE) begin
      for (int i = 0; i < 5; i++) begin
        reversed_str[i][char_pos] <= str_data[i][7 - char_pos];
      end
    end
  end

  // Pair comparison and counting
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      temp_count <= 4'b0;
    end else if (current_state == COUNT_PAIRS) begin
      if (pair_i < 4 && pair_j < 5 && pair_i < pair_j) begin
        // Compare reversed_str[pair_i] with str_data[pair_j]
        reg match;
        match = 1'b1;
        for (int k = 0; k < 8; k++) begin
          if (reversed_str[pair_i][k] != str_data[pair_j][k]) begin
            match = 1'b0;
          end
        end
        if (match) begin
          temp_count <= temp_count + 1;
        end
      end
    end else if (current_state == DONE) begin
      pair_count <= temp_count;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 4'b0;
      done <= 1'b0;
    end else if (current_state == DONE) begin
      result <= pair_count;
      done <= 1'b1;
    end else begin
      done <= 1'b0;
    end
  end

endmodule