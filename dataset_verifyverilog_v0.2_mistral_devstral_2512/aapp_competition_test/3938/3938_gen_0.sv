module min_rect_cost (
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [7:0],
  output reg [5:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    BUILD_ADJ,
    SOLVE,
    DONE
  } state_t;

  state_t state;
  reg [7:0] black_rows;
  reg [7:0] black_cols;
  reg [7:0] row_count;
  reg [7:0] col_count;
  reg [7:0] row_index;
  reg [7:0] col_index;
  reg [7:0] flow;
  reg [7:0] temp;
  reg [7:0] i;
  reg [7:0] j;
  reg [7:0] k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      black_rows <= 0;
      black_cols <= 0;
      row_count <= 0;
      col_count <= 0;
      row_index <= 0;
      col_index <= 0;
      flow <= 0;
      temp <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PARSE;
            done <= 0;
            result <= 0;
            black_rows <= 0;
            black_cols <= 0;
            row_count <= 0;
            col_count <= 0;
            row_index <= 0;
            col_index <= 0;
            flow <= 0;
            temp <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
          end
        end
        PARSE: begin
          if (row_index < 8) begin
            if (col_index < 8) begin
              if (grid[row_index][col_index]) begin
                black_rows[row_index] <= 1;
                black_cols[col_index] <= 1;
              end
              col_index <= col_index + 1;
            end else begin
              col_index <= 0;
              row_index <= row_index + 1;
            end
          end else begin
            state <= BUILD_ADJ;
          end
        end
        BUILD_ADJ: begin
          row_count <= 0;
          col_count <= 0;
          for (i = 0; i < 8; i = i + 1) begin
            if (black_rows[i]) row_count <= row_count + 1;
            if (black_cols[i]) col_count <= col_count + 1;
          end
          state <= SOLVE;
        end
        SOLVE: begin
          if (i < 8) begin
            if (j < 8) begin
              if (black_rows[i] && black_cols[j]) begin
                temp <= temp + 1;
              end
              j <= j + 1;
            end else begin
              j <= 0;
              i <= i + 1;
            end
          end else begin
            flow <= temp;
            result <= (row_count < col_count) ? row_count : col_count;
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule