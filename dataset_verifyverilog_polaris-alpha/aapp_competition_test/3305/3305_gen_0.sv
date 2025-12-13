module almost_palindrome_counter (
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [5:0] str_len, // actual string length (1-8 chars) - not heavily used since L/R bound the segment
  input [2:0] L, // query start index (1-based, 3 bits)
  input [2:0] R, // query end index (1-based, 3 bits)
  input [7:0][4:0] char_array, // 8 characters (5-bit encoded: a=0, z=25)
  output reg [5:0] count, // almost palindromic substring count
  output reg done // high when computation complete
);

  // Internal state machine for fixed 5-cycle latency
  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_C1    = 3'd1, // precompute substring masks
    S_C2    = 3'd2, // check exact palindromes
    S_C3    = 3'd3, // check almost palindromes (single swap)
    S_C4    = 3'd4, // accumulate counts
    S_C5    = 3'd5  // output valid
  } state_t;

  state_t state, next_state;

  // Derived bounds
  reg [2:0] L0, R0;          // 0-based indices
  reg [3:0] seg_len;         // length of [L0..R0]
  reg [5:0] total_sub;       // total substrings count in segment

  // For each substring index i (0..total_sub-1):
  // start_i = L0 + off_s[i]
  // end_i   = start_i + off_len[i]
  // Precompute using small arrays (max substrings for length 8 is 36)
  reg [2:0] off_s   [0:35];  // start offset from L0
  reg [3:0] off_len [0:35];  // length-1 (i.e., end-start)

  // Per-substring flags/results
  reg is_pal        [0:35];
  reg is_almost_pal [0:35];

  // Accumulation
  reg [5:0] acc_count;

  integer i;

  // Next-state logic (simple linear progression when start asserted)
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE:  next_state = start ? S_C1 : S_IDLE;
      S_C1:    next_state = S_C2;
      S_C2:    next_state = S_C3;
      S_C3:    next_state = S_C4;
      S_C4:    next_state = S_C5;
      S_C5:    next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential state + core logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      count      <= 6'd0;
      done       <= 1'b0;
      L0         <= 3'd0;
      R0         <= 3'd0;
      seg_len    <= 4'd0;
      total_sub  <= 6'd0;
      acc_count  <= 6'd0;
      // Clear arrays
      for (i = 0; i < 36; i = i + 1) begin
        off_s[i]       <= 3'd0;
        off_len[i]     <= 4'd0;
        is_pal[i]      <= 1'b0;
        is_almost_pal[i]<= 1'b0;
      end
    end else begin
      state <= next_state;

      case (state)
        // IDLE: wait for start, clear outputs
        S_IDLE: begin
          done      <= 1'b0;
          count     <= 6'd0;
          acc_count <= 6'd0;
          if (start) begin
            // Capture L/R (1-based to 0-based)
            L0      <= (L > 0) ? (L - 1) : 3'd0;
            R0      <= (R > 0) ? (R - 1) : 3'd0;
          end
        end

        // Cycle 1: Precompute all substring start/end (encoded)
        S_C1: begin
          done <= 1'b0;

          // Compute segment length (assume L<=R and within str_len)
          seg_len <= (R0 >= L0) ? (R0 - L0 + 1) : 4'd0;

          // Generate substring offsets
          // For segment of length N: total_sub = N*(N+1)/2
          // Enumerate in nested form: for s in 0..N-1, for e in s..N-1
          integer s, e, idx;
          idx = 0;
          if ((R0 >= L0)) begin
            for (s = 0; s < 8; s = s + 1) begin
              if (s < seg_len) begin
                for (e = s; e < 8; e = e + 1) begin
                  if (e < seg_len) begin
                    if (idx < 36) begin
                      off_s[idx]   <= s[2:0];
                      off_len[idx] <= (e - s)[3:0];
                      idx = idx + 1;
                    end
                  end
                end
              end
            end
          end
          total_sub <= idx[5:0];

          // Clear flags for safety
          for (i = 0; i < 36; i = i + 1) begin
            is_pal[i]       <= 1'b0;
            is_almost_pal[i]<= 1'b0;
          end

          acc_count <= 6'd0;
        end

        // Cycle 2: For each substring, check exact palindrome
        S_C2: begin
          done <= 1'b0;
          integer idx;
          for (idx = 0; idx < 36; idx = idx + 1) begin
            if (idx < total_sub) begin
              // length = off_len[idx] + 1
              integer len;
              len = off_len[idx] + 1;
              integer j;
              reg pal;
              pal = 1'b1;
              for (j = 0; j < 8; j = j + 1) begin
                if (j < (len >> 1)) begin
                  // Compute indices in char_array
                  // start index = L0 + off_s[idx]
                  // mirrored positions within substring
                  reg [2:0] s_idx;
                  reg [2:0] left_idx, right_idx;
                  s_idx    = L0 + off_s[idx];
                  left_idx = s_idx + j[2:0];
                  right_idx= s_idx + (len - 1 - j)[2:0];
                  if (char_array[left_idx] != char_array[right_idx]) begin
                    pal = 1'b0;
                  end
                end
              end
              is_pal[idx] <= pal;
            end else begin
              is_pal[idx] <= 1'b0;
            end
          end
        end

        // Cycle 3: For non-palindromes, check if one swap can make palindrome
        S_C3: begin
          done <= 1'b0;
          integer idx;
          for (idx = 0; idx < 36; idx = idx + 1) begin
            if (idx < total_sub) begin
              if (is_pal[idx]) begin
                is_almost_pal[idx] <= 1'b1; // already palindrome qualifies
              end else begin
                // Evaluate if exactly one swap within the substring
                integer len;
                len = off_len[idx] + 1;
                integer s_idx_int;
                s_idx_int = L0 + off_s[idx];

                // We'll search for a pair (p,q) s.t. swapping makes palindrome.
                // Brute-force for small len (<=8): O(len^3) but bounded small.
                reg found;
                found = 1'b0;

                integer p, q, t, lpos, rpos;
                for (p = 0; p < 8 && !found; p = p + 1) begin
                  if (p < len && !found) begin
                    for (q = p + 1; q < 8 && !found; q = q + 1) begin
                      if (q < len && !found) begin
                        // Check palindrome if swapping positions p,q
                        reg pal_after_swap;
                        pal_after_swap = 1'b1;
                        for (t = 0; t < 8; t = t + 1) begin
                          if (t < (len >> 1)) begin
                            lpos = t;
                            rpos = len - 1 - t;
                            // Map to array indices with hypothetical swap
                            reg [2:0] l_idx, r_idx;
                            // physical indices in substring before swap
                            l_idx = s_idx_int + lpos;
                            r_idx = s_idx_int + rpos;

                            // helper function via logic: value at position pos after swap
                            function automatic [4:0] get_swapped_val;
                              input integer pos;
                              input integer sp;
                              input integer sq;
                              input integer base;
                              begin
                                if (pos == sp)
                                  get_swapped_val = char_array[base + sq];
                                else if (pos == sq)
                                  get_swapped_val = char_array[base + sp];
                                else
                                  get_swapped_val = char_array[base + pos];
                              end
                            endfunction

                            if (get_swapped_val(lpos, p, q, s_idx_int) !=
                                get_swapped_val(rpos, p, q, s_idx_int)) begin
                              pal_after_swap = 1'b0;
                            end
                          end
                        end
                        if (pal_after_swap) begin
                          found = 1'b1;
                        end
                      end
                    end
                  end
                end

                is_almost_pal[idx] <= found;
              end
            end else begin
              is_almost_pal[idx] <= 1'b0;
            end
          end
        end

        // Cycle 4: Accumulate counts of valid substrings
        S_C4: begin
          done <= 1'b0;
          acc_count <= 6'd0;
          integer idx;
          for (idx = 0; idx < 36; idx = idx + 1) begin
            if (idx < total_sub) begin
              if (is_almost_pal[idx]) begin
                acc_count <= acc_count + 6'd1;
              end
            end
          end
        end

        // Cycle 5: Final count and done
        S_C5: begin
          count <= acc_count;
          done  <= 1'b1;
        end

        default: begin
          // Safety defaults
          done      <= 1'b0;
          count     <= 6'd0;
          acc_count <= 6'd0;
        end
      endcase
    end
  end

endmodule