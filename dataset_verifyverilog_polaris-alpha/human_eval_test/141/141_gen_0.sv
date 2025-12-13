module file_name_checker (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [127:0] file_name,
  output logic        valid,
  output logic        done
);

  // State to track processing progress
  logic [4:0] index;            // 0-16
  logic       processing;

  // Tracking conditions
  logic       has_dot;
  logic [3:0] dot_pos;          // 0-15
  logic [2:0] digit_count;      // up to 8, but we only care up to 4 (more => invalid)
  logic       invalid_flag;

  // Capture file_name at start for fixed-latency behavior
  logic [127:0] file_name_reg;

  // Character extraction function
  function automatic logic [7:0] get_char(input logic [127:0] fn, input logic [4:0] idx);
    get_char = fn[8*idx +: 8];
  endfunction

  // Synchronous control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing   <= 1'b0;
      index        <= 5'd0;
      has_dot      <= 1'b0;
      dot_pos      <= 4'd0;
      digit_count  <= 3'd0;
      invalid_flag <= 1'b0;
      file_name_reg<= 128'd0;
      valid        <= 1'b0;
      done         <= 1'b0;
    end else begin
      // default outputs each cycle
      done  <= 1'b0;

      if (start && !processing) begin
        // Start new processing sequence
        processing    <= 1'b1;
        index         <= 5'd0;
        has_dot       <= 1'b0;
        dot_pos       <= 4'd0;
        digit_count   <= 3'd0;
        invalid_flag  <= 1'b0;
        file_name_reg <= file_name;
        valid         <= 1'b0;
      end else if (processing) begin
        // Process one character per cycle for indices 0..15
        if (index < 5'd16) begin
          logic [7:0] ch;
          ch = get_char(file_name_reg, index);

          // Condition (a): dot handling
          if (ch == 8'h2E) begin // '.'
            if (!has_dot) begin
              has_dot  <= 1'b1;
              dot_pos  <= index[3:0];
            end else begin
              // Multiple dots => invalid immediately
              invalid_flag <= 1'b1;
            end
          end

          // Condition (d): digit count
          if (ch >= 8'h30 && ch <= 8'h39) begin
            if (digit_count < 3'd7) begin
              digit_count <= digit_count + 3'd1;
            end
          end

          // Condition (b): prefix starts with A-Z/a-z
          if (index == 5'd0) begin
            if (!((ch >= 8'h41 && ch <= 8'h5A) || (ch >= 8'h61 && ch <= 8'h7A))) begin
              invalid_flag <= 1'b1;
            end
          end

          // Increment index
          index <= index + 5'd1;
        end else begin
          // Completed 16 characters; finalize in this (17th) cycle
          processing <= 1'b0;

          // Evaluate suffix and digit constraints
          logic final_valid;
          final_valid = 1'b1;

          // Must have exactly one dot
          if (!has_dot) begin
            final_valid = 1'b0;
          end

          // No more than 3 digits overall
          if (digit_count > 3'd3) begin
            final_valid = 1'b0;
          end

          // Check suffix only if still potentially valid and dot present
          if (final_valid && has_dot) begin
            // Suffix must be "txt", "exe", or "dll"
            logic [7:0] c1, c2, c3;
            c1 = get_char(file_name_reg, dot_pos + 4'd1);
            c2 = get_char(file_name_reg, dot_pos + 4'd2);
            c3 = get_char(file_name_reg, dot_pos + 4'd3);

            // Expected patterns:
            // txt: 74 78 74
            // exe: 65 78 65
            // dll: 64 6C 6C
            logic is_txt, is_exe, is_dll;
            is_txt = (c1 == 8'h74 && c2 == 8'h78 && c3 == 8'h74);
            is_exe = (c1 == 8'h65 && c2 == 8'h78 && c3 == 8'h65);
            is_dll = (c1 == 8'h64 && c2 == 8'h6C && c3 == 8'h6C);

            if (!(is_txt || is_exe || is_dll)) begin
              final_valid = 1'b0;
            end
          end

          // Combine with any early invalidation
          if (invalid_flag) begin
            final_valid = 1'b0;
          end

          valid <= final_valid;
          done  <= 1'b1; // 1-cycle pulse
        end
      end else begin
        // Idle: ensure outputs per spec
        valid <= 1'b0;
      end
    end
  end

endmodule