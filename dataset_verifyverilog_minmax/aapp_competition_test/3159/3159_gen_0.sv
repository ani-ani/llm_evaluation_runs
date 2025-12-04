module ad_remover (
  input clk,               // clock signal
  input rst_n,             // active-low reset
  input start,             // pulse high to begin processing
  input [7:0] grid [0:15][0:15],  // 16x16 ASCII input grid (8-bit chars)
  output reg [7:0] out_grid [0:15][0:15], // processed output grid
  output reg done          // high when processing complete
);

  // State machine
  localparam IDLE  = 2'b00;
  localparam S1    = 2'b01; // Stage 1: border detection and boundary recording
  localparam S2    = 2'b10; // Stage 2: validity checks (combinational)
  localparam S3    = 2'b11; // Stage 3: area compare and final grid modification

  reg [1:0] state, state_next;

  // Image boundary registers: [left, right, top, bottom] (4 bits each) per image entry
  reg [3:0] img_left  [0:7];
  reg [3:0] img_right [0:7];
  reg [3:0] img_top   [0:7];
  reg [3:0] img_bot   [0:7];

  // Internal signals for pipeline flow
  reg [3:0] i_ptr, i_ptr_next;
  reg [3:0] j_ptr, j_ptr_next;
  reg have_candidate, have_candidate_next;
  reg [3:0] cand_left, cand_left_next;
  reg [3:0] cand_top,  cand_top_next;
  reg [3:0] cand_right, cand_right_next;
  reg [3:0] cand_bottom, cand_bottom_next;
  reg [3:0] img_count, img_count_next;   // how many valid 3x3 '+'-bordered images found
  reg [3:0] img_count_pipe, img_count_pipe_next;

  // Stage 2: validity and areas
  reg invalid_img [0:7];
  reg [5:0] area    [0:7]; // area = width * height (max 256 fits in 9 bits, 6 bits enough for 16*16)
  reg [5:0] min_area, min_area_next;
  reg [2:0] min_idx, min_idx_next;
  reg has_invalid, has_invalid_next;

  // Stage 3: result selected
  reg [3:0] sel_left,  sel_left_next;
  reg [3:0] sel_right, sel_right_next;
  reg [3:0] sel_top,   sel_top_next;
  reg [3:0] sel_bot,   sel_bot_next;

  // Helper functions
  function automatic bit is_allowed_char(input [7:0] ch);
    // Allowed: A-Z a-z 0-9 ? ! , . space
    bit [7:0] c;
    c = ch;
    return ((c >= "A") && (c <= "Z")) ||
           ((c >= "a") && (c <= "z")) ||
           ((c >= "0") && (c <= "9")) ||
           (c == "?") || (c == "!") || (c == ",") || (c == ".") || (c == " ");
  endfunction

  function automatic bit is_plus(input [7:0] ch);
    return (ch == 8'd43); // '+'
  endfunction

  // Combinational logic (3-stage pipeline + state machine + output update)
  always_comb begin
    // Defaults
    state_next       = state;
    i_ptr_next       = i_ptr;
    j_ptr_next       = j_ptr;
    have_candidate_next = have_candidate;
    cand_left_next   = cand_left;
    cand_top_next    = cand_top;
    cand_right_next  = cand_right;
    cand_bottom_next = cand_bottom;
    img_count_next   = img_count;
    img_count_pipe_next = img_count_pipe;

    // Stage 2 defaults (combinational)
    for (int k = 0; k < 8; k++) begin
      invalid_img[k] = 1'b0;
      area[k] = 6'd0;
    end
    min_area_next  = 6'd255;
    min_idx_next   = 3'd0;
    has_invalid_next = 1'b0;

    // Stage 3 defaults (combinational)
    sel_left_next  = 4'd0;
    sel_right_next = 4'd0;
    sel_top_next   = 4'd0;
    sel_bot_next   = 4'd0;

    // Reset output grid to input by default
    out_grid = grid;

    case (state)
      IDLE: begin
        // Capture boundary registers when entering S1
        if (start) begin
          state_next = S1;
          i_ptr_next = 4'd0;
          j_ptr_next = 4'd0;
          have_candidate_next = 1'b0;
          img_count_next = 4'd0;
          img_count_pipe_next = 4'd0;
        end
      end

      S1: begin
        // Stage 1: Border detection and boundary recording
        if ((i_ptr < 16) && (j_ptr < 16)) begin
          if (is_plus(grid[i_ptr][j_ptr])) begin
            if (!have_candidate) begin
              // Potential top-left '+' found
              have_candidate_next = 1'b1;
              cand_left_next   = j_ptr;
              cand_top_next    = i_ptr;
              cand_right_next  = j_ptr;
              cand_bottom_next = i_ptr;
            end else begin
              // If same row -> could be right edge
              if (i_ptr == cand_top) begin
                if (j_ptr > (cand_left + 1)) begin
                  // Update tentative right edge
                  cand_right_next = j_ptr;
                end
              end
              // If same col -> could be bottom edge
              if (j_ptr == cand_left) begin
                if (i_ptr > (cand_top + 1)) begin
                  // Update tentative bottom edge
                  cand_bottom_next = i_ptr;
                end
              end
              // If we have a non-degenerate rectangle, record and reset candidate
              if ((cand_right > (cand_left + 1)) && (cand_bottom > (cand_top + 1))) begin
                if (img_count < 4'd8) begin
                  img_left  [img_count] = cand_left;
                  img_right [img_count] = cand_right;
                  img_top   [img_count] = cand_top;
                  img_bot   [img_count] = cand_bottom;
                  img_count_next = img_count + 1;
                end
                have_candidate_next = 1'b0; // consume candidate and look for new TL '+'
              end
            end
          end
          // Advance coordinates
          if (j_ptr == 4'd15) begin
            j_ptr_next = 4'd0;
            i_ptr_next = i_ptr + 1;
          end else begin
            j_ptr_next = j_ptr + 1;
          end
        end else begin
          // Finalize any remaining candidate if it formed a rectangle >= 3x3
          if (have_candidate && (cand_right > (cand_left + 1)) && (cand_bottom > (cand_top + 1))) begin
            if (img_count < 4'd8) begin
              img_left  [img_count] = cand_left;
              img_right [img_count] = cand_right;
              img_top   [img_count] = cand_top;
              img_bot   [img_count] = cand_bottom;
              img_count_next = img_count + 1;
            end
          end
          // Move to Stage 2
          state_next = S2;
          img_count_pipe_next = (have_candidate && (cand_right > (cand_left + 1)) && (cand_bottom > (cand_top + 1)))
                                ? (img_count + 1) : img_count;
          have_candidate_next = 1'b0;
        end
      end

      S2: begin
        // Stage 2: Parallel validity checks for all detected images (combinational)
        // Check borders: ensure border cells are '+' and interior is non-empty.
        for (int i = 0; i < 8; i++) begin
          if (i < img_count) begin
            automatic int w = $unsigned(img_right[i]) - $unsigned(img_left[i]) + 1;
            automatic int h = $unsigned(img_bot[i])   - $unsigned(img_top[i])   + 1;
            area[i] = w * h; // up to 256
            // Border validation
            bit border_ok;
            border_ok = 1'b1;
            // Top and bottom rows
            for (int x = img_left[i]; x <= img_right[i]; x++) begin
              if (!is_plus(grid[img_top[i]][x]) || !is_plus(grid[img_bot[i]][x])) begin
                border_ok = 1'b0;
              end
            end
            // Left and right columns (excluding corners to avoid double-check)
            for (int y = img_top[i] + 1; y < img_bot[i]; y++) begin
              if (!is_plus(grid[y][img_left[i]]) || !is_plus(grid[y][img_right[i]])) begin
                border_ok = 1'b0;
              end
            end
            // Interior validation (must not contain invalid chars)
            bit interior_ok;
            interior_ok = 1'b1;
            if ((w >= 3) && (h >= 3)) begin
              for (int yy = img_top[i] + 1; yy < img_bot[i]; yy++) begin
                for (int xx = img_left[i] + 1; xx < img_right[i]; xx++) begin
                  if (!is_allowed_char(grid[yy][xx])) begin
                    interior_ok = 1'b0;
                  end
                end
              end
            end else begin
              interior_ok = 1'b0; // too small, not a valid image
            end
            invalid_img[i] = ~(border_ok && interior_ok);
          end else begin
            invalid_img[i] = 1'b1; // unused entries are considered invalid by default
            area[i] = 6'd0;
          end
        end

        // Select smallest area among invalid images
        min_area_next = 6'd255;
        min_idx_next  = 3'd0;
        has_invalid_next = 1'b0;
        for (int i = 0; i < 8; i++) begin
          if (invalid_img[i]) begin
            if (!has_invalid) begin
              min_area_next = area[i];
              min_idx_next  = i[2:0];
              has_invalid_next = 1'b1;
            end else if (area[i] < min_area_next) begin
              min_area_next = area[i];
              min_idx_next  = i[2:0];
            end
          end
        end

        // If no invalid images, we're done without modifications
        if (!has_invalid_next) begin
          state_next = IDLE;
        end else begin
          // Stage 3: Prepare selection for the smallest invalid image
          sel_left_next  = img_left [min_idx_next];
          sel_right_next = img_right[min_idx_next];
          sel_top_next   = img_top  [min_idx_next];
          sel_bot_next   = img_bot  [min_idx_next];
          state_next = S3;
        end
      end

      S3: begin
        // Stage 3: Replace flagged image border and interior with spaces (ASCII 32)
        for (int y = sel_top; y <= sel_bot; y++) begin
          for (int x = sel_left; x <= sel_right; x++) begin
            out_grid[y][x] = 8'd32; // ' '
          end
        end
        state_next = IDLE;
      end

      default: begin
        state_next = IDLE;
      end
    endcase

    // Drive done high when in IDLE (processing complete)
    done = (state_next == IDLE) && (state != IDLE ? 1'b1 : 1'b0);
  end

  // Sequential logic: state updates and internal pipeline registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i_ptr <= 4'd0;
      j_ptr <= 4'd0;
      have_candidate <= 1'b0;
      cand_left   <= 4'd0;
      cand_top    <= 4'd0;
      cand_right  <= 4'd0;
      cand_bottom <= 4'd0;
      img_count   <= 4'd0;
      img_count_pipe <= 4'd0;
    end else begin
      state <= state_next;
      i_ptr <= i_ptr_next;
      j_ptr <= j_ptr_next;
      have_candidate <= have_candidate_next;
      cand_left   <= cand_left_next;
      cand_top    <= cand_top_next;
      cand_right  <= cand_right_next;
      cand_bottom <= cand_bottom_next;
      img_count   <= img_count_next;
      img_count_pipe <= img_count_pipe_next;
    end
  end

endmodule
