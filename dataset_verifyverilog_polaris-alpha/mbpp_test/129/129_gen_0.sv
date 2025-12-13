module magic_square_checker(
  input  logic              clk,
  input  logic              rst_n,      // active-low synchronous reset
  input  logic              start,      // pulse high to begin calculation
  input  logic [1:0]        size,       // 2'b11 for 4x4, 2'b10 for 3x3
  input  logic [7:0]        matrix [0:3][0:3], // 4x4 matrix elements
  output logic              result,     // 1 if magic square, 0 otherwise
  output logic              valid       // high when calculation complete
);

  // Internal cycle counter (0-15)
  logic [3:0] cycle_cnt;

  // Row, column and diagonal sums (enough width for max 4 * 255 = 1020)
  logic [9:0] row_sum   [0:3];
  logic [9:0] col_sum   [0:3];
  logic [9:0] diag_sum  [0:1]; // [0]: main diag, [1]: anti diag

  // Latched size and control
  logic [1:0] size_reg;
  logic       busy;

  // Synchronous control and datapath
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cycle_cnt <= 4'd0;
      size_reg  <= 2'b00;
      busy      <= 1'b0;
      result    <= 1'b0;
      valid     <= 1'b0;
      // Clear sums
      row_sum[0] <= 10'd0; row_sum[1] <= 10'd0; row_sum[2] <= 10'd0; row_sum[3] <= 10'd0;
      col_sum[0] <= 10'd0; col_sum[1] <= 10'd0; col_sum[2] <= 10'd0; col_sum[3] <= 10'd0;
      diag_sum[0] <= 10'd0; diag_sum[1] <= 10'd0;
    end else begin
      valid <= 1'b0; // default

      // Start pulse handling
      if (start && !busy) begin
        // Latch size
        size_reg  <= size;
        busy      <= 1'b1;
        cycle_cnt <= 4'd0;

        // Initialize sums to zero
        row_sum[0] <= 10'd0; row_sum[1] <= 10'd0; row_sum[2] <= 10'd0; row_sum[3] <= 10'd0;
        col_sum[0] <= 10'd0; col_sum[1] <= 10'd0; col_sum[2] <= 10'd0; col_sum[3] <= 10'd0;
        diag_sum[0] <= 10'd0; diag_sum[1] <= 10'd0;
        result <= 1'b0;
      end else if (busy) begin
        // Sequential operation over 16 cycles
        case (cycle_cnt)
          // Row sums: 4 cycles (0-3), one row per cycle
          4'd0: begin
            row_sum[0] <= matrix[0][0] + matrix[0][1] + matrix[0][2] + matrix[0][3];
          end
          4'd1: begin
            row_sum[1] <= matrix[1][0] + matrix[1][1] + matrix[1][2] + matrix[1][3];
          end
          4'd2: begin
            row_sum[2] <= matrix[2][0] + matrix[2][1] + matrix[2][2] + matrix[2][3];
          end
          4'd3: begin
            row_sum[3] <= matrix[3][0] + matrix[3][1] + matrix[3][2] + matrix[3][3];
          end

          // Column sums: 4 cycles (4-7), one column per cycle
          4'd4: begin
            col_sum[0] <= matrix[0][0] + matrix[1][0] + matrix[2][0] + matrix[3][0];
          end
          4'd5: begin
            col_sum[1] <= matrix[0][1] + matrix[1][1] + matrix[2][1] + matrix[3][1];
          end
          4'd6: begin
            col_sum[2] <= matrix[0][2] + matrix[1][2] + matrix[2][2] + matrix[3][2];
          end
          4'd7: begin
            col_sum[3] <= matrix[0][3] + matrix[1][3] + matrix[2][3] + matrix[3][3];
          end

          // Diagonals: 2 cycles (8-9)
          4'd8: begin
            diag_sum[0] <= matrix[0][0] + matrix[1][1] + matrix[2][2] + matrix[3][3];
          end
          4'd9: begin
            diag_sum[1] <= matrix[0][3] + matrix[1][2] + matrix[2][1] + matrix[3][0];
          end

          // Comparisons: 6 cycles (10-15)
          // Final result computed and valid asserted at cycle 15
          4'd15: begin
            logic [9:0] target;
            logic       ok;

            // Select target based on size
            // For 3x3 (2'b10): use row_sum[0]
            // For 4x4 (2'b11): use row_sum[0]
            target = row_sum[0];
            ok     = 1'b1;

            if (size_reg == 2'b10) begin
              // 3x3: check rows 0-2, cols 0-2, and both diags (using first 3 elements)
              if (row_sum[1] != target) ok = 1'b0;
              if (row_sum[2] != target) ok = 1'b0;

              if (col_sum[0] != target) ok = 1'b0;
              if (col_sum[1] != target) ok = 1'b0;
              if (col_sum[2] != target) ok = 1'b0;

              // Rebuild effective 3x3 diagonals from stored values
              // Stored diag_sum includes 4th term (matrix[3][3] or matrix[3][0]/[0][3]),
              // so recompute here explicitly for correctness.
              if ((matrix[0][0] + matrix[1][1] + matrix[2][2]) != target) ok = 1'b0;
              if ((matrix[0][2] + matrix[1][1] + matrix[2][0]) != target) ok = 1'b0;

            end else if (size_reg == 2'b11) begin
              // 4x4: check all rows, cols, and both diags directly
              if (row_sum[1] != target) ok = 1'b0;
              if (row_sum[2] != target) ok = 1'b0;
              if (row_sum[3] != target) ok = 1'b0;

              if (col_sum[0] != target) ok = 1'b0;
              if (col_sum[1] != target) ok = 1'b0;
              if (col_sum[2] != target) ok = 1'b0;
              if (col_sum[3] != target) ok = 1'b0;

              if (diag_sum[0] != target) ok = 1'b0;
              if (diag_sum[1] != target) ok = 1'b0;
            end else begin
              // Unsupported size -> not magic
              ok = 1'b0;
            end

            result <= ok;
            valid  <= 1'b1;
            busy   <= 1'b0;
          end

          default: begin
            // No operation for intermediate compare cycles (10-14) as per
            // fixed 16-cycle latency; hardware already computed sums.
          end
        endcase

        // Increment cycle counter while busy, wrap is irrelevant as busy will clear
        cycle_cnt <= cycle_cnt + 4'd1;
      end
    end
  end

endmodule