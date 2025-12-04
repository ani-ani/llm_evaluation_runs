module buffet_optimizer(input clk, input rst_n, input start, input [1:0] dish_type [0:3], input [7:0] w_i [0:3], input [7:0] t_i [0:3], input [7:0] dt_i [0:3], input [7:0] target_w, output reg [15:0] max_taste, output reg impossible, output reg done);

  typedef enum logic [2:0] {IDLE, ITERATE_DISHES, CHECK_WEIGHT, UPDATE, DONE} state_e;
  state_e current_state, next_state;

  reg [1:0] dish_counter;
  reg [7:0] remaining_w;
  reg step;
  reg [7:0] N_X;
  reg [7:0] weight_used;
  reg [15:0] taste_cont;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_taste <= 16\'b0;
      remaining_w <= 8\'b0;
      dish_counter <= 2\'b0;
      done <= 1\'b0;
      impossible <= 1\'b0;
      step <= 1\'b0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          if (start) begin
            max_taste <= 16\'b0;
            remaining_w <= target_w;
            dish_counter <= 2\'b0;
            impossible <= 1\'b0;
            done <= 1\'b0;
          end
        end
        ITERATE_DISHES: begin
          step <= 1\'b0;
          if (dish_counter >= 4) done <= 1\'b1;
        end
        CHECK_WEIGHT: begin
          if (!step) step <= 1\'b1;
          else step <= 1\'b0;
        end
        UPDATE: begin
          max_taste <= max_taste + taste_cont;
          remaining_w <= remaining_w - weight_used;
          dish_counter <= dish_counter + 1;
        end
        DONE: begin
          impossible <= (remaining_w > 0);
          done <= 1\'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: next_state = start ? ITERATE_DISHES : IDLE;
      ITERATE_DISHES: next_state = (dish_counter >= 4) ? DONE : CHECK_WEIGHT;
      CHECK_WEIGHT: next_state = (step) ? UPDATE : CHECK_WEIGHT;
      UPDATE: next_state = ITERATE_DISHES;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    weight_used = 8\'b0;
    taste_cont = 16\'b0;
    N_X = 8\'b0;
    if (current_state == CHECK_WEIGHT) begin
      if (dish_type[dish_counter] == 2\'b00 && dt_i[dish_counter] != 8\'b0) begin // Discrete
        if (step) begin
          automatic reg [16:0] decay = dt_i[dish_counter] * (N_X * (N_X - 1)) >> 1;
          taste_cont = ( (N_X * t_i[dish_counter]) - decay ) << 8;
          weight_used = N_X * w_i[dish_counter];
        end else begin
          N_X = (w_i[dish_counter] != 0) ? (remaining_w / w_i[dish_counter]) : 0;
        end
      end else if (dish_type[dish_counter] == 2\'b01) begin // Continuous
        if (step) begin
          automatic reg [15:0] X_squared = N_X * N_X;
          automatic reg [23:0] term1 = t_i[dish_counter] * N_X << 4;
          automatic reg [23:0] term2 = (dt_i[dish_counter] * X_squared) >> 1;
          taste_cont = (term1 - term2) >> 8;
          weight_used = N_X;
        end else begin
          if (dt_i[dish_counter] != 0) begin
            automatic reg [15:0] div_result = (t_i[dish_counter] << 4) / dt_i[dish_counter];
            if (div_result > 255) div_result = 255;
            N_X = (div_result < remaining_w) ? div_result[7:0] : remaining_w;
          end else begin
            N_X = 0;
          end
        end
      end
    end
  end

endmodule