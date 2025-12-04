module gl_bot_tracker(
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_data,
  input [7:0] cmd_str,
  input [2:0] grid_size,
  input [1:0] start_row,
  input [1:0] start_col,
  output reg [5:0] result_x,
  output reg done
);

  localparam [1:0] S_IDLE = 2'b00;
  localparam [1:0] S_SIMULATE = 2'b01;
  localparam [1:0] S_DONE = 2'b10;

  reg [1:0] state; 
  reg [1:0] row_reg, col_reg;
  reg [2:0] cmd_idx; 
  reg [5:0] step_cnt;
  reg [3:0] no_move_cnt;

  reg [127:0] valid_mem; 
  reg [5:0] step_mem [0:127];

  wire [6:0] current_state = {row_reg, col_reg, cmd_idx};
  wire [7:0] current_cmd = cmd_str >> (cmd_idx*8);
  wire move_left = (current_cmd == "<");
  wire move_right = (current_cmd == ">");
  wire move_up = (current_cmd == "^");
  wire move_down = (current_cmd == "v");

  wire [1:0] next_row = (move_up && (row_reg > '0)) ? row_reg - 1'b1 :
                        (move_down && (row_reg < (grid_size-1))) ? row_reg + 1'b1 :
                        row_reg;

  wire [1:0] next_col = (move_left && (col_reg > '0)) ? col_reg - 1'b1 :
                        (move_right && (col_reg < (grid_size-1))) ? col_reg + 1'b1 :
                        col_reg;

  wire position_valid = (next_row < grid_size) && (next_col < grid_size);
  wire grid_addr_valid = (next_row*8 + next_col) < 64;
  wire cell_passable = grid_addr_valid ? grid_data[next_row*8 + next_col] : 1'b0;
  wire valid_move = position_valid && cell_passable;
  wire moved = (move_left | move_right | move_up | move_down) && valid_move;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= S_IDLE;
      row_reg <= '0;
      col_reg <= '0;
      cmd_idx <= '0;
      step_cnt <= '0;
      no_move_cnt <= '0;
      result_x <= '0;
      done <= '0;
      valid_mem <= '0;
      for (int i=0; i<128; i=i+1)
        step_mem[i] <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= '0;
          result_x <= '0;
          if (start) begin
            row_reg <= start_row;
            col_reg <= start_col;
            cmd_idx <= '0;
            step_cnt <= '0;
            no_move_cnt <= '0;
            valid_mem <= '1;
            state <= S_SIMULATE;
          end
        end

        S_SIMULATE: begin
          if (valid_mem[current_state]) begin // Cycle detected
            result_x <= step_cnt - step_mem[current_state];
            done <= 1'b1;
            state <= S_DONE;
          end else if (no_move_cnt >= 7 && !moved) begin // Finite trail
            result_x <= 6'd1;
            done <= 1'b1;
            state <= S_DONE;
          end else if (step_cnt == 6'd63) begin // Max steps
            result_x <= 6'd1;
            done <= 1'b1;
            state <= S_DONE;
          end else begin
            step_cnt <= step_cnt + 1;
            if (moved) begin
              row_reg <= next_row;
              col_reg <= next_col;
              no_move_cnt <= '0;
            end else begin
              no_move_cnt <= no_move_cnt + 1;
            end
            if (!valid_mem[current_state]) begin
              valid_mem[current_state] <= 1'b1;
              step_mem[current_state] <= step_cnt;
            end
            cmd_idx <= (cmd_idx == 3'd7) ? 3'd0 : cmd_idx + 1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule