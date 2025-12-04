module robot_position_checker(
  input clk,
  input rst_n,
  input start,
  input signed [15:0] a,
  input signed [15:0] b,
  input [15:0][1:0] cmd_string,
  output reg result,
  output reg done
);

  typedef enum logic [1:0] { IDLE, COMPUTE_STEPS, CHECK_CONDITIONS, DONE } state_t;
  state_t current_state, next_state;

  reg signed [15:0] curr_x, curr_y;
  reg signed [15:0] dx, dy;
  reg signed [15:0] x_steps [0:15];
  reg signed [15:0] y_steps [0:15];
  reg [4:0] step_counter; // 0-31 (count 0-15 for steps)
  reg [3:0] check_counter;
  reg found;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      curr_x <= 0;
      curr_y <= 0;
      dx <= 0;
      dy <= 0;
      step_counter <= 0;
      check_counter <= 0;
      found <= 0;
      result <= 0;
      done <= 0;
      for (int i=0; i<16; i++) begin
        x_steps[i] <= 0;
        y_steps[i] <= 0;
      end
    end else begin
      current_state <= next_state;

      case(current_state)
        IDLE: begin
          done <= 0;
          result <= 0;
          found <= 0;
          if (start) begin
            curr_x <= 0;
            curr_y <= 0;
            step_counter <= 0;
          end
        end

        COMPUTE_STEPS: begin
          if (step_counter < 16) begin
            case(cmd_string[step_counter[3:0]])
              2'b00: begin curr_y <= curr_y + 1; y_steps[step_counter[3:0]] <= curr_y + 1; end
              2'b01: begin curr_y <= curr_y - 1; y_steps[step_counter[3:0]] <= curr_y - 1; end
              2'b10: begin curr_x <= curr_x - 1; x_steps[step_counter[3:0]] <= curr_x - 1; end
              2'b11: begin curr_x <= curr_x + 1; x_steps[step_counter[3:0]] <= curr_x + 1; end
            endcase
            step_counter <= step_counter + 1;
          end
        end

        CHECK_CONDITIONS: begin
          if (check_counter < 16) begin
            automatic logic signed [15:0] x_i = x_steps[check_counter];
            automatic logic signed [15:0] y_i = y_steps[check_counter];
            automatic logic signed [15:0] delta_x = a - x_i;
            automatic logic signed [15:0] delta_y = b - y_i;
            automatic logic dx_zero = (dx == 0);
            automatic logic dy_zero = (dy == 0);
            automatic logic condition_met;

            if (dx_zero && dy_zero) begin
              condition_met = (x_i == a) && (y_i == b);
            end else if (dx_zero) begin
              condition_met = (x_i == a) && ((dy > 0) ? (delta_y >= 0) : (delta_y <= 0)) && (delta_y % dy == 0);
            end else if (dy_zero) begin
              condition_met = (y_i == b) && ((dx > 0) ? (delta_x >= 0) : (delta_x <= 0)) && (delta_x % dx == 0);
            end else begin
              condition_met = (delta_x * dy == delta_y * dx) &&
                             ((dx > 0) ? (delta_x >= 0) : (delta_x <= 0)) &&
                             (delta_x % dx == 0);
            end

            if (condition_met) found <= 1;
            check_counter <= check_counter + 1;
          end
        end

        DONE: begin
          result <= found;
          done <= 1;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (current_state == COMPUTE_STEPS && next_state == CHECK_CONDITIONS) begin
      dx <= curr_x;
      dy <= curr_y;
    end
  end

  always_comb begin
    next_state = current_state;
    case(current_state)
      IDLE: if(start) next_state = COMPUTE_STEPS;
      COMPUTE_STEPS: if(step_counter == 16) next_state = CHECK_CONDITIONS;
      CHECK_CONDITIONS: if(check_counter == 16) next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

endmodule