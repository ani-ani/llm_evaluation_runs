module primitive_search_steps (
  input clk,
  input rst_n,
  input start,
  input [7:0] query_word [0:7],
  input db_word_en,
  input [7:0] db_word [0:7],
  input [2:0] db_word_index,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD_DB,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Database storage (8 words, each 8 bytes)
  reg [7:0] database [0:7][0:7];

  // Processing variables
  reg [2:0] current_word_index;
  reg [15:0] step_count;
  reg [2:0] lcp_length;
  reg [7:0] i;
  reg match_found;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_word_index <= 0;
      step_count <= 0;
      lcp_length <= 0;
      i <= 0;
      match_found <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_DB;
      end
      LOAD_DB: begin
        if (db_word_en) next_state = LOAD_DB;
        else next_state = PROCESSING;
      end
      PROCESSING: begin
        if (match_found || current_word_index == 7) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Database loading
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state register
    end else if (current_state == LOAD_DB && db_word_en) begin
      database[db_word_index] <= db_word;
    end
  end

  // Processing logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state register
    end else if (current_state == PROCESSING) begin
      // Compute LCP length
      lcp_length = 0;
      for (i = 0; i < 8; i = i + 1) begin
        if (query_word[i] == database[current_word_index][i]) begin
          lcp_length = lcp_length + 1;
        end else begin
          break;
        end
      end

      // Check for exact match
      match_found = (lcp_length == 8);

      // Accumulate steps
      step_count = step_count + 1 + lcp_length;

      // Move to next word if no match
      if (!match_found) begin
        current_word_index = current_word_index + 1;
      end
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        DONE: begin
          result <= step_count;
          done <= 1;
        end
        default: begin
          result <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule