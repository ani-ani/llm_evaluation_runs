module find_coordinates(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0][7:0] data_row0,
  input  [7:0][7:0] data_row1,
  input  [7:0][7:0] data_row2,
  input  [7:0][7:0] data_row3,
  input  [7:0][7:0] data_row4,
  input  [7:0][7:0] data_row5,
  input  [7:0][7:0] data_row6,
  input  [7:0][7:0] data_row7,
  input  [7:0][2:0] row_len,
  input  [7:0] target,
  output reg done,
  output reg [4:0] count,
  output reg [15:0][5:0] coordinates
);

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE      = 2'b00,
    S_SCAN      = 2'b01,
    S_DONE_PULSE= 2'b10
  } state_t;

  state_t state, next_state;

  // Row/column indices
  reg [2:0] row_idx;
  reg [2:0] col_idx;

  // Current row_len-1 for convenience
  reg [2:0] cur_row_max_col;

  // Count next
  reg [4:0] count_next;

  // Coordinate write enable
  reg        coord_we;
  reg [4:0]  coord_widx;
  reg [5:0]  coord_wdata;

  // Helper: read current element based on row_idx
  function automatic [7:0] read_data(
    input [2:0] r,
    input [2:0] c
  );
    case (r)
      3'd0: read_data = data_row0[c];
      3'd1: read_data = data_row1[c];
      3'd2: read_data = data_row2[c];
      3'd3: read_data = data_row3[c];
      3'd4: read_data = data_row4[c];
      3'd5: read_data = data_row5[c];
      3'd6: read_data = data_row6[c];
      3'd7: read_data = data_row7[c];
      default: read_data = 8'h00;
    endcase
  endfunction

  // Helper: compute starting column for a row based on row_len
  function automatic [2:0] row_start_col(input [2:0] len);
    if (len == 3'd0)
      row_start_col = 3'd0; // unused when len==0
    else
      row_start_col = len - 3'd1;
  endfunction

  // Next-state and control logic
  always @(*) begin
    next_state   = state;
    coord_we     = 1'b0;
    coord_widx   = count;
    coord_wdata  = {row_idx, col_idx};
    count_next   = count;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_SCAN;
        end
      end

      S_SCAN: begin
        // Default stays in S_SCAN until last row/col processed
        next_state = S_SCAN;

        // Default: no new match
        coord_we   = 1'b0;
        count_next = count;

        // Only compare if this row has valid columns
        if (row_len[row_idx] != 3'd0) begin
          if (read_data(row_idx, col_idx) == target && count < 5'd16) begin
            coord_we   = 1'b1;
            coord_widx = count;
            coord_wdata= {row_idx, col_idx};
            count_next = count + 5'd1;
          end
        end

        // Determine next (row_idx, col_idx) and possible state transition
        if (row_len[row_idx] == 3'd0 || col_idx == 3'd0) begin
          // Move to next row
          if (row_idx == 3'd7) begin
            // Finished last row
            next_state = S_DONE_PULSE;
          end
        end
      end

      S_DONE_PULSE: begin
        // Single-cycle done pulse, then go idle
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      count       <= 5'd0;
      row_idx     <= 3'd0;
      col_idx     <= 3'd0;
      cur_row_max_col <= 3'd0;
      coordinates <= '{default:6'd0};
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          // Wait for start; reset counters on start
          if (start) begin
            count <= 5'd0;
            coordinates <= '{default:6'd0};
            row_idx <= 3'd0;
            if (row_len[3'd0] == 3'd0) begin
              col_idx <= 3'd0; // unused for empty row
            end else begin
              col_idx <= row_start_col(row_len[3'd0]);
            end
          end
        end

        S_SCAN: begin
          // Write coordinate if match
          if (coord_we) begin
            coordinates[coord_widx] <= coord_wdata;
          end
          count <= count_next;

          // Advance scanning indices
          if (row_len[row_idx] == 3'd0 || col_idx == 3'd0) begin
            // Move to next row
            if (row_idx != 3'd7) begin
              row_idx <= row_idx + 3'd1;
              if (row_len[row_idx + 3'd1] == 3'd0) begin
                col_idx <= 3'd0; // no valid cols
              end else begin
                col_idx <= row_start_col(row_len[row_idx + 3'd1]);
              end
            end
            // else row_idx==7 and handled by state transition to S_DONE_PULSE
          end else begin
            // Same row, move to previous column
            col_idx <= col_idx - 3'd1;
          end
        end

        S_DONE_PULSE: begin
          // Assert done for one cycle, keep count and coordinates stable
          done <= 1'b1;
          // Prepare for next potential start
          // row_idx/col_idx will be reinitialized on next start
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule