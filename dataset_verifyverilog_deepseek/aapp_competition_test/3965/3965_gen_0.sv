module verse_pattern_matcher(
  input clk,
  input rst_n,
  input start,
  input [3:0][3:0] pattern,
  input [3:0][15:0][7:0] text_lines,
  output reg match,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    COUNT_VOWELS,
    COMPARE,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [1:0] line_idx;
  reg [3:0] line_count;
  reg all_match;

  function automatic [3:0] count_vowels(input [15:0][7:0] line);
    integer i;
    reg [3:0] cnt;
    begin
      cnt = 0;
      for (i = 0; i < 16; i = i + 1) begin
        if (line[i] == "a" || line[i] == "e" || line[i] == "i" || 
            line[i] == "o" || line[i] == "u" || line[i] == "y") cnt = cnt + 1;
      end
      count_vowels = cnt;
    end
  endfunction

  // State registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= IDLE;
    else current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = COUNT_VOWELS;
      COUNT_VOWELS: next_state = COMPARE;
      COMPARE: next_state = (line_count != pattern[line_idx] || line_idx == 2'd3) ? DONE : COUNT_VOWELS;
      DONE: if (!start) next_state = IDLE;
    endcase
  end

  // Line index logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) line_idx <= 2'd0;
    else if (current_state == IDLE && start) line_idx <= 2'd0;
    else if (current_state == COMPARE && line_count == pattern[line_idx] && line_idx < 2'd3)
      line_idx <= line_idx + 1;
  end

  // Line count logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) line_count <= 4'd0;
    else if (current_state == COUNT_VOWELS)
      line_count <= count_vowels(text_lines[line_idx]);
  end

  // All match flag
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) all_match <= 1'b0;
    else if (current_state == IDLE && start) all_match <= 1'b1;
    else if (current_state == COMPARE && line_count != pattern[line_idx])
      all_match <= 1'b0;
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      match <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= (current_state == DONE);
      if (current_state == DONE) match <= all_match;
      else if (current_state == IDLE) match <= 1'b0;
    end
  end

endmodule