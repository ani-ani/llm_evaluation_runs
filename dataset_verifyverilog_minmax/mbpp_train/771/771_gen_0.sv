module balance_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0][2:0] expr,
  output reg result,
  output reg done
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // State registers
  reg [1:0] state, next_state;
  reg [4:0] char_idx, next_char_idx;
  reg [3:0] stack_ptr, next_stack_ptr;
  reg error, next_error;
  reg result, next_result;
  reg done, next_done;
  reg [2:0] stack_mem [0:7];
  reg [2:0] next_stack_mem [0:7];

  // Combinational logic for next state and next values
  always_comb begin
    // Default assignments
    next_state = state;
    next_char_idx = char_idx;
    next_stack_ptr = stack_ptr;
    next_error = error;
    next_result = result;
    next_done = 1'b0;
    // Copy current stack to next stack by default
    for (int i = 0; i < 8; i++) next_stack_mem[i] = stack_mem[i];

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          next_char_idx = 5'd0;
          next_stack_ptr = 4'd0;
          next_error = 1'b0;
          // Clear stack
          for (int i = 0; i < 8; i++) next_stack_mem[i] = 3'b0;
        end
      end
      PROCESSING: begin
        // Process current character at char_idx (0..15)
        if (char_idx < 5'd16) begin
          reg [2:0] ch = expr[char_idx];
          // Determine if open, close, or ignore
          if (ch == 3'b000 || ch == 3'b010 || ch == 3'b100) begin // open bracket
            if (next_stack_ptr < 4'd8) begin
              next_stack_mem[next_stack_ptr] = ch;
              next_stack_ptr = next_stack_ptr + 1;
            end else begin
              next_error = 1'b1; // stack overflow
            end
          end else if (ch == 3'b001 || ch == 3'b011 || ch == 3'b101) begin // close bracket
            if (next_stack_ptr == 4'd0) begin
              next_error = 1'b1; // unmatched close
            end else begin
              reg [2:0] top = next_stack_mem[next_stack_ptr - 1];
              // Check matching
              if ((ch == 3'b001 && top != 3'b000) ||
                  (ch == 3'b011 && top != 3'b010) ||
                  (ch == 3'b101 && top != 3'b100)) begin
                next_error = 1'b1; // mismatch
              end else begin
                // pop
                next_stack_ptr = next_stack_ptr - 1;
              end
            end
          end
          // Increment char_idx or move to DONE
          if (char_idx == 5'd15) begin
            // All characters processed, go to DONE next cycle
            next_state = DONE;
          end else begin
            next_char_idx = char_idx + 1;
          end
        end else begin
          // Should not happen, but go to DONE
          next_state = DONE;
        end
      end
      DONE: begin
        // Compute result
        next_result = (next_stack_ptr == 4'd0 && !next_error);
        next_done = 1'b1;
        // After one cycle, go back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 1'b0;
      done <= 1'b0;
      char_idx <= 5'b0;
      stack_ptr <= 4'b0;
      error <= 1'b0;
      for (int i = 0; i < 8; i++) stack_mem[i] <= 3'b0;
    end else begin
      state <= next_state;
      result <= next_result;
      done <= next_done;
      char_idx <= next_char_idx;
      stack_ptr <= next_stack_ptr;
      error <= next_error;
      for (int i = 0; i < 8; i++) stack_mem[i] <= next_stack_mem[i];
    end
  end

endmodule