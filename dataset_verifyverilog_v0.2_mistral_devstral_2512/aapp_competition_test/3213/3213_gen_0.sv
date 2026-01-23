module spell_optimizer(
  input clk,
  input rst_n,
  input start,
  input [7:0] step_types,
  output reg [2:0] max_power,
  output reg [7:0] best_mask,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    ITERATING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] combination_counter;
  reg [7:0] next_combination_counter;
  reg [2:0] current_power;
  reg [2:0] next_current_power;
  reg [2:0] next_max_power;
  reg [7:0] next_best_mask;
  reg [7:0] step_counter;
  reg [7:0] next_step_counter;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      combination_counter <= 0;
      step_counter <= 0;
      current_power <= 0;
      max_power <= 0;
      best_mask <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      combination_counter <= next_combination_counter;
      step_counter <= next_step_counter;
      current_power <= next_current_power;
      max_power <= next_max_power;
      best_mask <= next_best_mask;
      done <= (current_state == DONE);
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    next_combination_counter = combination_counter;
    next_step_counter = step_counter;
    next_current_power = current_power;
    next_max_power = max_power;
    next_best_mask = best_mask;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = ITERATING;
          next_combination_counter = 0;
          next_step_counter = 0;
          next_current_power = 1;
          next_max_power = 0;
          next_best_mask = 0;
        end
      end

      ITERATING: begin
        if (step_counter == 0) begin
          // Start new combination
          next_current_power = 1;
        end else begin
          // Process current step
          if (combination_counter[step_counter]) begin
            if (step_types[step_counter]) begin
              // 'x' operation: multiply by 2
              next_current_power = (current_power * 2) % 8;
            end else begin
              // '+' operation: add 1
              next_current_power = (current_power + 1) % 8;
            end
          end else begin
            // 'o' operation: no change
            next_current_power = current_power;
          end
        end

        // Move to next step or next combination
        if (step_counter == 7) begin
          // Finished current combination
          if (current_power > max_power) begin
            next_max_power = current_power;
            next_best_mask = combination_counter;
          end

          // Move to next combination
          if (combination_counter == 255) begin
            next_state = DONE;
          end else begin
            next_combination_counter = combination_counter + 1;
            next_step_counter = 0;
          end
        end else begin
          next_step_counter = step_counter + 1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule