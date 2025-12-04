module turtle_tracker(
  input clk,
  input rst_n,
  input start,
  input [15:0] target_grid,
  input [7:0] cmd_0, cmd_1, cmd_2, cmd_3, cmd_4, cmd_5, cmd_6, cmd_7,
  input [2:0] num_cmds,
  output reg [6:0] min_time,
  output reg [6:0] max_time,
  output reg done,
  output reg valid_result
);

  typedef enum logic [3:0] { IDLE, INIT, FETCH_CMD, CLAMP_DISTANCE, MOVE, NEXT_CMD, CHECK_COVERAGE, CALC_MIN, CALC_MAX, FINISH } state_t;
  state_t current_state, next_state;

  reg [1:0] curr_row, curr_col;
  reg [6:0] first_mark_time [0:3][0:3];
  reg [6:0] last_mark_time [0:3][0:3];
  reg [6:0] time_step;
  reg [2:0] cmd_index;
  reg [1:0] curr_direction;
  reg [3:0] steps_left;
  reg [6:0] min_time_reg, max_time_reg;
  reg valid_reg;

  wire [7:0] cmd_array [0:7] = {cmd_0, cmd_1, cmd_2, cmd_3, cmd_4, cmd_5, cmd_6, cmd_7};
  wire [7:0] current_cmd = cmd_array[cmd_index];

  logic any_target_unmarked;
  logic [6:0] temp_min_time;
  logic [6:0] temp_max_time;

  always_comb begin
    any_target_unmarked = 0;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        if (target_grid[i*4 + j] && first_mark_time[i][j] == 7'b1111111) any_target_unmarked = 1;
      end
    end
  end

  always_comb begin
    temp_min_time = 0;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        if (target_grid[i*4 + j] && first_mark_time[i][j] > temp_min_time) begin
          temp_min_time = first_mark_time[i][j];
        end
      end
    end
  end

  always_comb begin
    temp_max_time = 7'b1111111;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        if (target_grid[i*4 + j] && last_mark_time[i][j] < temp_max_time) begin
          temp_max_time = last_mark_time[i][j];
        end
      end
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE    : if (start) next_state = INIT;
      INIT    : next_state = FETCH_CMD;
      FETCH_CMD: next_state = CLAMP_DISTANCE;
      CLAMP_DISTANCE: begin
        if (steps_left == 0) next_state = NEXT_CMD;
        else next_state = MOVE;
      end
      MOVE    : if (steps_left == 1) next_state = NEXT_CMD;
      NEXT_CMD: begin
        if (cmd_index < num_cmds) next_state = FETCH_CMD;
        else next_state = CHECK_COVERAGE;
      end
      CHECK_COVERAGE: begin
        if (any_target_unmarked) next_state = FINISH;
        else next_state = CALC_MIN;
      end
      CALC_MIN: next_state = CALC_MAX;
      CALC_MAX: next_state = FINISH;
      FINISH  : if (!start) next_state = IDLE;
      default : next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      valid_result <= 0;
      min_time <= 0;
      max_time <= 0;
      for (int i=0; i<4; i++) begin
        for (int j=0; j<4; j++) begin
          first_mark_time[i][j] <= 7'b1111111;
          last_mark_time[i][j] <= 0;
        end
      end
      curr_row <= 3;
      curr_col <= 0;
      time_step <= 0;
      cmd_index <= 0;
      steps_left <= 0;
      min_time_reg <= 0;
      max_time_reg <= 0;
      valid_reg <= 0;
      curr_direction <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done <= 0;
          valid_result <= 0;
        end
        INIT: begin
          curr_row <= 3;
          curr_col <= 0;
          time_step <= 0;
          cmd_index <= 0;
          first_mark_time[3][0] <= 0;
          last_mark_time[3][0] <= 0;
        end
        FETCH_CMD: begin
          curr_direction <= current_cmd[1:0];
        end
        CLAMP_DISTANCE: begin
          case (curr_direction)
            2'b00: steps_left <= (current_cmd[7:4] > curr_row) ? curr_row : current_cmd[7:4];
            2'b01: steps_left <= (current_cmd[7:4] > (3 - curr_row)) ? (3 - curr_row) : current_cmd[7:4];
            2'b10: steps_left <= (current_cmd[7:4] > curr_col) ? curr_col : current_cmd[7:4];
            2'b11: steps_left <= (current_cmd[7:4] > (3 - curr_col)) ? (3 - curr_col) : current_cmd[7:4];
          endcase
        end
        MOVE: begin
          time_step <= time_step + 1;
          steps_left <= steps_left - 1;
          case (curr_direction)
            2'b00: curr_row <= curr_row - 1;
            2'b01: curr_row <= curr_row + 1;
            2'b10: curr_col <= curr_col - 1;
            2'b11: curr_col <= curr_col + 1;
          endcase
          if (first_mark_time[curr_row][curr_col] == 7'b1111111) begin
            first_mark_time[curr_row][curr_col] <= time_step + 1;
          end
          last_mark_time[curr_row][curr_col] <= time_step + 1;
        end
        NEXT_CMD: cmd_index <= cmd_index + 1;
        CHECK_COVERAGE: valid_reg <= !any_target_unmarked;
        CALC_MIN: min_time_reg <= temp_min_time;
        CALC_MAX: max_time_reg <= temp_max_time;
        FINISH: begin
          done <= 1;
          valid_result <= valid_reg;
          if (valid_reg) begin
            min_time <= min_time_reg;
            max_time <= max_time_reg;
          end else begin
            min_time <= 7'b1111111;
            max_time <= 7'b1111111;
          end
        end
      endcase
    end
  end

endmodule