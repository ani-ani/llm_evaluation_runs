module sequence_counter (
  input clk,
  input rst_n,
  input start,
  input [4:0] m,
  input [2:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  localparam [3:0] IDLE = 4'b0001;
  localparam [3:0] INIT = 4'b0010;
  localparam [3:0] COMPUTE_ROW = 4'b0100;
  localparam [3:0] COMPUTE_COL = 4'b1000;
  localparam [3:0] UPDATE = 4'b1001;
  localparam [3:0] DONE = 4'b1010;

  reg [3:0] state;
  reg [4:0] row_i;
  reg [2:0] col_j;
  reg [15:0] T [0:16][0:4];
  reg [15:0] temp_val;
  reg [15:0] temp_val2;
  reg [4:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      row_i <= 0;
      col_j <= 0;
      result <= 0;
      done <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end
        INIT: begin
          // Initialize T matrix
          for (int i = 0; i <= 16; i = i + 1) begin
            for (int j = 0; j <= 4; j = j + 1) begin
              T[i][j] <= 0;
            end
          end
          // Base case: T[i][1] = i
          for (int i = 1; i <= 16; i = i + 1) begin
            T[i][1] <= i;
          end
          row_i <= 1;
          col_j <= 1;
          counter <= 0;
          state <= COMPUTE_ROW;
        end
        COMPUTE_ROW: begin
          if (col_j > n || row_i > m) begin
            state <= DONE;
          end else if (row_i > m) begin
            row_i <= 1;
            col_j <= col_j + 1;
            state <= COMPUTE_ROW;
          end else begin
            state <= COMPUTE_COL;
          end
        end
        COMPUTE_COL: begin
          temp_val <= T[row_i - 1][col_j];
          state <= UPDATE;
        end
        UPDATE: begin
          if (col_j > 1) begin
            temp_val2 <= T[row_i >> 1][col_j - 1];
            T[row_i][col_j] <= temp_val + temp_val2;
          end else begin
            T[row_i][col_j] <= temp_val;
          end
          row_i <= row_i + 1;
          state <= COMPUTE_ROW;
        end
        DONE: begin
          result <= T[m][n];
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule