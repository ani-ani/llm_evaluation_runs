module gas_station_optimizer(input clk, input rst_n, input start, input [3:0] n, input [15:0] g, input [15:0] d[0:7], input [15:0] c[0:7], output reg [31:0] total_cost, output reg error, output reg done);
  parameter N_STATIONS = 8;
  typedef enum logic [2:0] {IDLE=3'd0, INIT=3'd1, FIND_CHEAPER=3'd2, REFUEL=3'd3, UPDATE=3'd4, DONE=3'd5} state_t;
  reg [15:0] current_fuel;
  reg [2:0] current_pos;
  reg [31:0] total_cost_reg;
  reg error_reg;
  state_t state, next_state;
  reg [2:0] target_station;
  reg [15:0] target_distance;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_fuel <= 0;
      current_pos <= 0;
      total_cost_reg <= 0;
      error_reg <= 0;
      error <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      done <= (next_state == DONE);
      error <= error_reg;
      case (next_state)
        INIT: begin
          current_pos <= 0;
          current_fuel <= g;
          total_cost_reg <= 0;
          error_reg <= 0;
        end
        REFUEL: begin
          automatic logic [15:0] needed = target_distance - current_fuel;
          if (needed > (g - current_fuel)) begin
            error_reg <= 1'b1;
            total_cost_reg <= 32'hFFFFFFFF;
          end else begin
            total_cost_reg <= total_cost_reg + needed * c[current_pos];
            current_fuel <= current_fuel + needed;
          end
        end
        UPDATE: begin
          current_pos <= target_station;
          current_fuel <= current_fuel - target_distance;
        end
        DONE: begin
          total_cost <= error_reg ? 32'hFFFFFFFF : total_cost_reg;
          state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    target_station = current_pos;
    target_distance = 0;
    case (state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = FIND_CHEAPER;
      FIND_CHEAPER: begin
        automatic logic [15:0] min_cost = c[current_pos];
        automatic logic [2:0] temp_target = current_pos;
        automatic logic [15:0] temp_dist = 0;
        for (int i = current_pos+1; i < n; i++) begin
          automatic logic [15:0] delta = d[i] - d[current_pos];
          if ((delta <= current_fuel) && (c[i] < min_cost)) begin
            min_cost = c[i];
            temp_target = i;
            temp_dist = delta;
          end
        end
        if (temp_target != current_pos) begin
          target_station = temp_target;
          target_distance = temp_dist;
          next_state = UPDATE;
        end else if (current_pos == n-1) begin
          next_state = DONE;
        end else begin
          automatic logic [15:0] next_delta = d[current_pos+1] - d[current_pos];
          if (next_delta <= current_fuel) begin
            target_station = current_pos + 1;
            target_distance = next_delta;
            next_state = UPDATE;
          end else begin
            target_station = current_pos + 1;
            target_distance = next_delta;
            next_state = REFUEL;
          end
        end
      end
      REFUEL: next_state = UPDATE;
      UPDATE: next_state = (target_station == n-1) ? DONE : FIND_CHEAPER;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule