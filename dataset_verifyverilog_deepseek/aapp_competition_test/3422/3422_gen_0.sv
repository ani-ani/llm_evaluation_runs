module treasure_map_solver (
  input clk, 
  input rst_n, 
  input start, 
  input [2:0] num_pieces, 
  input [3:0] piece_w [0:7], 
  input [3:0] piece_h [0:7], 
  input [3:0] piece_data [0:7][0:3][0:3], 
  output reg [2:0] map_w, 
  output reg [2:0] map_h, 
  output reg [3:0] solution_grid [0:7][0:7], 
  output reg [2:0] piece_grid [0:7][0:7], 
  output reg done
);

typedef enum {
  IDLE,
  INIT,
  ROTATE,
  ARRANGE,
  CHECK,
  FOUND,
  NOT_FOUND
} state_t;

state_t current_state, next_state;
reg [15:0] perm_count;
reg [15:0] rotate_count;
reg [2:0] current_perm [0:7];
reg [1:0] current_rotation [0:7];
reg [3:0] current_x, current_y;
reg [3:0] current_row_h;
reg [3:0] max_row_width;
reg [2:0] piece_index;
reg [3:0] map_w_temp, map_h_temp;
reg [3:0] temp_solution [0:7][0:7];
reg [2:0] temp_piece_grid [0:7][0:7];
reg [5:0] grid_counter;
reg treasure_found;
integer i, j, p, r;

function automatic [3:0] get_rw(input [3:0] w, input [3:0] h, input [1:0] rot);
  case (rot)
    2'b00, 2'b10: get_rw = w;
    default: get_rw = h;
  endcase
endfunction

function automatic [3:0] get_rh(input [3:0] w, input [3:0] h, input [1:0] rot);
  case (rot)
    2'b00, 2'b10: get_rh = h;
    default: get_rh = w;
  endcase
endfunction

function automatic [3:0] get_rotated_cell(input [3:0] data[0:3][0:3], input [1:0] rot, input [1:0] row, col);
  case (rot)
    2'b00: get_rotated_cell = data[row][col];
    2'b01: get_rotated_cell = data[col][3 - row];
    2'b10: get_rotated_cell = data[3 - row][3 - col];
    2'b11: get_rotated_cell = data[3 - col][row];
  endcase
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    map_w <= 0;
    map_h <= 0;
    for (i = 0; i < 8; i++) begin
      for (j = 0; j < 8; j++) begin
        solution_grid[i][j] <= 0;
        piece_grid[i][j] <= 0;
      end
    end
  end
  else begin
    case (current_state)
      IDLE: begin
        done <= 0;
        if (start) current_state <= INIT;
      end
      INIT: begin
        perm_count <= 0;
        rotate_count <= 0;
        for (i = 0; i < 8; i++) current_perm[i] <= i;
        current_state <= ROTATE;
      end
      ROTATE: begin
        if (rotate_count == (4 ** num_pieces) - 1) begin
          rotate_count <= 0;
          perm_count <= perm_count + 1;
          current_state <= (perm_count == 40319) ? NOT_FOUND : ROTATE;
        end
        else begin
          rotate_count <= rotate_count + 1;
          for (p = 0; p < 8; p++) current_rotation[p] <= (rotate_count >> (2 * p)) & 2'b11;
          current_state <= ARRANGE;
        end
      end
      ARRANGE: begin
        map_w_temp <= 0;
        map_h_temp <= 0;
        current_x <= 0;
        current_y <= 0;
        current_row_h <= 0;
        max_row_width <= 0;
        piece_index <= 0;
        for (i = 0; i < 8; i++) begin
          for (j = 0; j < 8; j++) begin
            temp_solution[i][j] <= 0;
            temp_piece_grid[i][j] <= 0;
          end
        end
        current_state <= (num_pieces == 0) ? CHECK : ARRANGE_LOOP;
      end
      ARRANGE_LOOP: begin
        if (piece_index < num_pieces) begin
          p = current_perm[piece_index];
          r = current_rotation[p];
          if (current_x + get_rw(piece_w[p], piece_h[p], r) > 8) begin
            if (current_x > max_row_width) max_row_width <= current_x;
            current_x <= 0;
            current_y <= current_y + current_row_h;
            current_row_h <= 0;
            if (current_y + get_rh(piece_w[p], piece_h[p], r) > 8) current_state <= ROTATE;
            else current_state <= PLACE_PIECE;
          end
          else begin
            current_state <= PLACE_PIECE;
          end
        end
        else begin
          map_w_temp <= (max_row_width > current_x) ? max_row_width : current_x;
          map_h_temp <= current_y + current_row_h;
          if (map_w_temp > 8 || map_h_temp > 8) current_state <= ROTATE;
          else current_state <= CHECK;
        end
      end
      PLACE_PIECE: begin
        for (i = 0; i < get_rh(piece_w[p], piece_h[p], r); i++) begin
          for (j = 0; j < get_rw(piece_w[p], piece_h[p], r); j++) begin
            temp_solution[current_y + i][current_x + j] <= 
              get_rotated_cell(piece_data[p], r, i, j);
            temp_piece_grid[current_y + i][current_x + j] <= p;
          end
        end
        if (get_rh(piece_w[p], piece_h[p], r) > current_row_h)
          current_row_h <= get_rh(piece_w[p], piece_h[p], r);
        current_x <= current_x + get_rw(piece_w[p], piece_h[p], r);
        piece_index <= piece_index + 1;
        current_state <= ARRANGE_LOOP;
      end
      CHECK: begin
        treasure_found <= 0;
        grid_counter <= 0;
        current_state <= CHECK_LOOP;
      end
      CHECK_LOOP: begin
        if (grid_counter < 64) begin
          i = grid_counter[5:3];
          j = grid_counter[2:0];
          if (i < map_h_temp && j < map_w_temp &&
              i > 0 && i < 7 && j > 0 && j < 7) begin
            if ((temp_solution[i][j] % 10) == (temp_solution[i-1][j] % 10) &&
                (temp_solution[i][j] % 10) == (temp_solution[i+1][j] % 10) &&
                (temp_solution[i][j] % 10) == (temp_solution[i][j-1] % 10) &&
                (temp_solution[i][j] % 10) == (temp_solution[i][j+1] % 10)) begin
              treasure_found <= 1;
            end
          end
          grid_counter <= grid_counter + 1;
        end
        else begin
          current_state <= treasure_found ? FOUND : ROTATE;
        end
      end
      FOUND: begin
        map_w <= map_w_temp;
        map_h <= map_h_temp;
        for (i = 0; i < 8; i++) begin
          for (j = 0; j < 8; j++) begin
            solution_grid[i][j] <= temp_solution[i][j];
            piece_grid[i][j] <= temp_piece_grid[i][j];
          end
        end
        done <= 1;
        current_state <= IDLE;
      end
      NOT_FOUND: begin
        map_w <= 0;
        map_h <= 0;
        for (i = 0; i < 8; i++) begin
          for (j = 0; j < 8; j++) begin
            solution_grid[i][j] <= 0;
            piece_grid[i][j] <= 0;
          end
        end
        done <= 1;
        current_state <= IDLE;
      end
    endcase
  end
end

endmodule