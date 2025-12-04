module button_assigner(
  input clk, rst_n, start,
  input [15:0] grid,
  output reg [2:0] k,
  output reg done
);

  typedef enum logic [1:0] {IDLE, FIND_MATCH, DONE} state_t;
  state_t state;
  
  reg [3:0] grid_2d[0:3];
  reg [3:0] col_assigned;
  reg [1:0] curr_row;
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      k <= 0;
      col_assigned <= 0;
      curr_row <= 0;
      grid_2d[0] <= 0;
      grid_2d[1] <= 0;
      grid_2d[2] <= 0;
      grid_2d[3] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            grid_2d[3] <= grid[3:0];   
            grid_2d[2] <= grid[7:4];
            grid_2d[1] <= grid[11:8];
            grid_2d[0] <= grid[15:12];
            col_assigned <= 0;
            curr_row <= 0;
            k <= 0;
            state <= FIND_MATCH;
          end
        end
        
        FIND_MATCH: begin
          if (curr_row < 4) begin
            if (grid_2d[curr_row][0] && ~col_assigned[0]) begin
              col_assigned[0] <= 1'b1;
              k <= k + 1'b1;
            end else if (grid_2d[curr_row][1] && ~col_assigned[1]) begin
              col_assigned[1] <= 1'b1;
              k <= k + 1'b1;
            end else if (grid_2d[curr_row][2] && ~col_assigned[2]) begin
              col_assigned[2] <= 1'b1;
              k <= k + 1'b1;
            end else if (grid_2d[curr_row][3] && ~col_assigned[3]) begin
              col_assigned[3] <= 1'b1;
              k <= k + 1'b1;
            end
            curr_row <= curr_row + 1'b1;
          end else begin
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (~start) state <= IDLE;
        end
      endcase
    end
  end
endmodule