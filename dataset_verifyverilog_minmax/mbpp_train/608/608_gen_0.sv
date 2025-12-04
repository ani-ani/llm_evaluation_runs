module bell_number (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  output reg [5:0] bell_out,
  output reg done
);

  // 6x6 register array for DP
  reg [5:0] bell [0:5][0:5];

  // FSM and iteration state
  localparam IDLE = 2'b00;
  localparam INIT_ROW = 2'b01;
  localparam COMPUTE_COL = 2'b10;
  localparam FINISH = 2'b11;

  reg [1:0] state, next_state;
  reg [2:0] i_row;   // current row index
  reg [2:0] j_col;   // current column index
  reg [2:0] n_reg;   // captured start value

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_ROW;
      end
      INIT_ROW: begin
        next_state = COMPUTE_COL;
      end
      COMPUTE_COL: begin
        if (i_row < n_reg) begin
          // When j reaches i, finished current row
          if (j_col == i_row) next_state = INIT_ROW;
        end else begin
          next_state = FINISH;
        end
      end
      FINISH: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i_row <= 3'b0;
      j_col <= 3'b0;
      n_reg <= 3'b0;
      done <= 1'b0;
      bell_out <= 6'b0;
      // Clear array (not strictly required but helps simulation)
      for (integer r = 0; r < 6; r = r + 1) begin
        for (integer c = 0; c < 6; c = c + 1) begin
          bell[r][c] <= 6'b0;
        end
      end
    end else begin
      state <= next_state;

      case (next_state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            i_row <= 3'b0;
            j_col <= 3'b0;
            done <= 1'b0;
          end
        end

        INIT_ROW: begin
          if (i_row == 0) begin
            // Base: bell[0][0] = 1
            bell[0][0] <= 6'b000001;
            i_row <= 3'b1; // move to first data row
            j_col <= 3'b0;
          end else if (i_row <= n_reg) begin
            // bell[i][0] = bell[i-1][i-1]
            bell[i_row][0] <= bell[i_row - 1][i_row - 1];
            i_row <= i_row + 1;       // next row
            j_col <= 3'b1;            // start columns from 1
          end
        end

        COMPUTE_COL: begin
          if (i_row <= n_reg) begin
            // bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
            if (j_col <= i_row) begin
              bell[i_row][j_col] <= bell[i_row - 1][j_col - 1] + bell[i_row][j_col - 1];
              j_col <= j_col + 1;
            end
          end
        end

        FINISH: begin
          // bell_out = bell[n][0] (the sum for row n)
          bell_out <= bell[n_reg][0];
          done <= 1'b1;
        end

        default: begin
          // No action
        end
      endcase
    end
  end

endmodule
