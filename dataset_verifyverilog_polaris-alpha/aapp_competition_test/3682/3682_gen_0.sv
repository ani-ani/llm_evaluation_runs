module code_match_detector(
  input clk,
  input rst_n,
  input start,
  input [127:0] line_in, // 16 characters (8 bits per char)
  input line_valid,
  input fragment_end,
  output reg [2:0] max_count, // Maximum match count (0-4)
  output reg [255:0] filenames, // 2x128-bit filenames
  output reg done
);

  // State encoding
  localparam [1:0]
    S_IDLE       = 2'd0,
    S_PROCESSING = 2'd1,
    S_DONE       = 2'd2;

  reg [1:0] state, next_state;

  // Repository structures: 2 fragments x 4 lines x 128 bits
  reg [127:0] repo_lines [0:1][0:3];
  reg [1:0]   repo_line_count [0:1];        // number of stored non-empty lines (0-4)
  reg [127:0] repo_filenames [0:1];         // 16-char filenames

  // Fragment tracking
  reg [0:0]   frag_index;                   // current fragment index (0 or 1)
  reg         repo_full;                    // asserted when both fragments captured
  reg [7:0]   char_idx;

  // Normalization outputs
  reg [127:0] norm_line;
  reg         norm_empty;

  // Matching control
  reg [1:0]   line_latency_cnt;             // for enforcing 1 cycle per line + 1 cycle finalize
  reg         end_seen;

  // Consecutive match tracking per fragment
  reg [2:0] current_count [0:1];
  reg [2:0] best_count    [0:1];

  // Internal wires for line compare
  wire [1:0] f0_len = repo_line_count[0];
  wire [1:0] f1_len = repo_line_count[1];

  // Extract possible 4-line windows for comparison with last up to 4 input lines.
  // We maintain a sliding window of last 4 normalized non-empty input lines.
  reg [127:0] in_hist [0:3];
  reg [1:0]   in_hist_count; // number of valid entries in in_hist

  integer i, j;

  // Whitespace helper: treat only space (0x20) as space per requirements
  function automatic bit is_space (input [7:0] c);
    begin
      is_space = (c == 8'h20);
    end
  endfunction

  // Normalize a 128-bit line according to rules:
  // 1. Remove leading/trailing spaces
  // 2. Collapse consecutive spaces to single space
  // 3. Determine if empty after normalization
  task automatic normalize_line(
    input  [127:0] in_line,
    output [127:0] out_line,
    output         out_empty
  );
    integer k;
    reg [7:0] ch;
    reg [7:0] tmp   [0:15];
    integer write_idx;
    bit prev_space;
    bit started;
    begin
      write_idx = 0;
      prev_space = 0;
      started = 0;

      // First pass: trim leading spaces and collapse internal spaces
      for (k = 0; k < 16; k = k + 1) begin
        ch = in_line[8*(15-k)+:8]; // char 0 is MSB; process left-to-right
        if (!started) begin
          if (!is_space(ch)) begin
            // first non-space
            started = 1;
            prev_space = 0;
            if (write_idx < 16) begin
              tmp[write_idx] = ch;
              write_idx = write_idx + 1;
            end
          end
        end else begin
          if (is_space(ch)) begin
            if (!prev_space) begin
              // emit single space candidate, may be trimmed later if trailing
              if (write_idx < 16) begin
                tmp[write_idx] = 8'h20;
                write_idx = write_idx + 1;
              end
              prev_space = 1;
            end
          end else begin
            if (write_idx < 16) begin
              tmp[write_idx] = ch;
              write_idx = write_idx + 1;
            end
            prev_space = 0;
          end
        end
      end

      // Trim trailing space if present
      if (write_idx > 0 && tmp[write_idx-1] == 8'h20)
        write_idx = write_idx - 1;

      // Build out_line (pad remaining with zeros)
      out_line = 128'd0;
      for (k = 0; k < 16; k = k + 1) begin
        if (k < write_idx)
          out_line[8*(15-k)+:8] = tmp[k];
        else
          out_line[8*(15-k)+:8] = 8'd0;
      end

      out_empty = (write_idx == 0);
    end
  endtask

  // Simple filename derivation: use first normalized line of each fragment.
  // If no line, filename is zero.
  task automatic derive_filename(
    input  [127:0] first_line,
    output [127:0] fname
  );
    integer k;
    begin
      // Directly use first_line as truncated filename.
      fname = first_line;
      // (Already 128 bits / 16 chars)
      // Could add extra truncation/cleanup if needed.
    end
  endtask

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PROCESSING;
      end
      S_PROCESSING: begin
        if (end_seen)
          next_state = S_DONE;
      end
      S_DONE: begin
        if (start)
          next_state = S_PROCESSING;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      max_count <= 3'd0;
      filenames <= 256'd0;
      done <= 1'b0;
      repo_full <= 1'b0;
      frag_index <= 1'b0;
      repo_line_count[0] <= 2'd0;
      repo_line_count[1] <= 2'd0;
      repo_filenames[0] <= 128'd0;
      repo_filenames[1] <= 128'd0;
      for (i = 0; i < 2; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          repo_lines[i][j] <= 128'd0;
        end
        current_count[i] <= 3'd0;
        best_count[i] <= 3'd0;
      end
      for (i = 0; i < 4; i = i + 1)
        in_hist[i] <= 128'd0;
      in_hist_count <= 2'd0;
      end_seen <= 1'b0;
      line_latency_cnt <= 2'd0;
    end else begin
      state <= next_state;
      done <= 1'b0;

      if (start) begin
        // Reset all on start pulse
        repo_full <= 1'b0;
        frag_index <= 1'b0;
        repo_line_count[0] <= 2'd0;
        repo_line_count[1] <= 2'd0;
        repo_filenames[0] <= 128'd0;
        repo_filenames[1] <= 128'd0;
        for (i = 0; i < 2; i = i + 1) begin
          for (j = 0; j < 4; j = j + 1)
            repo_lines[i][j] <= 128'd0;
          current_count[i] <= 3'd0;
          best_count[i] <= 3'd0;
        end
        for (i = 0; i < 4; i = i + 1)
          in_hist[i] <= 128'd0;
        in_hist_count <= 2'd0;
        end_seen <= 1'b0;
        max_count <= 3'd0;
        filenames <= 256'd0;
        line_latency_cnt <= 2'd0;
      end

      case (state)
        S_IDLE: begin
          // Wait for start; nothing else
        end

        S_PROCESSING: begin
          // Normalize incoming line when valid
          if (line_valid) begin
            normalize_line(line_in, norm_line, norm_empty);

            if (!end_seen) begin
              // Before END: treat as repository fragment collection
              if (!norm_empty) begin
                if (!repo_full) begin
                  // Store into current fragment if space available
                  if (repo_line_count[frag_index] < 2'd4) begin
                    repo_lines[frag_index][repo_line_count[frag_index]] <= norm_line;
                    repo_line_count[frag_index] <= repo_line_count[frag_index] + 2'd1;
                    // If first line of fragment, derive filename
                    if (repo_line_count[frag_index] == 2'd0)
                      derive_filename(norm_line, repo_filenames[frag_index]);
                  end
                end
              end

              // Handle fragment_end to advance fragment index
              if (fragment_end && !repo_full) begin
                if (frag_index == 1'd0) begin
                  frag_index <= 1'd1;
                end else begin
                  repo_full <= 1'b1;
                end
              end

            end else begin
              // After END: treat as query input for matching
              if (!norm_empty) begin
                // Update sliding window of last 4 non-empty lines
                // Shift left and insert newest at position 0 (MSB index 0)
                in_hist[3] <= in_hist[2];
                in_hist[2] <= in_hist[1];
                in_hist[1] <= in_hist[0];
                in_hist[0] <= norm_line;
                if (in_hist_count < 2'd4)
                  in_hist_count <= in_hist_count + 2'd1;

                // For each fragment, check for consecutive matches ending at newest line
                for (i = 0; i < 2; i = i + 1) begin
                  if (repo_line_count[i] != 2'd0) begin
                    // count matches from the end backwards
                    reg [2:0] match_run;
                    match_run = 3'd0;
                    for (j = 0; j < 4; j = j + 1) begin
                      if (j < repo_line_count[i] && j < in_hist_count + 1) begin
                        // Compare repo last line-j with in_hist[j==0 ? new line : previous]
                        if (repo_lines[i][repo_line_count[i]-1-j] == (j == 0 ? norm_line : in_hist[j-1]))
                          match_run = match_run + 3'd1;
                        else
                          break;
                      end
                    end
                    // Update current and best counts
                    if (match_run > 0) begin
                      if (match_run > current_count[i])
                        current_count[i] <= match_run;
                      else
                        current_count[i] <= match_run;
                      if (match_run > best_count[i])
                        best_count[i] <= match_run;
                    end else begin
                      current_count[i] <= 3'd0;
                    end
                  end
                end
              end
            end
          end

          // Detect END marker line (not tied to normalization rules, as per spec)
          if (line_valid) begin
            // END marker is ASCII "***END***" at start; we check raw line_in
            if (line_in[127:64] == 64'h2A2A2A454E442A2A && // "***END**" (first 8 chars)
                line_in[63:56]  == 8'h2A) begin            // last '*'
              end_seen <= 1'b1;
            end
          end

          // Latency counter after END: one extra cycle for final calculation
          if (end_seen) begin
            if (line_latency_cnt < 2'd1)
              line_latency_cnt <= line_latency_cnt + 2'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Compute global max_count and filenames (LSBs contain valid names)
          begin
            reg [2:0] m0, m1;
            m0 = best_count[0];
            m1 = best_count[1];
            if (m0 >= m1) begin
              max_count <= m0;
            end else begin
              max_count <= m1;
            end
            filenames[127:0]   <= repo_filenames[0];
            filenames[255:128] <= repo_filenames[1];
          end
        end
      endcase
    end
  end

endmodule