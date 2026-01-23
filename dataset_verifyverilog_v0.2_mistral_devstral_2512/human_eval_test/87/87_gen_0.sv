module get_row (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_rows,
  input [2:0] row_lengths [0:7],
  input [7:0] lst [0:7][0:7],
  input [7:0] x,
  output reg [2:0] result_count,
  output reg [2:0] result_rows [0:7],
  output reg [2:0] result_cols [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SCAN_ROW,
    SCAN_COL,
    CHECK_MATCH,
    STORE_MATCH,
    SORT_RESULTS,
    OUTPUT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Temporary buffer for matches (max 8)
  reg [2:0] temp_rows [0:7];
  reg [2:0] temp_cols [0:7];
  reg [2:0] temp_count;

  // Counters for scanning
  reg [2:0] row_counter;
  reg [2:0] col_counter;

  // Sorting variables
  reg [2:0] sort_i;
  reg [2:0] sort_j;
  reg [2:0] swap_temp_row;
  reg [2:0] swap_temp_col;

  // Control signals
  reg match_found;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_count <= 0;
      done <= 0;
      row_counter <= 0;
      col_counter <= 0;
      temp_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SCAN_ROW;
      end
      SCAN_ROW: begin
        if (row_counter < num_rows) next_state = SCAN_COL;
        else next_state = SORT_RESULTS;
      end
      SCAN_COL: begin
        if (col_counter < row_lengths[row_counter]) next_state = CHECK_MATCH;
        else next_state = SCAN_ROW;
      end
      CHECK_MATCH: begin
        if (lst[row_counter][col_counter] == x) next_state = STORE_MATCH;
        else next_state = SCAN_COL;
      end
      STORE_MATCH: begin
        next_state = SCAN_COL;
      end
      SORT_RESULTS: begin
        if (sort_i < temp_count - 1) next_state = SORT_RESULTS;
        else next_state = OUTPUT;
      end
      OUTPUT: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row_counter <= 0;
      col_counter <= 0;
      temp_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      match_found <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            row_counter <= 0;
            col_counter <= 0;
            temp_count <= 0;
            sort_i <= 0;
            sort_j <= 0;
            done <= 0;
          end
        end
        SCAN_ROW: begin
          row_counter <= row_counter + 1;
          col_counter <= 0;
        end
        SCAN_COL: begin
          col_counter <= col_counter + 1;
        end
        CHECK_MATCH: begin
          match_found <= (lst[row_counter][col_counter] == x);
        end
        STORE_MATCH: begin
          if (temp_count < 8) begin
            temp_rows[temp_count] <= row_counter;
            temp_cols[temp_count] <= col_counter;
            temp_count <= temp_count + 1;
          end
        end
        SORT_RESULTS: begin
          if (sort_j < temp_count - sort_i - 1) begin
            if (temp_rows[sort_j] > temp_rows[sort_j + 1] ||
                (temp_rows[sort_j] == temp_rows[sort_j + 1] &&
                 temp_cols[sort_j] < temp_cols[sort_j + 1])) begin
              swap_temp_row = temp_rows[sort_j];
              swap_temp_col = temp_cols[sort_j];
              temp_rows[sort_j] = temp_rows[sort_j + 1];
              temp_cols[sort_j] = temp_cols[sort_j + 1];
              temp_rows[sort_j + 1] = swap_temp_row;
              temp_cols[sort_j + 1] = swap_temp_col;
            end
            sort_j <= sort_j + 1;
          end else begin
            sort_j <= 0;
            sort_i <= sort_i + 1;
          end
        end
        OUTPUT: begin
          result_count <= temp_count;
          for (int i = 0; i < 8; i = i + 1) begin
            result_rows[i] <= temp_rows[i];
            result_cols[i] <= temp_cols[i];
          end
          done <= 1;
        end
        DONE: begin
          if (!start) begin
            done <= 0;
          end
        end
        default: ;
      endcase
    end
  end

endmodule