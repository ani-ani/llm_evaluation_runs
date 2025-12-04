module superdoku_solver(
  input clk,  // Clock
  input rst_n,  // Active-low reset
  input start,  // Start computation (pulse high)
  input [2:0] k,  // Number of pre-filled rows (0-4)
  input [31:0] grid_in,  // Flattened 4x4 grid (FOR RECEPTION ONLY)
  output reg valid_out,  // 1 = solution exists
  output reg [31:0] grid_out,  // Flattened 4x4 solution
  output reg done  // High when computation completes
);

  // Internal signals
  reg [7:0] row0_i, row1_i, row2_i, row3_i;  // received rows (8-bit each, 2 bits per cell)
  reg [7:0] s0, s1, s2, s3;                  // shifted rows for the solution (post-validity)
  reg [2:0] cycle_cnt;                       // 0..3 pipeline cycle
  reg dup_reg;                               // duplicates detected (1 cycle delayed)
  reg valid_reg;                             // 1 if no duplicates found
  reg [1:0] col0v [0:3], col1v [0:3], col2v [0:3], col3v [0:3];  // extracted column vectors per cycle
  integer i;

  // Helper: extract 2-bit value of a cell from a row register
  function [1:0] cell;
    input [7:0] row;
    input [1:0] col;
    begin
      case (col)
        2'b00: cell = row[1:0];
        2'b01: cell = row[3:2];
        2'b10: cell = row[5:4];
        2'b11: cell = row[7:6];
      endcase
    end
  endfunction

  // Main pipeline: valid_out, done, grid_out are combinational from current pipeline state
  always @(*) begin
    // Default outputs (overridden in always_ff where needed)
    valid_out = valid_reg;
    done = (cycle_cnt == 3);
    // Default identity mapping for s0..s3
    s0 = row0_i;
    s1 = row1_i;
    s2 = row2_i;
    s3 = row3_i;

    // Column 0 shift schedule
    if (cycle_cnt == 0) begin
      s0 = row0_i;           // 0000 0000 -> keep
      s1 = row1_i;           // 0000 0000 -> keep
      s2 = row2_i;           // 0000 0000 -> keep
      s3 = row3_i;           // 0000 0000 -> keep
    end else if (cycle_cnt == 1) begin
      s0 = row0_i;                        // c0: 0 shifts
      s1 = {row1_i[5:0], row1_i[7:6]};    // c0: 1 shift left
      s2 = {row2_i[3:0], row2_i[7:4]};    // c0: 2 shifts left
      s3 = {row3_i[1:0], row3_i[7:2]};    // c0: 3 shifts left
    end else if (cycle_cnt == 2) begin
      s0 = row0_i;                        // c0: 0 shifts
      s1 = {row1_i[5:0], row1_i[7:6]};    // c0: 1 shift left
      s2 = {row2_i[3:0], row2_i[7:4]};    // c0: 2 shifts left
      s3 = {row3_i[1:0], row3_i[7:2]};    // c0: 3 shifts left
    end else begin // cycle_cnt == 3
      s0 = row0_i;                        // c0: 0 shifts
      s1 = {row1_i[5:0], row1_i[7:6]};    // c0: 1 shift left
      s2 = {row2_i[3:0], row2_i[7:4]};    // c0: 2 shifts left
      s3 = {row3_i[1:0], row3_i[7:2]};    // c0: 3 shifts left
    end

    // Flatten solution into grid_out (row-major order, 2 bits per cell)
    grid_out = {
      s3[7:6], s3[5:4], s3[3:2], s3[1:0],
      s2[7:6], s2[5:4], s2[3:2], s2[1:0],
      s1[7:6], s1[5:4], s1[3:2], s1[1:0],
      s0[7:6], s0[5:4], s0[3:2], s0[1:0]
    };
  end

  // Sequential pipeline and validation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row0_i <= 8'b0;
      row1_i <= 8'b0;
      row2_i <= 8'b0;
      row3_i <= 8'b0;
      cycle_cnt <= 3'b0;
      dup_reg <= 1'b0;
      valid_reg <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        col0v[i] <= 2'b0;
        col1v[i] <= 2'b0;
        col2v[i] <= 2'b0;
        col3v[i] <= 2'b0;
      end
    end else begin
      // Sample input on start
      if (start) begin
        row0_i <= grid_in[7:0];   // row0: c0..c3
        row1_i <= grid_in[15:8];  // row1: c0..c3
        row2_i <= grid_in[23:16]; // row2: c0..c3
        row3_i <= grid_in[31:24]; // row3: c0..c3
        cycle_cnt <= 3'b0;
        // Initialize column vectors for the next 4 cycles
        col0v[0] <= cell(row0_i, 2'd0);
        col1v[0] <= cell(row0_i, 2'd1);
        col2v[0] <= cell(row0_i, 2'd2);
        col3v[0] <= cell(row0_i, 2'd3);

        col0v[1] <= cell(row1_i, 2'd0);
        col1v[1] <= cell(row1_i, 2'd1);
        col2v[1] <= cell(row1_i, 2'd2);
        col3v[1] <= cell(row1_i, 2'd3);

        col0v[2] <= cell(row2_i, 2'd0);
        col1v[2] <= cell(row2_i, 2'd1);
        col2v[2] <= cell(row2_i, 2'd2);
        col3v[2] <= cell(row2_i, 2'd3);

        col0v[3] <= cell(row3_i, 2'd0);
        col1v[3] <= cell(row3_i, 2'd1);
        col2v[3] <= cell(row3_i, 2'd2);
        col3v[3] <= cell(row3_i, 2'd3);
      end else begin
        // Advance pipeline cycles
        if (cycle_cnt < 3) begin
          cycle_cnt <= cycle_cnt + 1;
          // Shift column vectors down the pipeline for next column check
          for (i = 0; i < 3; i = i + 1) begin
            col0v[i] <= col0v[i+1];
            col1v[i] <= col1v[i+1];
            col2v[i] <= col2v[i+1];
            col3v[i] <= col3v[i+1];
          end
          // Last slot filled with zeros (not used, kept for completeness)
          col0v[3] <= 2'b0;
          col1v[3] <= 2'b0;
          col2v[3] <= 2'b0;
          col3v[3] <= 2'b0;
        end
      end

      // Validate columns (ignore zeros) per cycle based on cycle_cnt
      if (start) begin
        // At start, validity is still unknown; will be set after first column check
        valid_reg <= 1'b0;
      end else if (cycle_cnt == 0) begin
        // Check column 0 among first k rows
        dup_reg <= |({
          (k >= 1) & (col0v[0] != 2'b0) & ( (col0v[0] == col0v[1]) | (col0v[0] == col0v[2]) | (col0v[0] == col0v[3]) ),
          (k >= 2) & (col0v[1] != 2'b0) & ( (col0v[1] == col0v[2]) | (col0v[1] == col0v[3]) ),
          (k >= 3) & (col0v[2] != 2'b0) & (col0v[2] == col0v[3]),
          1'b0
        });
        valid_reg <= ~dup_reg;
      end else if (cycle_cnt == 1) begin
        // Check column 1 among first k rows
        dup_reg <= |({
          (k >= 1) & (col1v[0] != 2'b0) & ( (col1v[0] == col1v[1]) | (col1v[0] == col1v[2]) | (col1v[0] == col1v[3]) ),
          (k >= 2) & (col1v[1] != 2'b0) & ( (col1v[1] == col1v[2]) | (col1v[1] == col1v[3]) ),
          (k >= 3) & (col1v[2] != 2'b0) & (col1v[2] == col1v[3]),
          1'b0
        });
        valid_reg <= ~dup_reg;
      end else if (cycle_cnt == 2) begin
        // Check column 2 among first k rows
        dup_reg <= |({
          (k >= 1) & (col2v[0] != 2'b0) & ( (col2v[0] == col2v[1]) | (col2v[0] == col2v[2]) | (col2v[0] == col2v[3]) ),
          (k >= 2) & (col2v[1] != 2'b0) & ( (col2v[1] == col2v[2]) | (col2v[1] == col2v[3]) ),
          (k >= 3) & (col2v[2] != 2'b0) & (col2v[2] == col2v[3]),
          1'b0
        });
        valid_reg <= ~dup_reg;
      end else begin
        // cycle_cnt == 3: Check column 3 among first k rows
        dup_reg <= |({
          (k >= 1) & (col3v[0] != 2'b0) & ( (col3v[0] == col3v[1]) | (col3v[0] == col3v[2]) | (col3v[0] == col3v[3]) ),
          (k >= 2) & (col3v[1] != 2'b0) & ( (col3v[1] == col3v[2]) | (col3v[1] == col3v[3]) ),
          (k >= 3) & (col3v[2] != 2'b0) & (col3v[2] == col3v[3]),
          1'b0
        });
        valid_reg <= ~dup_reg;
      end
    end
  end

endmodule
