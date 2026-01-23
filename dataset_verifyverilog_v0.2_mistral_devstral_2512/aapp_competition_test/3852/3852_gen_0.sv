module non_decreasing_sequence (
  input clk,
  input rst_n,
  input start,
  input signed [31:0] a_in,
  input [3:0] idx,
  input valid_in,
  output reg [3:0] op_x,
  output reg [3:0] op_y,
  output reg op_valid,
  output reg done,
  output reg error
);

  parameter N = 16;
  parameter MAX_OPS = 32;

  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    ANALYZE,
    PROCESS_OPS,
    COMPLETE
  } state_t;

  state_t state, next_state;
  logic [3:0] load_count;
  logic [5:0] op_count;
  logic [31:0] array [0:N-1];
  logic [3:0] max_idx, min_idx;
  logic [31:0] max_val, min_val;
  logic all_non_negative, all_non_positive;
  logic [3:0] current_x, current_y;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_count <= 0;
      op_count <= 0;
      op_x <= 0;
      op_y <= 0;
      op_valid <= 0;
      done <= 0;
      error <= 0;
      for (int i = 0; i < N; i++) array[i] <= 0;
    end else begin
      state <= next_state;
      if (state == LOAD && valid_in) begin
        array[idx] <= a_in;
        load_count <= load_count + 1;
      end
      if (state == PROCESS_OPS && op_valid) begin
        op_count <= op_count + 1;
      end
    end
  end

  always_comb begin
    next_state = state;
    op_valid = 0;
    done = 0;
    error = 0;

    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end

      LOAD: begin
        if (load_count == N-1) next_state = ANALYZE;
      end

      ANALYZE: begin
        max_val = array[0];
        min_val = array[0];
        max_idx = 0;
        min_idx = 0;
        all_non_negative = 1;
        all_non_positive = 1;

        for (int i = 1; i < N; i++) begin
          if (array[i] > max_val) begin
            max_val = array[i];
            max_idx = i;
          end
          if (array[i] < min_val) begin
            min_val = array[i];
            min_idx = i;
          end
          if (array[i] < 0) all_non_negative = 0;
          if (array[i] > 0) all_non_positive = 0;
        end

        next_state = PROCESS_OPS;
      end

      PROCESS_OPS: begin
        if (op_count >= MAX_OPS) begin
          error = 1;
          next_state = COMPLETE;
        end else begin
          if (all_non_negative) begin
            if (op_count < N-1) begin
              current_x = op_count;
              current_y = op_count + 1;
              op_valid = 1;
            end else begin
              next_state = COMPLETE;
            end
          end else if (all_non_positive) begin
            if (op_count < N-1) begin
              current_x = N-1 - op_count;
              current_y = N-2 - op_count;
              op_valid = 1;
            end else begin
              next_state = COMPLETE;
            end
          end else begin
            if (op_count == 0) begin
              current_x = max_idx;
              current_y = min_idx;
              op_valid = 1;
            end else if (op_count < N-1) begin
              current_x = op_count - 1;
              current_y = op_count;
              op_valid = 1;
            end else begin
              next_state = COMPLETE;
            end
          end
        end
      end

      COMPLETE: begin
        done = 1;
        if (!start) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (op_valid) begin
      op_x <= current_x;
      op_y <= current_y;
    end
  end

endmodule