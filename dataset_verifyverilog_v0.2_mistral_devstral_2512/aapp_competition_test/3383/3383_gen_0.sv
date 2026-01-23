module ice_cream_optimizer (
  input clk,
  input rst_n,
  input start,
  input [7:0] num_scoops,
  input [7:0] cost_per_scoop,
  input [7:0] cost_cone,
  input [3:0][7:0] base_tastiness,
  input [3:0][3:0][15:0] interaction,
  output reg [15:0] max_ratio,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    CALCULATE_SCOOP,
    UPDATE_STATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0] current_scoop;
  reg [3:0] selected_flavour;
  reg [15:0] current_tastiness;
  reg [15:0] current_cost;
  reg [15:0] best_ratio;
  reg [3:0] flavour_counter;
  reg [15:0] temp_tastiness;
  reg [15:0] temp_cost;
  reg [15:0] temp_ratio;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_scoop <= 0;
      selected_flavour <= 0;
      current_tastiness <= 0;
      current_cost <= 0;
      best_ratio <= 0;
      flavour_counter <= 0;
      temp_tastiness <= 0;
      temp_cost <= 0;
      temp_ratio <= 0;
      max_ratio <= 0;
      done <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            next_state = INIT;
          end
        end

        INIT: begin
          current_scoop <= 0;
          current_tastiness <= 0;
          current_cost <= cost_cone;
          best_ratio <= 0;
          next_state = CALCULATE_SCOOP;
        end

        CALCULATE_SCOOP: begin
          if (flavour_counter == 0) begin
            temp_tastiness <= current_tastiness + base_tastiness[0];
            temp_cost <= current_cost + cost_per_scoop;
            temp_ratio <= (temp_tastiness << 8) / temp_cost;
            selected_flavour <= 0;
            flavour_counter <= flavour_counter + 1;
          end else if (flavour_counter < 4) begin
            temp_tastiness <= current_tastiness + base_tastiness[flavour_counter];
            temp_cost <= current_cost + cost_per_scoop;
            temp_ratio <= (temp_tastiness << 8) / temp_cost;

            if (temp_ratio > best_ratio) begin
              best_ratio <= temp_ratio;
              selected_flavour <= flavour_counter;
            end

            flavour_counter <= flavour_counter + 1;
          end else begin
            flavour_counter <= 0;
            next_state = UPDATE_STATE;
          end
        end

        UPDATE_STATE: begin
          current_tastiness <= current_tastiness + base_tastiness[selected_flavour];
          current_cost <= current_cost + cost_per_scoop;

          if (current_scoop < num_scoops - 1) begin
            current_scoop <= current_scoop + 1;
            next_state = CALCULATE_SCOOP;
          end else begin
            next_state = DONE;
          end
        end

        DONE: begin
          max_ratio <= best_ratio;
          done <= 1;
          if (!start) begin
            done <= 0;
            next_state = IDLE;
          end
        end

        default: begin
          next_state = IDLE;
        end
      endcase
    end
  end

  // Default next state
  always @(*) begin
    next_state = state;
  end

endmodule