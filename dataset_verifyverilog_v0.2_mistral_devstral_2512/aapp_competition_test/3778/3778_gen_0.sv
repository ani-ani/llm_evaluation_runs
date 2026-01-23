module boomerang_solver (
  input clk,
  input rst_n,
  input start,
  input [1:0] a_in,
  output reg [4:0] target_r,
  output reg [2:0] target_c,
  output reg valid,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESS
  } state_t;

  // Internal signals
  state_t state, next_state;
  logic [1:0] col_counter, next_col_counter;
  logic [3:0] row_counter, next_row_counter;
  logic [3:0] pending_stack [0:3], next_pending_stack [0:3];
  logic [3:0] two_stack [0:3], next_two_stack [0:3];
  logic [3:0] pending_ptr, next_pending_ptr;
  logic [3:0] two_ptr, next_two_ptr;
  logic [3:0] current_row, next_current_row;
  logic [1:0] current_col, next_current_col;
  logic [3:0] target_buffer_r [0:1], target_buffer_c [0:1];
  logic [1:0] target_buffer_ptr, next_target_buffer_ptr;
  logic target_buffer_valid [0:1], next_target_buffer_valid [0:1];
  logic target_buffer_done, next_target_buffer_done;
  logic target_buffer_error, next_target_buffer_error;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      col_counter <= 0;
      row_counter <= 0;
      for (int i = 0; i < 4; i++) begin
        pending_stack[i] <= 0;
        two_stack[i] <= 0;
      end
      pending_ptr <= 0;
      two_ptr <= 0;
      current_row <= 0;
      current_col <= 0;
      target_buffer_ptr <= 0;
      for (int i = 0; i < 2; i++) begin
        target_buffer_r[i] <= 0;
        target_buffer_c[i] <= 0;
        target_buffer_valid[i] <= 0;
      end
      target_buffer_done <= 0;
      target_buffer_error <= 0;
    end else begin
      state <= next_state;
      col_counter <= next_col_counter;
      row_counter <= next_row_counter;
      for (int i = 0; i < 4; i++) begin
        pending_stack[i] <= next_pending_stack[i];
        two_stack[i] <= next_two_stack[i];
      end
      pending_ptr <= next_pending_ptr;
      two_ptr <= next_two_ptr;
      current_row <= next_current_row;
      current_col <= next_current_col;
      target_buffer_ptr <= next_target_buffer_ptr;
      for (int i = 0; i < 2; i++) begin
        target_buffer_r[i] <= target_buffer_r[i];
        target_buffer_c[i] <= target_buffer_c[i];
        target_buffer_valid[i] <= next_target_buffer_valid[i];
      end
      target_buffer_done <= next_target_buffer_done;
      target_buffer_error <= next_target_buffer_error;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    next_col_counter = col_counter;
    next_row_counter = row_counter;
    for (int i = 0; i < 4; i++) begin
      next_pending_stack[i] = pending_stack[i];
      next_two_stack[i] = two_stack[i];
    end
    next_pending_ptr = pending_ptr;
    next_two_ptr = two_ptr;
    next_current_row = current_row;
    next_current_col = current_col;
    next_target_buffer_ptr = target_buffer_ptr;
    for (int i = 0; i < 2; i++) begin
      next_target_buffer_valid[i] = target_buffer_valid[i];
    end
    next_target_buffer_done = target_buffer_done;
    next_target_buffer_error = target_buffer_error;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESS;
          next_col_counter = 0;
          next_row_counter = 0;
          next_current_row = 1;
          next_current_col = 1;
          next_target_buffer_ptr = 0;
          next_target_buffer_done = 0;
          next_target_buffer_error = 0;
        end
      end

      PROCESS: begin
        if (col_counter == 3) begin
          next_state = IDLE;
          next_target_buffer_done = 1;
        end else begin
          next_col_counter = col_counter + 1;
          next_current_col = current_col + 1;
          next_current_row = row_counter + 1;
          next_row_counter = row_counter + 1;

          case (a_in)
            2'b00: begin
              // No operation
            end

            2'b01: begin
              // Add current row to pending stack
              next_pending_stack[pending_ptr] = current_row;
              next_pending_ptr = pending_ptr + 1;
              // Output target (current_row, current_col)
              target_buffer_r[target_buffer_ptr] = current_row;
              target_buffer_c[target_buffer_ptr] = current_col;
              next_target_buffer_valid[target_buffer_ptr] = 1;
              next_target_buffer_ptr = target_buffer_ptr + 1;
            end

            2'b10: begin
              // Requires item from pending stack
              if (pending_ptr > 0) begin
                // Output target (stack_item, current_col)
                target_buffer_r[target_buffer_ptr] = pending_stack[pending_ptr - 1];
                target_buffer_c[target_buffer_ptr] = current_col;
                next_target_buffer_valid[target_buffer_ptr] = 1;
                next_target_buffer_ptr = target_buffer_ptr + 1;
                // Add current_row to two_stack
                next_two_stack[two_ptr] = current_row;
                next_two_ptr = two_ptr + 1;
                // Pop from pending stack
                next_pending_ptr = pending_ptr - 1;
              end else begin
                next_target_buffer_error = 1;
              end
            end

            2'b11: begin
              // Requires item from stack (priority: two_stack > pending_stack)
              if (two_ptr > 0) begin
                // Output targets (current_row, current_col) and (current_row, matched_col)
                target_buffer_r[target_buffer_ptr] = current_row;
                target_buffer_c[target_buffer_ptr] = current_col;
                next_target_buffer_valid[target_buffer_ptr] = 1;
                next_target_buffer_ptr = target_buffer_ptr + 1;
                if (target_buffer_ptr + 1 < 2) begin
                  target_buffer_r[target_buffer_ptr + 1] = current_row;
                  target_buffer_c[target_buffer_ptr + 1] = two_stack[two_ptr - 1];
                  next_target_buffer_valid[target_buffer_ptr + 1] = 1;
                end
                // Add current_row to two_stack
                next_two_stack[two_ptr] = current_row;
                next_two_ptr = two_ptr + 1;
                // Pop from two_stack
                next_two_ptr = two_ptr - 1;
              end else if (pending_ptr > 0) begin
                // Output targets (current_row, current_col) and (current_row, matched_col)
                target_buffer_r[target_buffer_ptr] = current_row;
                target_buffer_c[target_buffer_ptr] = current_col;
                next_target_buffer_valid[target_buffer_ptr] = 1;
                next_target_buffer_ptr = target_buffer_ptr + 1;
                if (target_buffer_ptr + 1 < 2) begin
                  target_buffer_r[target_buffer_ptr + 1] = current_row;
                  target_buffer_c[target_buffer_ptr + 1] = pending_stack[pending_ptr - 1];
                  next_target_buffer_valid[target_buffer_ptr + 1] = 1;
                end
                // Add current_row to two_stack
                next_two_stack[two_ptr] = current_row;
                next_two_ptr = two_ptr + 1;
                // Pop from pending stack
                next_pending_ptr = pending_ptr - 1;
              end else begin
                next_target_buffer_error = 1;
              end
            end
          endcase
        end
      end
    endcase
  end

  // Output logic
  always @(*) begin
    target_r = 0;
    target_c = 0;
    valid = 0;
    done = target_buffer_done;
    error = target_buffer_error;

    if (target_buffer_ptr > 0 && target_buffer_valid[0]) begin
      target_r = target_buffer_r[0];
      target_c = target_buffer_c[0];
      valid = 1;
      // Clear the valid bit after reading
      next_target_buffer_valid[0] = 0;
      // Shift the buffer
      if (target_buffer_ptr > 1) begin
        target_buffer_r[0] = target_buffer_r[1];
        target_buffer_c[0] = target_buffer_c[1];
        target_buffer_valid[0] = target_buffer_valid[1];
        next_target_buffer_ptr = target_buffer_ptr - 1;
      end else begin
        next_target_buffer_ptr = 0;
      end
    end
  end

endmodule