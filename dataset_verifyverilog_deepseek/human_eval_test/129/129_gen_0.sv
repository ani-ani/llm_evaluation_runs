module min_path(input clk, input rst_n, input start, input [3:0] grid [0:3][0:3], input [3:0] k, output reg [63:0] path, output reg done);
  typedef enum logic [1:0] { IDLE, SEARCH, COMPARE, DONE } state_t;
  state_t state, next_state;

  typedef struct packed {
    logic [1:0] row;
    logic [1:0] col;
    logic [15:0] visited;
    logic [1:0] dir;
  } stack_frame_t;

  stack_frame_t stack [0:15];
  logic [4:0] sp;
  reg [63:0] current_path;
  reg [63:0] min_path;

  reg [3:0] min_val;
  reg [1:0] min_row, min_col;

  wire lex_less = current_path < min_path;

  always_comb begin
    min_val = 16'hFFFF;
    min_row = 0;
    min_col = 0;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        if (grid[i][j] < min_val) begin
          min_val = grid[i][j];
          min_row = i;
          min_col = j;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      path <= 0;
      current_path <= 0;
      min_path <= {16{4'hF}};
      sp <= 0;
      state <= IDLE;
    end else begin
      case(state)
        IDLE: begin
          if (start) begin
            stack[0].row <= min_row;
            stack[0].col <= min_col;
            stack[0].visited <= (1 << (min_row*4 + min_col));
            stack[0].dir <= 0;
            sp <= 1;
            current_path <= {60'b0, grid[min_row][min_col]};
            min_path <= {16{4'hF}};
            done <= 0;
            state <= SEARCH;
          end
        end

        SEARCH: begin
          if (sp == 0) begin
            state <= DONE;
          end else if (sp == k) begin
            state <= COMPARE;
          end else begin
            stack_frame_t current = stack[sp-1];
            if (current.dir <= 3) begin
              logic [1:0] new_row = current.row;
              logic [1:0] new_col = current.col;
              case(current.dir)
                0: new_row = current.row - 1;
                1: new_col = current.col - 1;
                2: new_col = current.col + 1;
                3: new_row = current.row + 1;
              endcase
              logic valid = (new_row < 4) && (new_col < 4);
              logic visited = current.visited[new_row*4 + new_col];
              if (valid && !visited) begin
                stack[sp].row <= new_row;
                stack[sp].col <= new_col;
                stack[sp].visited <= current.visited | (1 << (new_row*4 + new_col));
                stack[sp].dir <= 0;
                sp <= sp + 1;
                current_path <= (current_path << 4) | grid[new_row][new_col];
                stack[sp-1].dir <= current.dir + 1;
              end else begin
                stack[sp-1].dir <= current.dir + 1;
              end
            end else begin
              sp <= sp - 1;
              current_path <= current_path >> 4;
            end
          end
        end

        COMPARE: begin
          if (lex_less) min_path <= current_path;
          sp <= sp - 1;
          current_path <= current_path >> 4;
          if (sp > 1) begin
            stack[sp-2].dir <= stack[sp-2].dir + 1;
            state <= SEARCH;
          end else state <= DONE;
        end

        DONE: begin
          path <= min_path;
          done <= 1;
        end
      endcase
    end
  end
endmodule