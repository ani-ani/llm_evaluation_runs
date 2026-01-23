module bracket_eval (
  input clk,
  input rst_n,
  input start,
  input [7:0] token_in,
  input token_valid,
  input token_end,
  output reg [31:0] result,
  output reg result_valid,
  output reg done
);

  // Constants
  localparam MODULUS = 32'h3B9ACA07;
  localparam OPEN_PAREN = 8'h28;
  localparam CLOSE_PAREN = 8'h29;

  // State machine states
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // State machine
  state_t state, next_state;

  // Stack and accumulator
  reg [31:0] stack_values [0:7];
  reg stack_modes [0:7];
  reg [2:0] stack_depth;
  reg [31:0] current_value;
  reg current_mode;

  // Token processing
  reg [3:0] token_count;
  reg [7:0] token_reg;
  reg token_valid_reg;
  reg token_end_reg;

  // Modulo operations
  function [31:0] mod_add;
    input [31:0] a, b;
    begin
      mod_add = (a + b) % MODULUS;
    end
  endfunction

  function [31:0] mod_mul;
    input [31:0] a, b;
    begin
      mod_mul = (a * b) % MODULUS;
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      stack_depth <= 0;
      current_value <= 0;
      current_mode <= 0;
      token_count <= 0;
      token_reg <= 0;
      token_valid_reg <= 0;
      token_end_reg <= 0;
      result <= 0;
      result_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;

      // Register token inputs
      if (state == PROCESSING && token_valid) begin
        token_reg <= token_in;
        token_valid_reg <= token_valid;
        token_end_reg <= token_end;
      end

      // Process token when valid
      if (state == PROCESSING && token_valid_reg) begin
        if (token_reg == OPEN_PAREN) begin
          // Push current state to stack
          stack_values[stack_depth] <= current_value;
          stack_modes[stack_depth] <= current_mode;
          stack_depth <= stack_depth + 1;
          current_value <= 0;
          current_mode <= (stack_depth + 1) % 2;
        end else if (token_reg == CLOSE_PAREN) begin
          // Pop from stack and combine
          reg [31:0] temp = current_value;
          stack_depth <= stack_depth - 1;
          current_value <= stack_values[stack_depth];
          current_mode <= stack_modes[stack_depth];
          if (current_mode == 0) begin
            current_value <= mod_add(current_value, temp);
          end else begin
            current_value <= mod_mul(current_value, temp);
          end
        end else begin
          // Process number
          if (current_mode == 0) begin
            current_value <= mod_add(current_value, token_reg);
          end else begin
            current_value <= mod_mul(current_value, token_reg);
          end
        end

        token_count <= token_count + 1;
        token_valid_reg <= 0;
      end

      // Handle end of tokens
      if (state == PROCESSING && token_end_reg && token_count == 8) begin
        result <= current_value;
        result_valid <= 1;
        done <= 1;
        next_state <= DONE;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      PROCESSING: begin
        if (token_end && token_count == 8) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk) begin
    if (state == DONE && !start) begin
      done <= 0;
      result_valid <= 0;
    end
  end

endmodule