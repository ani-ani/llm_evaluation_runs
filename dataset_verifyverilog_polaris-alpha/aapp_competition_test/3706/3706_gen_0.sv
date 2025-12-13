module grid_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:3][0:3],
  output reg valid,
  output reg error,
  output reg [7:0] move_count
);

  // State encoding
  localparam IDLE          = 3'd0;
  localparam LOAD          = 3'd1;
  localparam FIND_ROW_MIN  = 3'd2;
  localparam SUB_ROW_MIN   = 3'd3;
  localparam FIND_COL_MIN  = 3'd4;
  localparam SUB_COL_MIN   = 3'd5;
  localparam CHECK_ZERO    = 3'd6;
  localparam DONE          = 3'd7;

  reg [2:0] state, next_state;

  // Internal storage for grid
  reg [7:0] grid_reg [0:3][0:3];

  // Row/column minima and sums (use 10 bits internal to avoid overflow)
  reg [7:0] row_min [0:3];
  reg [7:0] col_min [0:3];
  reg [9:0] row_sum;
  reg [9:0] col_sum;

  // Indices and counters
  reg [1:0] row_idx;
  reg [1:0] col_idx;

  // Timer to ensure completion within 20 cycles (not functionally required for correctness)
  reg [4:0] cycle_cnt;

  integer i, j;

  // Sequential state and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      valid      <= 1'b0;
      error      <= 1'b0;
      move_count <= 8'd0;
      row_idx    <= 2'd0;
      col_idx    <= 2'd0;
      row_sum    <= 10'd0;
      col_sum    <= 10'd0;
      cycle_cnt  <= 5'd0;
      for (i = 0; i < 4; i = i + 1) begin
        row_min[i] <= 8'd0;
        col_min[i] <= 8'd0;
        for (j = 0; j < 4; j = j + 1) begin
          grid_reg[i][j] <= 8'd0;
        end
      end
    end else begin
      state <= next_state;

      // cycle counter (for max-latency tracking, optional)
      if (state == IDLE) begin
        cycle_cnt <= 5'd0;
      end else if (!valid) begin
        cycle_cnt <= cycle_cnt + 5'd1;
      end

      case (state)
        IDLE: begin
          valid      <= 1'b0;
          error      <= 1'b0;
          move_count <= 8'd0;
          row_sum    <= 10'd0;
          col_sum    <= 10'd0;
          row_idx    <= 2'd0;
          col_idx    <= 2'd0;
        end

        LOAD: begin
          // Latch input grid
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              grid_reg[i][j] <= grid[i][j];
            end
          end
          row_sum <= 10'd0;
          col_sum <= 10'd0;
          row_idx <= 2'd0;
          col_idx <= 2'd0;
        end

        FIND_ROW_MIN: begin
          // Compute row minima combinationally via loop unrolling style
          // Per-row minima
          row_min[0] <= (grid_reg[0][0] <= grid_reg[0][1] ? grid_reg[0][0] : grid_reg[0][1]) <= (grid_reg[0][2] <= grid_reg[0][3] ? grid_reg[0][2] : grid_reg[0][3]) ? (grid_reg[0][0] <= grid_reg[0][1] ? grid_reg[0][0] : grid_reg[0][1]) : (grid_reg[0][2] <= grid_reg[0][3] ? grid_reg[0][2] : grid_reg[0][3]);
          row_min[1] <= (grid_reg[1][0] <= grid_reg[1][1] ? grid_reg[1][0] : grid_reg[1][1]) <= (grid_reg[1][2] <= grid_reg[1][3] ? grid_reg[1][2] : grid_reg[1][3]) ? (grid_reg[1][0] <= grid_reg[1][1] ? grid_reg[1][0] : grid_reg[1][1]) : (grid_reg[1][2] <= grid_reg[1][3] ? grid_reg[1][2] : grid_reg[1][3]);
          row_min[2] <= (grid_reg[2][0] <= grid_reg[2][1] ? grid_reg[2][0] : grid_reg[2][1]) <= (grid_reg[2][2] <= grid_reg[2][3] ? grid_reg[2][2] : grid_reg[2][3]) ? (grid_reg[2][0] <= grid_reg[2][1] ? grid_reg[2][0] : grid_reg[2][1]) : (grid_reg[2][2] <= grid_reg[2][3] ? grid_reg[2][2] : grid_reg[2][3]);
          row_min[3] <= (grid_reg[3][0] <= grid_reg[3][1] ? grid_reg[3][0] : grid_reg[3][1]) <= (grid_reg[3][2] <= grid_reg[3][3] ? grid_reg[3][2] : grid_reg[3][3]) ? (grid_reg[3][0] <= grid_reg[3][1] ? grid_reg[3][0] : grid_reg[3][1]) : (grid_reg[3][2] <= grid_reg[3][3] ? grid_reg[3][2] : grid_reg[3][3]);

          row_sum <= row_min[0] + row_min[1] + row_min[2] + row_min[3];
          row_idx <= 2'd0;
          col_idx <= 2'd0;
        end

        SUB_ROW_MIN: begin
          // Sequentially subtract row minima from each element: 16 cycles max
          grid_reg[row_idx][col_idx] <= grid_reg[row_idx][col_idx] - row_min[row_idx];

          if (col_idx == 2'd3) begin
            col_idx <= 2'd0;
            if (row_idx == 2'd3) begin
              row_idx <= 2'd0;
            end else begin
              row_idx <= row_idx + 2'd1;
            end
          end else begin
            col_idx <= col_idx + 2'd1;
          end
        end

        FIND_COL_MIN: begin
          // Compute column minima after row subtraction
          col_min[0] <= (grid_reg[0][0] <= grid_reg[1][0] ? grid_reg[0][0] : grid_reg[1][0]) <= (grid_reg[2][0] <= grid_reg[3][0] ? grid_reg[2][0] : grid_reg[3][0]) ? (grid_reg[0][0] <= grid_reg[1][0] ? grid_reg[0][0] : grid_reg[1][0]) : (grid_reg[2][0] <= grid_reg[3][0] ? grid_reg[2][0] : grid_reg[3][0]);
          col_min[1] <= (grid_reg[0][1] <= grid_reg[1][1] ? grid_reg[0][1] : grid_reg[1][1]) <= (grid_reg[2][1] <= grid_reg[3][1] ? grid_reg[2][1] : grid_reg[3][1]) ? (grid_reg[0][1] <= grid_reg[1][1] ? grid_reg[0][1] : grid_reg[1][1]) : (grid_reg[2][1] <= grid_reg[3][1] ? grid_reg[2][1] : grid_reg[3][1]);
          col_min[2] <= (grid_reg[0][2] <= grid_reg[1][2] ? grid_reg[0][2] : grid_reg[1][2]) <= (grid_reg[2][2] <= grid_reg[3][2] ? grid_reg[2][2] : grid_reg[3][2]) ? (grid_reg[0][2] <= grid_reg[1][2] ? grid_reg[0][2] : grid_reg[1][2]) : (grid_reg[2][2] <= grid_reg[3][2] ? grid_reg[2][2] : grid_reg[3][2]);
          col_min[3] <= (grid_reg[0][3] <= grid_reg[1][3] ? grid_reg[0][3] : grid_reg[1][3]) <= (grid_reg[2][3] <= grid_reg[3][3] ? grid_reg[2][3] : grid_reg[3][3]) ? (grid_reg[0][3] <= grid_reg[1][3] ? grid_reg[0][3] : grid_reg[1][3]) : (grid_reg[2][3] <= grid_reg[3][3] ? grid_reg[2][3] : grid_reg[3][3]);

          col_sum <= col_min[0] + col_min[1] + col_min[2] + col_min[3];
          row_idx <= 2'd0;
          col_idx <= 2'd0;
        end

        SUB_COL_MIN: begin
          // Sequentially subtract column minima from each element: 16 cycles max
          grid_reg[row_idx][col_idx] <= grid_reg[row_idx][col_idx] - col_min[col_idx];

          if (col_idx == 2'd3) begin
            col_idx <= 2'd0;
            if (row_idx == 2'd3) begin
              row_idx <= 2'd0;
            end else begin
              row_idx <= row_idx + 2'd1;
            end
          end else begin
            col_idx <= col_idx + 2'd1;
          end
        end

        CHECK_ZERO: begin
          // No register updates here besides flags in DONE
        end

        DONE: begin
          valid <= 1'b1;
          // move_count and error assigned in combinational block for DONE state
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic and outputs depending on state
  reg all_zero;
  integer r, c;

  always @(*) begin
    next_state = state;

    // Default stay
    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD;
        end
      end

      LOAD: begin
        next_state = FIND_ROW_MIN;
      end

      FIND_ROW_MIN: begin
        next_state = SUB_ROW_MIN;
      end

      SUB_ROW_MIN: begin
        if (row_idx == 2'd3 && col_idx == 2'd3) begin
          // Last update occurs this cycle; move on next cycle
          next_state = FIND_COL_MIN;
        end
      end

      FIND_COL_MIN: begin
        next_state = SUB_COL_MIN;
      end

      SUB_COL_MIN: begin
        if (row_idx == 2'd3 && col_idx == 2'd3) begin
          next_state = CHECK_ZERO;
        end
      end

      CHECK_ZERO: begin
        // Evaluate if all cells are zero
        all_zero = 1'b1;
        for (r = 0; r < 4; r = r + 1) begin
          for (c = 0; c < 4; c = c + 1) begin
            if (grid_reg[r][c] != 8'd0)
              all_zero = 1'b0;
          end
        end
        next_state = DONE;
      end

      DONE: begin
        // Wait in DONE until start deasserted then asserted again
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combinational logic for final outputs in DONE state
  always @(*) begin
    // Defaults (overridden in DONE)
    if (state == DONE) begin
      // Recompute all_zero here for reliability
      all_zero = 1'b1;
      for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 4; c = c + 1) begin
          if (grid_reg[r][c] != 8'd0)
            all_zero = 1'b0;
        end
      end

      if (all_zero) begin
        error = 1'b0;
        // Sum of row and column mins (truncate to 8 bits as required)
        move_count = (row_sum + col_sum)[7:0];
      end else begin
        error = 1'b1;
        move_count = 8'd0;
      end
    end
  end

endmodule