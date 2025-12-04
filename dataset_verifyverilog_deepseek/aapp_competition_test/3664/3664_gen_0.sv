module zamboni_controller(
  input clk,
  input rst_n,
  input start,
  input [2:0] r,
  input [2:0] c,
  input [2:0] start_i,
  input [2:0] start_j,
  input [3:0] n,
  output reg [4:0] grid [0:7][0:7],
  output reg done
);

  typedef enum logic [1:0] {S_IDLE, S_MOVE, S_UPDATE, S_FINISH} state_t;
  state_t state_reg, state_next;

  reg [2:0] current_i, current_i_next;
  reg [2:0] current_j, current_j_next;
  reg [1:0] direction_reg, direction_next;
  reg [4:0] color_reg, color_next;
  reg [4:0] step_size_reg, step_size_next;
  reg [3:0] iteration_cnt, iteration_next;
  reg [4:0] step_move_cnt, step_move_next;
  reg done_next;

  always_comb begin
    state_next = state_reg;
    current_i_next = current_i;
    current_j_next = current_j;
    direction_next = direction_reg;
    color_next = color_reg;
    step_size_next = step_size_reg;
    iteration_next = iteration_cnt;
    step_move_next = step_move_cnt;
    done_next = done;

    case (state_reg)
      S_IDLE: begin
        if (start) begin
          current_i_next = start_i - 3'd1;
          current_j_next = start_j - 3'd1;
          done_next = 1'b0;
          if (n == 4'd0) begin
            state_next = S_FINISH;
          end else begin
            state_next = S_MOVE;
            direction_next = 2'b00;
            color_next = 5'd2;
            step_size_next = 5'd1;
            iteration_next = 4'd0;
            step_move_next = 5'd0;
          end
        end
      end

      S_MOVE: begin
        if (step_move_cnt < step_size_reg) begin
          step_move_next = step_move_cnt + 5'd1;
          case (direction_reg)
            2'b00: current_i_next = current_i - 3'd1;
            2'b01: current_j_next = current_j + 3'd1;
            2'b10: current_i_next = current_i + 3'd1;
            2'b11: current_j_next = current_j - 3'd1;
          endcase
        end else begin
          state_next = S_UPDATE;
          step_move_next = 5'd0;
        end
      end

      S_UPDATE: begin
        direction_next = direction_reg + 2'd1;

        if (color_reg == 5'd27)
          color_next = 5'd2;
        else
          color_next = color_reg + 5'd1;

        step_size_next = step_size_reg + 5'd1;
        iteration_next = iteration_cnt + 4'd1;

        if (iteration_next == n)
          state_next = S_FINISH;
        else
          state_next = S_MOVE;
      end

      S_FINISH: begin
        done_next = 1'b1;
        state_next = S_FINISH;
      end

      default: state_next = S_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      state_reg <= S_IDLE;
      current_i <= 3'b0;
      current_j <= 3'b0;
      direction_reg <= 2'b00;
      color_reg <= 5'd2;
      step_size_reg <= 5'd1;
      iteration_cnt <= 4'd0;
      step_move_cnt <= 5'd0;
      
      for (int i=0; i<8; i++) begin
        for (int j=0; j<8; j++) begin
          grid[i][j] <= 5'd0;
        end
      end
    end else begin
      state_reg <= state_next;
      current_i <= current_i_next;
      current_j <= current_j_next;
      direction_reg <= direction_next;
      color_reg <= color_next;
      step_size_reg <= step_size_next;
      iteration_cnt <= iteration_next;
      step_move_cnt <= step_move_next;
      done <= done_next;

      case (state_reg)
        S_MOVE: begin
          if (step_move_cnt < step_size_reg) begin
            grid[current_i][current_j] <= color_reg;
          end
        end

        S_FINISH: begin
          grid[current_i][current_j] <= 5'd1;
        end
      endcase
    end
  end
endmodule