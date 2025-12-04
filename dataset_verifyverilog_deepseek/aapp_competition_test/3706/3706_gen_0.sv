module grid_solver(
  input clk, 
  input rst_n, 
  input start, 
  input [7:0] grid [0:3][0:3], 
  output reg valid, 
  output reg error, 
  output reg [7:0] move_count 
);

  // States
  localparam IDLE  = 3'h0;
  localparam ROW   = 3'h1;
  localparam COL   = 3'h2;
  localparam CHECK = 3'h3;
  localparam DONE  = 3'h4;
  
  reg [2:0] state;
  reg [7:0] grid_reg [0:3][0:3];
  reg [1:0] row_idx, col_idx;
  wire all_zero;
  
  // All-zero detection
  assign all_zero = (grid_reg[0][0] | grid_reg[0][1] | grid_reg[0][2] | grid_reg[0][3] |
                    grid_reg[1][0] | grid_reg[1][1] | grid_reg[1][2] | grid_reg[1][3] |
                    grid_reg[2][0] | grid_reg[2][1] | grid_reg[2][2] | grid_reg[2][3] |
                    grid_reg[3][0] | grid_reg[3][1] | grid_reg[3][2] | grid_reg[3][3]) == 8'h0;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      error <= 0;
      move_count <= 0;
      row_idx <= 0;
      col_idx <= 0;
      for (int i=0; i<4; i=i+1)
        for (int j=0; j<4; j=j+1)
          grid_reg[i][j] <= 0;
    end else begin
      case (state)
        IDLE: begin
          valid <= 0;
          if (start) begin
            // Load input grid
            for(int i=0; i<4; i=i+1)
              for(int j=0; j<4; j=j+1)
                grid_reg[i][j] <= grid[i][j];
            move_count <= 0;
            row_idx <= 0;
            state <= ROW;
          end
        end
        
        ROW: begin
          // Find row min
          reg [7:0] row_min = grid_reg[row_idx][0];
          if (grid_reg[row_idx][1] < row_min) row_min = grid_reg[row_idx][1];
          if (grid_reg[row_idx][2] < row_min) row_min = grid_reg[row_idx][2];
          if (grid_reg[row_idx][3] < row_min) row_min = grid_reg[row_idx][3];
          
          // Subtract min from row
          for (int j=0; j<4; j=j+1)
            grid_reg[row_idx][j] <= grid_reg[row_idx][j] - row_min;
          
          move_count <= move_count + row_min;
          
          if (row_idx == 3) begin
            col_idx <= 0;
            state <= COL;
          end else begin
            row_idx <= row_idx + 1;
          end
        end
        
        COL: begin
          // Find col min
          reg [7:0] col_min = grid_reg[0][col_idx];
          if (grid_reg[1][col_idx] < col_min) col_min = grid_reg[1][col_idx];
          if (grid_reg[2][col_idx] < col_min) col_min = grid_reg[2][col_idx];
          if (grid_reg[3][col_idx] < col_min) col_min = grid_reg[3][col_idx];
          
          // Subtract min from column
          for (int i=0; i<4; i=i+1)
            grid_reg[i][col_idx] <= grid_reg[i][col_idx] - col_min;
          
          move_count <= move_count + col_min;
          
          if (col_idx == 3) begin
            state <= CHECK;
          end else begin
            col_idx <= col_idx + 1;
          end
        end
        
        CHECK: begin
          valid <= 1;
          error <= ~all_zero;
          if (~all_zero) move_count <= 0;
          state <= DONE;
        end
        
        DONE: begin
          if (start) begin
            valid <= 0;
            for(int i=0; i<4; i=i+1)
              for(int j=0; j<4; j=j+1)
                grid_reg[i][j] <= grid[i][j];
            move_count <= 0;
            row_idx <= 0;
            state <= ROW;
          end
        end
      endcase
    end
  end
endmodule