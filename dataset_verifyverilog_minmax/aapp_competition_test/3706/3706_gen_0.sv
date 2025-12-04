module grid_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:3][0:3],
  output reg valid,
  output reg error,
  output reg [7:0] move_count
);

  // Internal grid storage
  logic [7:0] grid_r [0:3][0:3];

  // State machine
  typedef enum logic [2:0] {
    IDLE   = 3'b000,
    S_R1   = 3'b001,
    S_R2   = 3'b010,
    S_R3   = 3'b011,
    S_R4   = 3'b100,
    S_C1   = 3'b101,
    S_C2   = 3'b110,
    S_C3   = 3'b111
  } state_t;

  state_t state, next_state;

  // Row and column minima
  logic [7:0] row_min [0:3];
  logic [7:0] col_min [0:3];

  // Fast zero-check on current grid
  logic grid_nonzero;
  always @* begin
    grid_nonzero = 1'b0;
    for (int i = 0; i < 4; i = i + 1) begin
      for (int j = 0; j < 4; j = j + 1) begin
        if (grid_r[i][j] != 8'h00) grid_nonzero = 1'b1;
      end
    end
  end

  // State transition and compute on clock
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      valid       <= 1'b0;
      error       <= 1'b0;
      move_count  <= 8'h00;
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) grid_r[i][j] <= 8'h00;
      end
      for (int k = 0; k < 4; k++) begin
        row_min[k] <= 8'h00;
        col_min[k] <= 8'h00;
      end
    end else begin
      case (state)
        IDLE: begin
          valid <= 1'b0;
          error <= 1'b0;
          if (start) begin
            // Capture the input grid
            for (int i = 0; i < 4; i = i + 1) begin
              for (int j = 0; j < 4; j = j + 1) begin
                grid_r[i][j] <= grid[i][j];
              end
            end
            state <= S_R1;
          end
        end

        S_R1: begin
          // Compute row 0 minimum
          row_min[0] <= grid_r[0][0];
          for (int j = 1; j < 4; j = j + 1) begin
            if (grid_r[0][j] < row_min[0]) row_min[0] <= grid_r[0][j];
          end
          state <= S_R2;
        end

        S_R2: begin
          // Subtract row 0 min and compute row 1 min
          for (int j = 0; j < 4; j = j + 1) begin
            grid_r[0][j] <= grid_r[0][j] - row_min[0];
          end
          row_min[1] <= grid_r[1][0];
          for (int j = 1; j < 4; j = j + 1) begin
            if (grid_r[1][j] < row_min[1]) row_min[1] <= grid_r[1][j];
          end
          state <= S_R3;
        end

        S_R3: begin
          // Subtract row 1 min and compute row 2 min
          for (int j = 0; j < 4; j = j + 1) begin
            grid_r[1][j] <= grid_r[1][j] - row_min[1];
          end
          row_min[2] <= grid_r[2][0];
          for (int j = 1; j < 4; j = j + 1) begin
            if (grid_r[2][j] < row_min[2]) row_min[2] <= grid_r[2][j];
          end
          state <= S_R4;
        end

        S_R4: begin
          // Subtract row 2 min and compute row 3 min
          for (int j = 0; j < 4; j = j + 1) begin
            grid_r[2][j] <= grid_r[2][j] - row_min[2];
          end
          row_min[3] <= grid_r[3][0];
          for (int j = 1; j < 4; j = j + 1) begin
            if (grid_r[3][j] < row_min[3]) row_min[3] <= grid_r[3][j];
          end
          state <= S_C1;
        end

        S_C1: begin
          // Subtract row 3 min and compute column 0 min
          for (int j = 0; j < 4; j = j + 1) begin
            grid_r[3][j] <= grid_r[3][j] - row_min[3];
          end
          col_min[0] <= grid_r[0][0];
          for (int i = 1; i < 4; i = i + 1) begin
            if (grid_r[i][0] < col_min[0]) col_min[0] <= grid_r[i][0];
          end
          state <= S_C2;
        end

        S_C2: begin
          // Subtract col 0 min and compute col 1 min
          for (int i = 0; i < 4; i = i + 1) begin
            grid_r[i][0] <= grid_r[i][0] - col_min[0];
          end
          col_min[1] <= grid_r[0][1];
          for (int i = 1; i < 4; i = i + 1) begin
            if (grid_r[i][1] < col_min[1]) col_min[1] <= grid_r[i][1];
          end
          state <= S_C3;
        end

        default: begin // S_C3
          // Subtract col 1 min and compute col 2 and col 3 mins in one cycle
          for (int i = 0; i < 4; i = i + 1) begin
            grid_r[i][1] <= grid_r[i][1] - col_min[1];
          end
          col_min[2] <= grid_r[0][2];
          col_min[3] <= grid_r[0][3];
          for (int i = 1; i < 4; i = i + 1) begin
            if (grid_r[i][2] < col_min[2]) col_min[2] <= grid_r[i][2];
            if (grid_r[i][3] < col_min[3]) col_min[3] <= grid_r[i][3];
          end

          // Subtract col 2 and col 3 mins and form final result
          for (int i = 0; i < 4; i = i + 1) begin
            grid_r[i][2] <= grid_r[i][2] - col_min[2];
            grid_r[i][3] <= grid_r[i][3] - col_min[3];
          end

          // Determine if the grid is fully zero
          if (grid_nonzero) begin
            error      <= 1'b1;
            move_count <= 8'h00;
          end else begin
            error      <= 1'b0;
            move_count <= (row_min[0] + row_min[1] + row_min[2] + row_min[3]) +
                          (col_min[0] + col_min[1] + col_min[2] + col_min[3]);
          end
          valid <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule