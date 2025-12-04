module bell_number(
  input        clk,
  input        rst_n,
  input        start,
  input  [2:0] n,
  output reg [5:0] bell_out,
  output reg       done
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam INIT_ROW    = 2'b01;
  localparam COMPUTE_COL = 2'b10;
  localparam FINISH      = 2'b11;

  reg [1:0] state, next_state;

  // DP table: bell[i][j], 0 <= i,j <= 5, 6-bit each
  reg [5:0] bell[0:5][0:5];

  // Indices
  reg [2:0] i, j;          // current row/column
  reg [2:0] i_next, j_next;

  // Latched input n to keep stable during computation
  reg [2:0] n_reg;

  // Start pulse edge-detect
  reg start_d;
  wire start_pulse = start & ~start_d;

  integer r, c;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      start_d   <= 1'b0;
      n_reg     <= 3'd0;
      bell_out  <= 6'd0;
      done      <= 1'b0;
      i         <= 3'd0;
      j         <= 3'd0;
      // Clear table
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          bell[r][c] <= 6'd0;
        end
      end
    end else begin
      start_d <= start;
      state   <= next_state;
      i       <= i_next;
      j       <= j_next;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Latch n and initialize table
            n_reg <= (n > 3'd5) ? 3'd5 : n; // clamp for safety

            // Clear table
            for (r = 0; r < 6; r = r + 1) begin
              for (c = 0; c < 6; c = c + 1) begin
                bell[r][c] <= 6'd0;
              end
            end

            // Initialize bell[0][0] = 1
            bell[0][0] <= 6'd1;
          end
        end

        INIT_ROW: begin
          // Set bell[i][0] = bell[i-1][i-1]
          bell[i][0] <= bell[i-1][i-1];
        end

        COMPUTE_COL: begin
          // bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
          bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
        end

        FINISH: begin
          done <= 1'b1;
          // bell[n_reg][0] holds the Bell number for n_reg
          bell_out <= bell[n_reg][0];
        end

        default: begin
          // No default behavior
        end
      endcase
    end
  end

  // Next-state and index logic
  always @* begin
    next_state = state;
    i_next     = i;
    j_next     = j;

    case (state)
      IDLE: begin
        // Wait for start pulse to kick off computation
        if (start_pulse) begin
          if (n == 3'd0) begin
            // For n=0, result is immediately 1 (bell[0][0])
            next_state = FINISH;
            i_next     = 3'd0;
            j_next     = 3'd0;
          end else begin
            // Begin with first row i=1
            next_state = INIT_ROW;
            i_next     = 3'd1;
            j_next     = 3'd0;
          end
        end
      end

      INIT_ROW: begin
        // After setting bell[i][0], move to compute columns of this row
        if (i > n_reg) begin
          // Should not happen; safety
          next_state = FINISH;
        end else begin
          // Start computing from j=1
          next_state = COMPUTE_COL;
          j_next     = 3'd1;
        end
      end

      COMPUTE_COL: begin
        if (j < i) begin
          // More columns to compute in this row
          next_state = COMPUTE_COL;
          j_next     = j + 3'd1;
        end else begin
          // Finished all columns for this row (last computed at j==i)
          if (i < n_reg) begin
            // Move to next row
            next_state = INIT_ROW;
            i_next     = i + 3'd1;
            j_next     = 3'd0;
          end else begin
            // All rows up to n_reg done
            next_state = FINISH;
          end
        end
      end

      FINISH: begin
        // Hold result until next start
        if (start_pulse) begin
          // Start a new computation
          if (n == 3'd0) begin
            next_state = FINISH;
            i_next     = 3'd0;
            j_next     = 3'd0;
          end else begin
            next_state = INIT_ROW;
            i_next     = 3'd1;
            j_next     = 3'd0;
          end
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule