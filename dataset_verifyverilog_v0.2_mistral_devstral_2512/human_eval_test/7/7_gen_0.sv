module filter_by_substring (
  input clk,
  input rst_n,
  input start,
  input [7:0][63:0] input_strings,
  input [63:0] substring,
  input [2:0] valid_count,
  output reg [2:0] match_indices [0:7],
  output reg [3:0] match_count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_STRING,
    NEXT_STRING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] current_string_idx;
  reg [2:0] current_pos;
  reg [2:0] current_char_idx;
  reg [2:0] match_ptr;
  reg [2:0] string_counter;
  reg [7:0] substring_len;
  reg substring_null_found;

  // Calculate substring length (find first null character)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      substring_len <= 0;
      substring_null_found <= 0;
    end else if (start) begin
      // Reset substring length calculation
      substring_len <= 0;
      substring_null_found <= 0;
    end else if (current_state == IDLE && substring_null_found == 0) begin
      // Calculate substring length by finding first null
      if (substring[substring_len] == 8'h00) begin
        substring_null_found <= 1;
      end else begin
        substring_len <= substring_len + 1;
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start && substring_null_found) begin
          next_state = CHECK_STRING;
        end else begin
          next_state = IDLE;
        end
      end
      CHECK_STRING: begin
        if (current_char_idx == substring_len - 1) begin
          if (substring[current_char_idx] == input_strings[current_string_idx][current_pos + current_char_idx]) begin
            // Full match found
            next_state = NEXT_STRING;
          end else begin
            // No match, try next position
            if (current_pos == 7) begin
              next_state = NEXT_STRING;
            end else begin
              next_state = CHECK_STRING;
            end
          end
        end else begin
          if (substring[current_char_idx] != input_strings[current_string_idx][current_pos + current_char_idx]) begin
            // Mismatch, try next position
            if (current_pos == 7) begin
              next_state = NEXT_STRING;
            end else begin
              next_state = CHECK_STRING;
            end
          end else begin
            next_state = CHECK_STRING;
          end
        end
      end
      NEXT_STRING: begin
        if (current_string_idx == valid_count - 1) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_STRING;
        end
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_string_idx <= 0;
      current_pos <= 0;
      current_char_idx <= 0;
      match_ptr <= 0;
      string_counter <= 0;
      match_count <= 0;
      done <= 0;
      for (int i = 0; i < 8; i++) begin
        match_indices[i] <= 0;
      end
    end else begin
      case (current_state)
        IDLE: begin
          current_string_idx <= 0;
          current_pos <= 0;
          current_char_idx <= 0;
          match_ptr <= 0;
          string_counter <= 0;
          match_count <= 0;
          done <= 0;
        end
        CHECK_STRING: begin
          if (current_char_idx == 0) begin
            // Starting new position check
            if (current_pos == 0) begin
              string_counter <= string_counter + 1;
            end
            current_pos <= current_pos + 1;
          end
          current_char_idx <= current_char_idx + 1;
          
          // Check for match completion
          if (current_char_idx == substring_len) begin
            // Match found
            match_indices[match_ptr] <= current_string_idx;
            match_ptr <= match_ptr + 1;
            match_count <= match_count + 1;
            current_char_idx <= 0;
            
            // Move to next position or string
            if (current_pos == 8) begin
              current_string_idx <= current_string_idx + 1;
              current_pos <= 0;
            end
          end else if (substring[current_char_idx] != input_strings[current_string_idx][current_pos + current_char_idx]) begin
            // Mismatch, reset character index
            current_char_idx <= 0;
          end
        end
        NEXT_STRING: begin
          current_string_idx <= current_string_idx + 1;
          current_pos <= 0;
          current_char_idx <= 0;
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk) begin
    if (current_state == IDLE && start) begin
      done <= 0;
    end
  end

endmodule