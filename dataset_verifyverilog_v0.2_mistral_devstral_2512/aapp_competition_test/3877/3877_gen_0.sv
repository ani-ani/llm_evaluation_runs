module count_ones_range (
  input clk,
  input rst_n,
  input start,
  input [15:0] n_in,
  input [13:0] l_in,
  input [13:0] r_in,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [5:0] {
    IDLE,
    CALCULATE_LEN,
    PUSH_CALL,
    POP_AND_PROCESS,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Stack parameters
  localparam STACK_DEPTH = 14;
  localparam STACK_WIDTH = 15 + 14 + 14; // n (16b), start_idx (14b), end_idx (14b)

  // Stack implementation
  reg [STACK_WIDTH-1:0] stack [0:STACK_DEPTH-1];
  reg [3:0] stack_ptr;

  // Current node data
  reg [15:0] current_n;
  reg [13:0] current_start, current_end;

  // Temporary variables
  reg [13:0] left_len, right_len;
  reg [13:0] mid_pos;
  reg [31:0] temp_count;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'h0;
      done <= 1'b0;
      current_state <= IDLE;
      stack_ptr <= 4'h0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATE_LEN;
          // Initialize stack with root node
          current_n = n_in;
          current_start = 14'h0;
          current_end = 14'h0;
        end
      end

      CALCULATE_LEN: begin
        if (current_n == 16'h0) begin
          // Base case: all zeros
          next_state = POP_AND_PROCESS;
        end else if (current_n == 16'h1) begin
          // Base case: single 1
          next_state = UPDATE_RESULT;
        end else begin
          // Calculate lengths for left and right parts
          left_len = (current_n >> 1) == 16'h0 ? 14'h0 : (current_n >> 1);
          right_len = left_len;
          mid_pos = current_start + left_len;

          // Push right part first (for DFS)
          if (right_len > 14'h0) begin
            next_state = PUSH_CALL;
          end else begin
            next_state = POP_AND_PROCESS;
          end
        end
      end

      PUSH_CALL: begin
        // Push right part to stack
        if (stack_ptr < STACK_DEPTH) begin
          stack[stack_ptr] = {current_n >> 1, current_start + left_len + 14'h1, current_end};
          stack_ptr <= stack_ptr + 1;
        end
        // Now process left part
        current_n = current_n >> 1;
        current_end = mid_pos - 14'h1;
        next_state = CALCULATE_LEN;
      end

      POP_AND_PROCESS: begin
        // Process current node (middle element)
        if (current_n == 16'h1 && mid_pos >= l_in && mid_pos <= r_in) begin
          temp_count = 1;
        end else begin
          temp_count = 0;
        end
        next_state = UPDATE_RESULT;
      end

      UPDATE_RESULT: begin
        // Update result with current count
        result <= result + temp_count;

        // Pop from stack if not empty
        if (stack_ptr > 4'h0) begin
          stack_ptr <= stack_ptr - 1;
          {current_n, current_start, current_end} = stack[stack_ptr];
          next_state = CALCULATE_LEN;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        done <= 1'b1;
        if (!start) begin
          done <= 1'b0;
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Calculate mid_pos for current node
  always @(*) begin
    if (current_n > 16'h1) begin
      left_len = (current_n >> 1) == 16'h0 ? 14'h0 : (current_n >> 1);
      right_len = left_len;
      mid_pos = current_start + left_len;
    end else begin
      left_len = 14'h0;
      right_len = 14'h0;
      mid_pos = current_start;
    end
  end

endmodule