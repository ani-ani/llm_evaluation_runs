module palindrome_parts(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][7:0] s,
  output reg [3:0] k,
  output reg [15:0][7:0] parts,
  output reg done
);

  // State encoding
  localparam IDLE   = 3'd0;
  localparam COUNT  = 3'd1;
  localparam CALC_K = 3'd2;
  localparam BUILD  = 3'd3;
  localparam DONE_S = 3'd4;

  reg [2:0] state, next_state;

  // Latency counter to ensure fixed max latency and done at 100 cycles after start
  reg [6:0] cycle_cnt; // up to >=100
  reg       start_seen;

  // Frequency counters: 16 chars max, 6-bit each
  reg [5:0] freq [0:15];
  reg [3:0] count_idx;

  // Odd count and k calculation
  reg [4:0] odd_count;  // up to 16
  reg [3:0] candidate_k;

  // Build-related
  reg [3:0] part_len;          // n / k
  reg [3:0] part_idx;          // which palindrome
  reg [3:0] pos_idx;           // position inside palindrome
  reg [3:0] left_pos, right_pos;
  reg [3:0] char_idx;
  reg       placing_pairs;     // 1: placing pair positions, 0: placing centers

  // Local storage for palindrome characters before mapping to parts bus
  reg [7:0] pal_mem [0:15][0:15]; // [pal][pos]

  integer i, j;

  // Combinational mapping from pal_mem to parts bus
  // Flatten pal_mem into parts as contiguous 16*8 bits, pal0 at lowest indices
  always @* begin
    // Default zero
    for (i = 0; i < 16; i = i + 1) begin
      for (j = 0; j < 16; j = j + 1) begin
        parts[i*16 + j] = pal_mem[i][j];
      end
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT;
      end
      COUNT: begin
        if (count_idx == n)
          next_state = CALC_K;
      end
      CALC_K: begin
        next_state = BUILD;
      end
      BUILD: begin
        // We rely on cycle_cnt/latency to move to DONE_S; FSM stays BUILD until time
        if (start_seen && cycle_cnt == 7'd99)
          next_state = DONE_S;
      end
      DONE_S: begin
        // One-cycle done pulse, then IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Helper: character index modulo 16 (since only 16 counters)
  function [3:0] char_index(input [7:0] c);
    begin
      char_index = c[3:0];
    end
  endfunction

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      k           <= 4'd0;
      cycle_cnt   <= 7'd0;
      start_seen  <= 1'b0;
      count_idx   <= 4'd0;
      odd_count   <= 5'd0;
      candidate_k <= 4'd0;
      part_len    <= 4'd0;
      part_idx    <= 4'd0;
      pos_idx     <= 4'd0;
      left_pos    <= 4'd0;
      right_pos   <= 4'd0;
      char_idx    <= 4'd0;
      placing_pairs <= 1'b1;
      // Clear freq and pal_mem
      for (i = 0; i < 16; i = i + 1) begin
        freq[i] <= 6'd0;
        for (j = 0; j < 16; j = j + 1) begin
          pal_mem[i][j] <= 8'd0;
        end
      end
    end else begin
      state <= next_state;

      // Default signals
      done <= 1'b0;

      // Cycle counter for fixed latency relative to start
      if (state == IDLE) begin
        cycle_cnt  <= 7'd0;
        start_seen <= 1'b0;
      end else begin
        if (!start_seen && (state == COUNT)) begin
          start_seen <= 1'b1;
          cycle_cnt  <= 7'd0;
        end else if (start_seen) begin
          if (cycle_cnt < 7'd127)
            cycle_cnt <= cycle_cnt + 7'd1;
        end
      end

      case (state)
        IDLE: begin
          // Initialize on IDLE
          count_idx   <= 4'd0;
          odd_count   <= 5'd0;
          candidate_k <= 4'd0;
          part_len    <= 4'd0;
          part_idx    <= 4'd0;
          pos_idx     <= 4'd0;
          left_pos    <= 4'd0;
          right_pos   <= 4'd0;
          char_idx    <= 4'd0;
          placing_pairs <= 1'b1;
          // Clear freq and pal_mem for new run
          for (i = 0; i < 16; i = i + 1) begin
            freq[i] <= 6'd0;
            for (j = 0; j < 16; j = j + 1) begin
              pal_mem[i][j] <= 8'd0;
            end
          end
          k <= 4'd0;
        end

        COUNT: begin
          // Count frequencies over n characters, one per cycle
          if (count_idx < n) begin
            // Map ASCII to one of 16 buckets (simplified)
            reg [3:0] idx;
            idx = char_index(s[count_idx]);
            freq[idx] <= freq[idx] + 6'd1;
            count_idx <= count_idx + 4'd1;
          end
        end

        CALC_K: begin
          // Compute number of odd-frequency chars
          odd_count = 5'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (freq[i][0] == 1'b1 && freq[i] != 6'd0)
              odd_count = odd_count + 5'd1;
          end

          // Find minimal k satisfying constraints
          candidate_k = (odd_count == 0) ? 4'd1 : (odd_count[3:0]);
          if (candidate_k == 4'd0)
            candidate_k = 4'd1;
          while (candidate_k <= n && (n % candidate_k) != 0) begin
            candidate_k = candidate_k + 4'd1;
          end
          if (candidate_k == 4'd0)
            candidate_k = 4'd1;
          k        <= candidate_k;
          part_len <= (candidate_k != 4'd0) ? (n / candidate_k) : 4'd0;

          // Prepare for BUILD
          part_idx      <= 4'd0;
          pos_idx       <= 4'd0;
          placing_pairs <= 1'b1;
          // Reset char_idx to scan frequencies
          char_idx      <= 4'd0;
          left_pos      <= 4'd0;
          right_pos     <= (candidate_k != 4'd0) ? (n / candidate_k) - 1'b1 : 4'd0;

          // Re-normalize freq for building: use a blocking loop copy as-is
          // (They are already counted.)
        end

        BUILD: begin
          // Simple deterministic construction using freq[] as a pool.
          // For each palindrome:
          //  1) Fill pairs from even counts
          //  2) Place centers from remaining odd counts (if part_len odd)

          // Ensure part_len non-zero to avoid issues when n==0
          if (part_idx < k && part_len != 4'd0) begin
            if (placing_pairs) begin
              // Place pairs at left_pos/right_pos
              if (left_pos < right_pos) begin
                // Find a character with at least 2 left
                if (char_idx < 4'd16) begin
                  if (freq[char_idx] >= 6'd2) begin
                    pal_mem[part_idx][left_pos]  <= {4'd0, char_idx};
                    pal_mem[part_idx][right_pos] <= {4'd0, char_idx};
                    freq[char_idx]              <= freq[char_idx] - 6'd2;
                    left_pos                    <= left_pos + 4'd1;
                    right_pos                   <= right_pos - 4'd1;
                    // stay on same char_idx to possibly use more
                  end else begin
                    char_idx <= char_idx + 4'd1;
                  end
                end else begin
                  // no more pairs available, move to center phase or next palindrome
                  placing_pairs <= 1'b0;
                  char_idx      <= 4'd0;
                end
              end else begin
                // All pairs placed or no space for more pairs
                placing_pairs <= 1'b0;
                char_idx      <= 4'd0;
              end
            end else begin
              // Place center character if odd length
              if (part_len[0] == 1'b1) begin
                // middle position
                reg [3:0] mid;
                mid = part_len >> 1;
                if (pal_mem[part_idx][mid] == 8'd0) begin
                  // Find any leftover freq (odd or even) to put as center
                  if (char_idx < 4'd16) begin
                    if (freq[char_idx] >= 6'd1) begin
                      pal_mem[part_idx][mid] <= {4'd0, char_idx};
                      freq[char_idx]         <= freq[char_idx] - 6'd1;
                      // Done with this palindrome, move to next
                      part_idx      <= part_idx + 4'd1;
                      left_pos      <= 4'd0;
                      right_pos     <= part_len - 1'b1;
                      char_idx      <= 4'd0;
                      placing_pairs <= 1'b1;
                    end else begin
                      char_idx <= char_idx + 4'd1;
                    end
                  end else begin
                    // No char found; still move on (best-effort)
                    part_idx      <= part_idx + 4'd1;
                    left_pos      <= 4'd0;
                    right_pos     <= part_len - 1'b1;
                    char_idx      <= 4'd0;
                    placing_pairs <= 1'b1;
                  end
                end else begin
                  // Center already filled (shouldn't generally happen), move on
                  part_idx      <= part_idx + 4'd1;
                  left_pos      <= 4'd0;
                  right_pos     <= part_len - 1'b1;
                  char_idx      <= 4'd0;
                  placing_pairs <= 1'b1;
                end
              end else begin
                // Even length: no center; move directly to next palindrome
                part_idx      <= part_idx + 4'd1;
                left_pos      <= 4'd0;
                right_pos     <= part_len - 1'b1;
                char_idx      <= 4'd0;
                placing_pairs <= 1'b1;
              end
            end
          end

          // After all palindromes processed, we may just idle until latency reached
        end

        DONE_S: begin
          // Assert done for 1 cycle. Outputs (k, parts) already stable.
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule