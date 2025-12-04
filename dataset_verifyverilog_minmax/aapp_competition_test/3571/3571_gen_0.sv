module elder_scroll_display (
  input clk,
  input rst_n,
  input start,                // pulse high to start processing
  input [3:0] view_w,         // viewport width (3-8 chars)
  input [2:0] view_h,         // viewport height (3-5 lines)
  input [2:0] first_line,     // starting line index (0-7)
  input [15:0][7:0] text_lines [0:7],  // 8 lines of text (16 chars each, 7-bit ASCII)
  output reg [7:0][7:0] display_out [0:4], // 5 viewport lines (8 chars each)
  output reg [3:0] thumb_pos,           // scroll thumb position (0-4)
  output reg done                        // high when output is valid
);
  // Parameters
  localparam NUM_TEXT_LINES = 8;
  localparam CHARS_PER_TEXT_LINE = 16;
  localparam DISP_LINES = 5;
  localparam CHARS_PER_DISP_LINE = 8;
  localparam VIEW_W_MIN = 3;
  localparam VIEW_W_MAX = 8;
  localparam VIEW_H_MIN = 3;
  localparam VIEW_H_MAX = 5;
  localparam IDLE = 2'b00;
  localparam PROC = 2'b01;
  localparam DONE = 2'b10;

  // Internal signals
  reg [1:0] state, next_state;
  reg [3:0] ctr;              // 0..14 (15 cycles total)

  // Captured inputs
  reg [3:0] view_w_r;
  reg [2:0] view_h_r;
  reg [2:0] first_line_r;
  reg [15:0][7:0] text_lines_r [0:7];

  // Line wrapper buffer (8x8 chars)
  reg [7:0] buffer [0:7][0:7];
  reg [3:0] total_wrapped; // number of wrapped lines (1..8)

  // Extraction info
  reg [2:0] sline; // starting line index captured (0..7)

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ctr <= 4'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      if (next_state == PROC) ctr <= 4'd0;
      else if (state == PROC) ctr <= ctr + 4'd1;
      done <= (next_state == DONE);
    end
  end

  // State machine combinational logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PROC;
      PROC: if (ctr == 4'd14) next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Capture inputs at start
  always @(posedge clk) begin
    if (state == IDLE && start) begin
      view_w_r     <= view_w;
      view_h_r     <= view_h;
      first_line_r <= first_line;
      text_lines_r <= text_lines;
    end
  end

  // Line-wrapping algorithm (combinational, results ready at end of PROC)
  always @(*) begin
    // Defaults
    total_wrapped = 4'd0;
    for (int i = 0; i < 8; i++) for (int j = 0; j < 8; j++) buffer[i][j] = 8'h20;

    if (state == PROC) begin
      for (int j = 0; j < 8; j++) begin
        buffer[total_wrapped][j] = 8'h20;
      end

      // Iterate through all 8 source lines
      for (int src = 0; src < 8; src++) begin
        // Find line length up to first space or 16 chars
        reg [4:0] line_len; // 0..16
        reg [4:0] sp;       // index of first space in line, 0..16
        line_len = 0;
        sp = 16;
        for (int i = 0; i < 16; i++) begin
          if (text_lines_r[src][i] == 8'h20) begin
            sp = i;
            break;
          end else if (text_lines_r[src][i] == 8'h00) begin
            sp = i;
            break;
          end else begin
            line_len = i + 5'd1;
          end
        end
        if (sp == 16) begin
          // No space found; length is text_len
          line_len = line_len;
        end

        // Copy source line to a temp array for word processing
        reg [15:0][7:0] line_chars;
        for (int i = 0; i < 16; i++) line_chars[i] = text_lines_r[src][i];

        // Word iterator (index into line_chars)
        integer w_start;
        integer w_end; // exclusive
        w_start = 0;
        while (w_start < 16) begin
          // Find next non-space
          while (w_start < 16 && line_chars[w_start] == 8'h20) w_start = w_start + 1;
          if (w_start >= 16) break;
          // Find next space or end
          w_end = w_start;
          while (w_end < 16 && line_chars[w_end] != 8'h20) w_end = w_end + 1;
          // Determine word length
          integer word_len;
          word_len = w_end - w_start;
          if (word_len > view_w_r) word_len = view_w_r; // truncate long words

          // Check if it fits on current line
          integer cur_len;
          cur_len = 0;
          // Count non-space chars in buffer[total_wrapped] up to 8 chars
          for (int i = 0; i < 8; i++) begin
            if (buffer[total_wrapped][i] != 8'h20) cur_len = cur_len + 1;
          end

          if (total_wrapped < 8) begin
            if (cur_len == 0) begin
              // Start new line with word
              for (int i = 0; i < word_len; i++) begin
                buffer[total_wrapped][i] = line_chars[w_start + i];
              end
              for (int i = word_len; i < 8; i++) begin
                buffer[total_wrapped][i] = 8'h20;
              end
            end else begin
              // Needs at least one space separator
              if (cur_len + 1 + word_len <= view_w_r) begin
                // Add space
                buffer[total_wrapped][cur_len] = 8'h20;
                // Add word
                for (int i = 0; i < word_len; i++) begin
                  buffer[total_wrapped][cur_len + 1 + i] = line_chars[w_start + i];
                end
                // Pad rest
                for (int i = cur_len + 1 + word_len; i < 8; i++) begin
                  buffer[total_wrapped][i] = 8'h20;
                end
              end else begin
                // Move to next wrapped line
                total_wrapped = total_wrapped + 4'd1;
                if (total_wrapped < 8) begin
                  for (int i = 0; i < word_len; i++) begin
                    buffer[total_wrapped][i] = line_chars[w_start + i];
                  end
                  for (int i = word_len; i < 8; i++) begin
                    buffer[total_wrapped][i] = 8'h20;
                  end
                end
              end
            end
          end
          // Advance to next word
          w_start = w_end;
        end
        // After finishing source line, increment wrapped lines count (if we added content)
        // Count current line length to see if it's non-empty (ignoring spaces)
        integer cur_len_check;
        cur_len_check = 0;
        for (int i = 0; i < 8; i++) begin
          if (buffer[total_wrapped][i] != 8'h20) cur_len_check = cur_len_check + 1;
        end
        if (cur_len_check > 0 && total_wrapped < 8) total_wrapped = total_wrapped + 4'd1;
      end
      // Clamp to 8
      if (total_wrapped > 4'd8) total_wrapped = 4'd8;
    end
  end

  // Compute thumb position and extract viewport lines at end of processing
  always @(*) begin
    // Default extraction: clear display
    for (int r = 0; r < 5; r++) begin
      for (int c = 0; c < 8; c++) begin
        display_out[r][c] = 8'h20;
      end
    end
    thumb_pos = 4'd0;
    sline = 3'd0;

    if (state == DONE) begin
      sline = first_line_r; // 0..7

      // Thumb calculation: thumb = ((view_h-3)*first_line)/(total_lines - view_h)
      // Clamp to [0, view_h-1]
      integer denom;
      denom = (total_wrapped > view_h_r) ? (total_wrapped - view_h_r) : 0;
      integer thumb_int;
      thumb_int = 0;
      if (denom > 0) begin
        thumb_int = ((view_h_r - 3'd3) * first_line_r) / denom;
      end
      if (thumb_int < 0) thumb_int = 0;
      if (thumb_int > (view_h_r - 1)) thumb_int = (view_h_r - 1);
      thumb_pos = thumb_int[3:0];

      // Fill text content (left 7 chars), leave 1 char on right for scrollbar
      for (int r = 0; r < view_h_r; r++) begin
        integer src_line;
        src_line = sline + r; // 0..7
        for (int c = 0; c < 7; c++) begin
          if (src_line < total_wrapped) begin
            display_out[r][c] = buffer[src_line][c];
          end else begin
            display_out[r][c] = 8'h20;
          end
        end
        // Rightmost char stays space for now; will be scrollbar below
        display_out[r][7] = 8'h20;
      end

      // Scrollbar column at rightmost char (col 7)
      for (int r = 0; r < view_h_r; r++) begin
        if (r == 0) display_out[r][7] = 8'h5E;       // top '^'
        else if (r == thumb_pos) display_out[r][7] = 8'h58; // thumb 'X'
        else if (r == (view_h_r - 1)) display_out[r][7] = 8'h76; // bottom 'v'
        else display_out[r][7] = 8'h20;             // space
      end
    end
  end
endmodule