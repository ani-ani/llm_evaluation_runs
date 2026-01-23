module string_explosion (
  input clk,
  input rst_n,
  input start,
  input [7:0] str_in [0:15],
  input [7:0] exp_in [0:7],
  input [5:0] str_len,
  input [5:0] exp_len,
  output reg [7:0] result [0:15],
  output reg [5:0] result_len,
  output reg done,
  output reg empty
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT_LOAD,
    CHECK_EXPLOSION,
    EXPLODE,
    RECHECK,
    NEXT_ITERATION,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] stack [0:15];
  reg [3:0] stack_ptr;
  reg [2:0] iter_count;
  reg [5:0] input_idx;
  reg [5:0] check_idx;
  reg match_found;

  // Initialize all registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      stack_ptr <= 0;
      iter_count <= 0;
      input_idx <= 0;
      check_idx <= 0;
      match_found <= 0;
      done <= 0;
      empty <= 0;
      result_len <= 0;
      for (int i = 0; i < 16; i = i + 1) begin
        stack[i] <= 0;
        result[i] <= 0;
      end
    end else begin
      state <= next_state;
      if (state == INIT_LOAD && input_idx < str_len) begin
        stack[stack_ptr] <= str_in[input_idx];
        stack_ptr <= stack_ptr + 1;
        input_idx <= input_idx + 1;
      end
      if (state == EXPLODE) begin
        stack_ptr <= stack_ptr - exp_len;
      end
      if (state == DONE) begin
        done <= 1;
        empty <= (result_len == 0);
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_LOAD;
      end
      INIT_LOAD: begin
        if (input_idx == str_len) begin
          if (exp_len == 0 || stack_ptr < exp_len) begin
            next_state = DONE;
          end else begin
            next_state = CHECK_EXPLOSION;
          end
        end
      end
      CHECK_EXPLOSION: begin
        if (stack_ptr >= exp_len && stack[stack_ptr - 1] == exp_in[exp_len - 1]) begin
          match_found = 1;
          for (int i = 0; i < exp_len; i = i + 1) begin
            if (stack[stack_ptr - exp_len + i] != exp_in[i]) begin
              match_found = 0;
            end
          end
          if (match_found) begin
            next_state = EXPLODE;
          end else begin
            next_state = RECHECK;
          end
        end else begin
          next_state = RECHECK;
        end
      end
      EXPLODE: begin
        next_state = RECHECK;
      end
      RECHECK: begin
        if (stack_ptr >= exp_len) begin
          next_state = CHECK_EXPLOSION;
        end else begin
          if (iter_count == 7) begin
            next_state = DONE;
          end else begin
            next_state = NEXT_ITERATION;
          end
        end
      end
      NEXT_ITERATION: begin
        iter_count = iter_count + 1;
        input_idx = 0;
        next_state = INIT_LOAD;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output result when done
  always @(posedge clk) begin
    if (state == DONE) begin
      result_len <= stack_ptr;
      for (int i = 0; i < 16; i = i + 1) begin
        if (i < stack_ptr) begin
          result[i] <= stack[i];
        end else begin
          result[i] <= 0;
        end
      end
    end
  end

endmodule