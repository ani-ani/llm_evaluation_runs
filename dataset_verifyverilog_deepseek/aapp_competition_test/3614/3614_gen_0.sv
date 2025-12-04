module grasshopper_path(
  input clk, 
  input rst_n, 
  input start, 
  input [15:0] grid [0:15], 
  input [1:0] init_row, 
  input [1:0] init_col, 
  output reg [3:0] max_flowers, 
  output reg done
);

  typedef enum logic [1:0] {IDLE, INIT, EXPLORE, DONE} state_t;
  state_t current_state;

  typedef struct packed {
    logic [1:0] row;
    logic [1:0] col;
    logic [2:0] move_idx;
    logic [3:0] depth;
  } stack_entry_t;

  localparam signed [2:0] dr [0:7] = '{1, 1, 2, 2, -1, -1, -2, -2};
  localparam signed [2:0] dc [0:7] = '{2, -2, 1, -1, 2, -2, 1, -1};

  reg [15:0] grid_reg [0:3][0:3];
  reg [3:0] sp;
  reg visited [0:3][0:3];
  stack_entry_t stack [0:15];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_flowers <= 4'd0;
      done <= 1'b0;
      sp <= 0;
      for (int i=0; i<4; i++) begin
        for (int j=0; j<4; j++) begin
          visited[i][j] <= 0;
          grid_reg[i][j] <= 0;
        end
      end
      stack <= '{default:0};
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) current_state <= INIT;
        end

        INIT: begin
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              grid_reg[i][j] <= grid[i*4 + j];
              visited[i][j] <= 0;
            end
          end
          stack[0].row <= init_row;
          stack[0].col <= init_col;
          stack[0].move_idx <= 0;
          stack[0].depth <= 4'd1;
          sp <= 1;
          visited[init_row][init_col] <= 1;
          max_flowers <= 4'd1;
          current_state <= EXPLORE;
        end

        EXPLORE: begin
          if (sp == 0) begin
            current_state <= DONE;
            done <= 1'b1;
          end else begin
            stack_entry_t curr = stack[sp-1];

            if (curr.move_idx < 8) begin
              automatic signed [3:0] nr = $signed({2'b0, curr.row}) + $signed(dr[curr.move_idx]);
              automatic signed [3:0] nc = $signed({2'b0, curr.col}) + $signed(dc[curr.move_idx]);
              automatic logic valid_move = (nr >=0) && (nr <4) && (nc >=0) && (nc <4);

              if (valid_move) begin
                automatic logic [1:0] new_r = nr[1:0];
                automatic logic [1:0] new_c = nc[1:0];

                if (!visited[new_r][new_c] && 
                    (grid_reg[new_r][new_c] > grid_reg[curr.row][curr.col])) begin
                  stack[sp].row <= new_r;
                  stack[sp].col <= new_c;
                  stack[sp].move_idx <= 0;
                  stack[sp].depth <= curr.depth + 1;
                  visited[new_r][new_c] <= 1;
                  sp <= sp + 1;
                  if (curr.depth + 1 > max_flowers)
                    max_flowers <= curr.depth + 1;
                end
              end
              stack[sp-1].move_idx <= curr.move_idx + 1;
            end else begin
              visited[curr.row][curr.col] <= 0;
              sp <= sp - 1;
            end
          end
        end

        DONE: begin
          if (!start) current_state <= IDLE;
        end
      endcase
    end
  end

endmodule