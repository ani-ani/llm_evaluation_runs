module file_pattern_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0] pattern_char,
  input [7:0] file_char,
  input pattern_valid,
  input file_valid,
  input pattern_end,
  input file_end,
  output reg match_result,
  output reg done,
  output reg need_more_chars
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PATTERN_READ,
    FILE_READ,
    WILDCARD_MATCH,
    COMPARE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal buffers (max 8 characters each)
  reg [7:0] pattern_buffer [0:7];
  reg [7:0] file_buffer [0:7];
  reg [2:0] pattern_ptr;
  reg [2:0] file_ptr;
  reg [2:0] pattern_len;
  reg [2:0] file_len;

  // Wildcard tracking
  reg wildcard_active;
  reg [2:0] wildcard_pattern_pos;
  reg [2:0] wildcard_file_pos;

  // Match tracking
  reg [2:0] pattern_idx;
  reg [2:0] file_idx;
  reg match_found;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = current_state;
    need_more_chars = 1'b0;
    match_result = 1'b0;
    done = 1'b0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PATTERN_READ;
          need_more_chars = 1'b1;
        end
      end

      PATTERN_READ: begin
        if (pattern_valid) begin
          pattern_buffer[pattern_ptr] = pattern_char;
          pattern_ptr = pattern_ptr + 1;
          if (pattern_end) begin
            pattern_len = pattern_ptr;
            pattern_ptr = 0;
            next_state = FILE_READ;
          end
        end else if (!pattern_valid && !pattern_end) begin
          need_more_chars = 1'b1;
        end
      end

      FILE_READ: begin
        if (file_valid) begin
          file_buffer[file_ptr] = file_char;
          file_ptr = file_ptr + 1;
          if (file_end) begin
            file_len = file_ptr;
            file_ptr = 0;
            pattern_idx = 0;
            file_idx = 0;
            match_found = 1'b1;
            next_state = COMPARE;
          end
        end else if (!file_valid && !file_end) begin
          need_more_chars = 1'b1;
        end
      end

      COMPARE: begin
        if (pattern_idx < pattern_len && file_idx < file_len) begin
          if (pattern_buffer[pattern_idx] == 8'h2a) begin // '*' wildcard
            wildcard_active = 1'b1;
            wildcard_pattern_pos = pattern_idx;
            wildcard_file_pos = file_idx;
            pattern_idx = pattern_idx + 1;
            next_state = WILDCARD_MATCH;
          end else begin
            if (pattern_buffer[pattern_idx] == file_buffer[file_idx]) begin
              pattern_idx = pattern_idx + 1;
              file_idx = file_idx + 1;
            end else begin
              if (wildcard_active) begin
                // Try to extend wildcard match
                file_idx = file_idx + 1;
                pattern_idx = wildcard_pattern_pos + 1;
              end else begin
                match_found = 1'b0;
                next_state = DONE;
              end
            end
          end
        end else if (pattern_idx == pattern_len && file_idx == file_len) begin
          next_state = DONE;
        end else if (pattern_idx < pattern_len) begin
          // Check if remaining pattern is all wildcards
          reg all_wildcards = 1'b1;
          for (int i = pattern_idx; i < pattern_len; i = i + 1) begin
            if (pattern_buffer[i] != 8'h2a) begin
              all_wildcards = 1'b0;
            end
          end
          if (all_wildcards) begin
            next_state = DONE;
          end else begin
            match_found = 1'b0;
            next_state = DONE;
          end
        end else if (file_idx < file_len) begin
          if (wildcard_active) begin
            file_idx = file_idx + 1;
            pattern_idx = wildcard_pattern_pos + 1;
          end else begin
            match_found = 1'b0;
            next_state = DONE;
          end
        end else begin
          next_state = DONE;
        end
      end

      WILDCARD_MATCH: begin
        if (pattern_idx < pattern_len && file_idx < file_len) begin
          if (pattern_buffer[pattern_idx] == file_buffer[file_idx]) begin
            pattern_idx = pattern_idx + 1;
            file_idx = file_idx + 1;
            next_state = COMPARE;
          end else begin
            file_idx = file_idx + 1;
          end
        end else if (pattern_idx == pattern_len && file_idx == file_len) begin
          next_state = DONE;
        end else if (pattern_idx < pattern_len) begin
          // Check if remaining pattern is all wildcards
          reg all_wildcards = 1'b1;
          for (int i = pattern_idx; i < pattern_len; i = i + 1) begin
            if (pattern_buffer[i] != 8'h2a) begin
              all_wildcards = 1'b0;
            end
          end
          if (all_wildcards) begin
            next_state = DONE;
          end else begin
            match_found = 1'b0;
            next_state = DONE;
          end
        end else if (file_idx < file_len) begin
          file_idx = file_idx + 1;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        match_result = match_found;
        done = 1'b1;
        if (start) begin
          next_state = PATTERN_READ;
          need_more_chars = 1'b1;
          // Reset internal state
          pattern_ptr = 0;
          file_ptr = 0;
          wildcard_active = 1'b0;
          match_found = 1'b1;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Reset logic
  always @(negedge rst_n) begin
    if (!rst_n) begin
      pattern_ptr <= 0;
      file_ptr <= 0;
      pattern_len <= 0;
      file_len <= 0;
      wildcard_active <= 0;
      wildcard_pattern_pos <= 0;
      wildcard_file_pos <= 0;
      pattern_idx <= 0;
      file_idx <= 0;
      match_found <= 1'b1;
      match_result <= 0;
      done <= 0;
      need_more_chars <= 0;
    end
  end

endmodule