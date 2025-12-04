module matrix_recover(
  input clk,
  input rst_n,
  input [3:0] R,
  input [3:0] C,
  output reg [15:0] matrix,
  output reg valid
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam INIT       = 3'd1;
  localparam ROW_ADJUST = 3'd2;
  localparam COL_ADJUST = 3'd3;
  localparam VERIFY     = 3'd4;
  localparam DONE       = 3'd5;

  reg [2:0] state, next_state;

  // Internal matrix representation (row-major, bit [r][c])
  reg mat [0:3][0:3];

  // Counters / indices
  reg [3:0] cycle_cnt;
  reg [1:0] r_idx;
  reg [1:0] c_idx;

  // Parity wires
  reg [3:0] row_par;
  reg [3:0] col_par;

  integer i, j;

  // Compute current parities combinationally from mat
  always @* begin
    row_par = 4'b0;
    col_par = 4'b0;
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        row_par[i] = row_par[i] ^ mat[i][j];
        col_par[j] = col_par[j] ^ mat[i][j];
      end
    end
  end

  // Next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (rst_n) next_state = INIT;
      end
      INIT: begin
        next_state = ROW_ADJUST;
      end
      ROW_ADJUST: begin
        next_state = COL_ADJUST;
      end
      COL_ADJUST: begin
        next_state = VERIFY;
      end
      VERIFY: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 4'd0;
      r_idx      <= 2'd0;
      c_idx      <= 2'd0;
      valid      <= 1'b0;
      matrix     <= 16'd0;
      // Initialize mat to zeros
      for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
          mat[i][j] <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          cycle_cnt <= 4'd0;
          valid     <= 1'b0;
          matrix    <= 16'd0;
          // Prepare for initialization
          for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
              mat[i][j] <= 1'b0;
        end

        INIT: begin
          // Start with all ones for maximum ones
          for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
              mat[i][j] <= 1'b1;
          r_idx     <= 2'd0;
          c_idx     <= 2'd0;
          cycle_cnt <= 4'd1;
        end

        ROW_ADJUST: begin
          // Adjust each row to match its parity by optionally flipping one bit.
          // Priority: flip from LSB matrix bit (row3_col3) towards MSB to minimize binary value.
          // Implementation: one sweep controlled by indices.
          // We will perform a full combinational-style update in this cycle.
          for (i = 0; i < 4; i = i + 1) begin
            // Count ones in row i
            integer ones;
            ones = 0;
            for (j = 0; j < 4; j = j + 1)
              if (mat[i][j]) ones = ones + 1;

            // Current parity of row i (from ones) vs required R[i]
            if ((ones[0] ^ R[i]) == 1'b1) begin
              // Need to flip one bit in this row.
              // To minimize binary value while preserving as many ones as possible,
              // we flip a '1' starting from right-bottom priority (higher index j).
              for (j = 3; j >= 0; j = j - 1) begin
                if (mat[i][j]) begin
                  mat[i][j] <= 1'b0;
                  disable j_loop_row;
                end
              end
            end
            j_loop_row: ;
          end
          cycle_cnt <= cycle_cnt + 1'b1;
        end

        COL_ADJUST: begin
          // Adjust columns to match parity while trying to keep max ones and minimal value.
          // For each column j, if parity mismatches C[j], flip one bit in that column.
          // Prefer flipping from bottom row (row3) upward to minimize binary value.
          for (j = 0; j < 4; j = j + 1) begin
            integer col_ones;
            col_ones = 0;
            for (i = 0; i < 4; i = i + 1)
              if (mat[i][j]) col_ones = col_ones + 1;

            if ((col_ones[0] ^ C[j]) == 1'b1) begin
              // Need flip in column j
              for (i = 3; i >= 0; i = i - 1) begin
                if (mat[i][j]) begin
                  mat[i][j] <= 1'b0;
                  disable i_loop_col;
                end
              end
            end
            i_loop_col: ;
          end
          cycle_cnt <= cycle_cnt + 1'b1;
        end

        VERIFY: begin
          // Check final parities; if mismatch, declare invalid (-1)
          // row_par, col_par are combinational from mat
          if ((row_par == R) && (col_par == C)) begin
            valid <= 1'b1;
          end else begin
            valid <= 1'b0;
            // As -1 equivalent, set matrix to 0; keep mat internal as-is
            matrix <= 16'd0;
          end
          cycle_cnt <= cycle_cnt + 1'b1;
        end

        DONE: begin
          // Latch matrix output from mat once in DONE if valid not yet driven
          if (valid) begin
            matrix[15] <= mat[0][3];
            matrix[14] <= mat[0][2];
            matrix[13] <= mat[0][1];
            matrix[12] <= mat[0][0];
            matrix[11] <= mat[1][3];
            matrix[10] <= mat[1][2];
            matrix[9]  <= mat[1][1];
            matrix[8]  <= mat[1][0];
            matrix[7]  <= mat[2][3];
            matrix[6]  <= mat[2][2];
            matrix[5]  <= mat[2][1];
            matrix[4]  <= mat[2][0];
            matrix[3]  <= mat[3][3];
            matrix[2]  <= mat[3][2];
            matrix[1]  <= mat[3][1];
            matrix[0]  <= mat[3][0];
          end
          // Remain in DONE; outputs stable
          cycle_cnt <= cycle_cnt;
        end

        default: begin
          // Fallback
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
