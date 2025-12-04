module find_coordinates (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_row0 [7:0],
  input [7:0] data_row1 [7:0],
  input [7:0] data_row2 [7:0],
  input [7:0] data_row3 [7:0],
  input [7:0] data_row4 [7:0],
  input [7:0] data_row5 [7:0],
  input [7:0] data_row6 [7:0],
  input [7:0] data_row7 [7:0],
  input [7:0][2:0] row_len,
  input [7:0] target,
  output reg done,
  output reg [4:0] count,
  output reg [15:0][5:0] coordinates
);

  // Internal state
  reg busy;
  reg [2:0] row;
  reg [2:0] col;
  reg [2:0] next_col;
  reg [4:0] next_count;
  reg [2:0] next_row;
  reg next_busy;
  reg [15:0][5:0] next_coords;

  // Data selector
  wire [7:0] curr_data;
  assign curr_data = (row == 3'b000) ? data_row0[col] :
                     (row == 3'b001) ? data_row1[col] :
                     (row == 3'b010) ? data_row2[col] :
                     (row == 3'b011) ? data_row3[col] :
                     (row == 3'b100) ? data_row4[col] :
                     (row == 3'b101) ? data_row5[col] :
                     (row == 3'b110) ? data_row6[col] :
                     data_row7[col];

  always @(*) begin
    // Defaults (avoid latches)
    next_busy    = busy;
    next_row     = row;
    next_col     = col;
    next_count   = count;
    next_coords  = coordinates;
    done         = 1'b0;

    if (!busy) begin
      if (start) begin
        // Start new scan
        next_busy  = 1'b1;
        next_row   = 3'b000;
        next_col   = 3'b000;
        next_count = 5'b00000;
        next_coords = '0;
      end else begin
        // Idle, keep outputs reset
        next_busy  = 1'b0;
        next_row   = 3'b000;
        next_col   = 3'b000;
        next_count = 5'b00000;
        next_coords = '0;
        done       = 1'b0;
      end
    end else begin
      // Busy: scan current row
      if (curr_data == target && next_count < 5'd16) begin
        // Store coordinate: {row[2:0], col[2:0]}
        next_coords[next_count] = {row, col};
        next_count = next_count + 1;
      end

      // Advance column
      if (col + 1 >= row_len[row]) begin
        // Move to next row
        if (row + 1 >= 3'b111) begin
          // Finished last row
          next_busy  = 1'b0;
          next_row   = 3'b000;
          next_col   = 3'b000;
          done       = 1'b1; // 1-cycle pulse on completion
        end else begin
          next_row   = row + 1;
          next_col   = 3'b000;
          next_busy  = 1'b1;
        end
      end else begin
        // Stay in the same row
        next_row = row;
        next_col = col + 1;
        next_busy = 1'b1;
      end
    end
  end

  // Synchronous update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy       <= 1'b0;
      row        <= 3'b000;
      col        <= 3'b000;
      count      <= 5'b00000;
      coordinates <= '0;
      done       <= 1'b0;
    end else begin
      busy       <= next_busy;
      row        <= next_row;
      col        <= next_col;
      count      <= next_count;
      coordinates <= next_coords;
      done       <= done; // 'done' is driven by combinational logic above
    end
  end

endmodule
