module ad_remover(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:15][0:15],
  output reg [7:0] out_grid [0:15][0:15],
  output reg done
);

  // State encoding
  localparam IDLE    = 3'd0;
  localparam SCAN    = 3'd1; // Stage 1: detect borders and record image boundaries
  localparam VALID   = 3'd2; // Stage 2: validity check of detected images
  localparam MODIFY  = 3'd3; // Stage 3: choose smallest invalid and modify grid
  localparam OUTPUT  = 3'd4; // Copy final grid to out_grid and assert done

  reg [2:0] state, next_state;

  // Scan position
  reg [3:0] row;
  reg [3:0] col;

  // Image table (max 8 images)
  reg [3:0] img_left   [0:7];
  reg [3:0] img_right  [0:7];
  reg [3:0] img_top    [0:7];
  reg [3:0] img_bottom [0:7];
  reg       img_valid  [0:7]; // 1 if entry used

  // Image count (0..8)
  reg [3:0] img_count;

  // Working grid used for modification
  reg [7:0] work_grid [0:15][0:15];

  // For VALID stage
  reg [2:0] v_idx;        // current image index (0..7)
  reg [3:0] v_r;          // scan row inside image
  reg [3:0] v_c;          // scan col inside image
  reg       any_invalid;  // internal flag while scanning one image
  reg       img_is_valid [0:7]; // result: 1 if valid image, 0 if invalid

  // For MODIFY stage: find smallest invalid image
  reg [2:0] m_idx;              // iterator over images
  reg [2:0] min_idx;            // index of smallest invalid image
  reg [7:0] min_area;           // area of smallest invalid image
  reg       have_invalid;       // at least one invalid image found
  reg [7:0] cur_area;

  // For MODIFY: clearing selected image rectangle
  reg [3:0] c_row;
  reg [3:0] c_col;
  reg [3:0] sel_left, sel_right, sel_top, sel_bottom;
  reg       clear_done;

  integer i, j;

  // Helper function: check plus char
  function automatic is_plus(input [7:0] ch);
    is_plus = (ch == 8'd43);
  endfunction

  // Helper function: allowed char for interior
  function automatic is_allowed(input [7:0] ch);
    begin
      if ((ch >= "A" && ch <= "Z") ||
          (ch >= "a" && ch <= "z") ||
          (ch >= "0" && ch <= "9") ||
          ch == "?" || ch == "!" || ch == "," || ch == "." || ch == " ")
        is_allowed = 1'b1;
      else
        is_allowed = 1'b0;
    end
  endfunction

  // Detect rectangle starting at (r,c) where grid[r][c] == '+'
  // Returns 1 if a valid border-only rectangle >=3x3 is found.
  function automatic detect_rect(
    input [3:0] r,
    input [3:0] c,
    output [3:0] left_o,
    output [3:0] right_o,
    output [3:0] top_o,
    output [3:0] bottom_o
  );
    integer xr, xc;
    reg [3:0] left, right, top, bottom;
    reg ok;
    begin
      left  = c;
      top   = r;
      ok    = 1'b0;
      right = c;
      bottom= r;

      // find right corner along top row
      xc = c + 1;
      while (xc < 16 && grid[r][xc] != 8'd43) begin
        xc = xc + 1;
      end
      if (xc >= 16) begin
        detect_rect = 1'b0;
      end else begin
        right = xc[3:0];
        // find bottom corner along left column
        xr = r + 1;
        while (xr < 16 && grid[xr][c] != 8'd43) begin
          xr = xr + 1;
        end
        if (xr >= 16) begin
          detect_rect = 1'b0;
        end else begin
          bottom = xr[3:0];
          // size check
          if (((right - left) >= 2) && ((bottom - top) >= 2)) begin
            // verify four corners are '+' (already know top-left, top-right, bottom-left)
            if (grid[top][right] == 8'd43 &&
                grid[bottom][left] == 8'd43 &&
                grid[bottom][right] == 8'd43) begin
              // verify top and bottom edges
              ok = 1'b1;
              for (xc = left; xc <= right; xc = xc + 1) begin
                if (!is_plus(grid[top][xc]) && xc != left && xc != right) begin
                  ok = 1'b0;
                end
                if (!is_plus(grid[bottom][xc]) && xc != left && xc != right) begin
                  ok = 1'b0;
                end
              end
              // verify left and right edges
              for (xr = top; xr <= bottom; xr = xr + 1) begin
                if (!is_plus(grid[xr][left]) && xr != top && xr != bottom) begin
                  ok = 1'b0;
                end
                if (!is_plus(grid[xr][right]) && xr != top && xr != bottom) begin
                  ok = 1'b0;
                end
              end
            end
          end
          if (ok) begin
            left_o   = left;
            right_o  = right;
            top_o    = top;
            bottom_o = bottom;
            detect_rect = 1'b1;
          end else begin
            detect_rect = 1'b0;
          end
        end
      end
    end
  endfunction

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done      <= 1'b0;
      row       <= 4'd0;
      col       <= 4'd0;
      img_count <= 4'd0;
      v_idx     <= 3'd0;
      v_r       <= 4'd0;
      v_c       <= 4'd0;
      any_invalid <= 1'b0;
      m_idx     <= 3'd0;
      min_idx   <= 3'd0;
      min_area  <= 8'hFF;
      have_invalid <= 1'b0;
      c_row     <= 4'd0;
      c_col     <= 4'd0;
      sel_left  <= 4'd0;
      sel_right <= 4'd0;
      sel_top   <= 4'd0;
      sel_bottom<= 4'd0;
      clear_done<= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        img_left[i]   <= 4'd0;
        img_right[i]  <= 4'd0;
        img_top[i]    <= 4'd0;
        img_bottom[i] <= 4'd0;
        img_valid[i]  <= 1'b0;
        img_is_valid[i]<=1'b1;
      end
      for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) begin
          work_grid[i][j] <= 8'd32;
          out_grid[i][j]  <= 8'd32;
        end
      end
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for new run
            row       <= 4'd0;
            col       <= 4'd0;
            img_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
              img_valid[i]   <= 1'b0;
              img_is_valid[i]<= 1'b1;
            end
            // Copy input grid to work_grid
            for (i = 0; i < 16; i = i + 1) begin
              for (j = 0; j < 16; j = j + 1) begin
                work_grid[i][j] <= grid[i][j];
              end
            end
          end
        end

        // Stage 1: scan grid and record image boundaries
        SCAN: begin
          if (row < 16) begin
            // At each cell, if '+', try detect rectangle
            if (grid[row][col] == 8'd43 && img_count < 8) begin
              reg [3:0] dl, dr, dt, db;
              if (detect_rect(row, col, dl, dr, dt, db)) begin
                img_left[img_count]   <= dl;
                img_right[img_count]  <= dr;
                img_top[img_count]    <= dt;
                img_bottom[img_count] <= db;
                img_valid[img_count]  <= 1'b1;
                img_is_valid[img_count]<=1'b1; // default until checked
                img_count             <= img_count + 1'b1;
              end
            end

            // advance scan position (1 cycle per cell)
            if (col == 4'd15) begin
              col <= 4'd0;
              row <= row + 1'b1;
            end else begin
              col <= col + 1'b1;
            end
          end
        end

        // Stage 2: validate all images sequentially
        VALID: begin
          if (v_idx < img_count) begin
            if (!img_valid[v_idx]) begin
              // Skip empty entry
              img_is_valid[v_idx] <= 1'b1;
              v_idx <= v_idx + 1'b1;
              v_r   <= 4'd0;
              v_c   <= 4'd0;
              any_invalid <= 1'b0;
            end else begin
              // Initialize scan for this image when v_r/v_c == 0 and any_invalid unknown
              if (v_r == 4'd0 && v_c == 4'd0 && any_invalid == 1'b0) begin
                any_invalid <= 1'b0;
              end

              // Only scan interior: rows (top+1 .. bottom-1), cols (left+1 .. right-1)
              if ( (img_bottom[v_idx] - img_top[v_idx]) > 1 &&
                   (img_right[v_idx]  - img_left[v_idx]) > 1 ) begin
                reg [3:0] ir, ic;
                ir = img_top[v_idx] + 1 + v_r;
                ic = img_left[v_idx] + 1 + v_c;

                if (ir < img_bottom[v_idx] && ic < img_right[v_idx]) begin
                  if (!is_allowed(grid[ir][ic])) begin
                    any_invalid <= 1'b1;
                  end

                  // advance interior coordinates (1 cell per cycle)
                  if (ic + 1 < img_right[v_idx]) begin
                    v_c <= v_c + 1'b1;
                  end else begin
                    v_c <= 4'd0;
                    if (ir + 1 < img_bottom[v_idx]) begin
                      v_r <= v_r + 1'b1;
                    end else begin
                      // finished scanning current image
                      img_is_valid[v_idx] <= (any_invalid == 1'b0);
                      v_idx <= v_idx + 1'b1;
                      v_r   <= 4'd0;
                      v_c   <= 4'd0;
                      any_invalid <= 1'b0;
                    end
                  end
                end else begin
                  // no interior (degenerate but size>=3x3 check above prevents)
                  img_is_valid[v_idx] <= 1'b1;
                  v_idx <= v_idx + 1'b1;
                  v_r   <= 4'd0;
                  v_c   <= 4'd0;
                  any_invalid <= 1'b0;
                end
              end else begin
                // Should not happen due to size check; treat as valid
                img_is_valid[v_idx] <= 1'b1;
                v_idx <= v_idx + 1'b1;
                v_r   <= 4'd0;
                v_c   <= 4'd0;
                any_invalid <= 1'b0;
              end
            end
          end
        end

        // Stage 3: select smallest invalid and clear it in work_grid
        MODIFY: begin
          if (!clear_done) begin
            // First pass: find smallest invalid image
            if (m_idx < img_count) begin
              if (img_valid[m_idx] && !img_is_valid[m_idx]) begin
                cur_area <= (img_right[m_idx] - img_left[m_idx] + 1) *
                            (img_bottom[m_idx] - img_top[m_idx] + 1);
                if (!have_invalid || cur_area < min_area) begin
                  min_area    <= cur_area;
                  min_idx     <= m_idx;
                  have_invalid<= 1'b1;
                end
              end
              m_idx <= m_idx + 1'b1;
            end else begin
              // After scanning all
              if (have_invalid) begin
                sel_left   <= img_left[min_idx];
                sel_right  <= img_right[min_idx];
                sel_top    <= img_top[min_idx];
                sel_bottom <= img_bottom[min_idx];
                c_row      <= img_top[min_idx];
                c_col      <= img_left[min_idx];
                clear_done <= 1'b0; // proceed to actual clearing next cycles
                // Mark we are moving into clear sequence by reusing clear_done flag progression
                have_invalid <= have_invalid; // keep for reference
              end else begin
                clear_done <= 1'b1; // nothing to clear
              end
            end
          end else begin
            // nothing; retained for structure (not used)
          end

          // If we have an invalid image selected and not yet cleared, perform clear
          if (have_invalid && !clear_done && m_idx == img_count) begin
            // Clear one cell per cycle within selected rectangle
            work_grid[c_row][c_col] <= 8'd32;
            if (c_col == sel_right) begin
              c_col <= sel_left;
              if (c_row == sel_bottom) begin
                clear_done <= 1'b1; // finished
              end else begin
                c_row <= c_row + 1'b1;
              end
            } else begin
              c_col <= c_col + 1'b1;
            end
          end
        end

        // OUTPUT: copy work_grid to out_grid, assert done
        OUTPUT: begin
          for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
              out_grid[i][j] <= work_grid[i][j];
            end
          end
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SCAN;
      end
      SCAN: begin
        if (row == 16) begin
          next_state = VALID;
        end
      end
      VALID: begin
        if (v_idx >= img_count) begin
          // move to modify stage
          next_state = MODIFY;
        end
      end
      MODIFY: begin
        if ((m_idx >= img_count) && ( (!have_invalid) || clear_done )) begin
          next_state = OUTPUT;
        end
      end
      OUTPUT: begin
        // stay until next start; could return to IDLE when start deasserted
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule