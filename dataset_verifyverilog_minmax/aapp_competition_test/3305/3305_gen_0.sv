module almost_palindrome_counter (
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [5:0] str_len, // actual string length (1-8 chars)
  input [2:0] L, // query start index (1-based, 3 bits)
  input [2:0] R, // query end index (1-based, 3 bits)
  input [7:0][4:0] char_array, // 8 characters (5-bit encoded: a=0, z=25)
  output reg [5:0] count, // almost palindromic substring count
  output reg done // high when computation complete
);

  // Internal state for 4-stage pipeline + final accumulation
  typedef enum logic [2:0] {S_IDLE=3'b000, S_RUN=3'b001, S_DONE=3'b010} state_t;
  state_t state, state_d;

  // Cycle 1: enumerate substrings and precompute per-substring pair count
  reg [5:0] start1, end1, start2, end2;
  reg [5:0] len1, len2, len3, len4;
  reg [5:0] pair_j1, pair_j2, pair_j3, pair_j4;
  reg [5:0] pair_j_max1, pair_j_max2, pair_j_max3, pair_j_max4;
  reg active1, active2, active3, active4;
  reg v1, v2, v3, v4; // valid substream flags
  reg [5:0] total_i, total_j, total_k; // substring enumeration counters

  // Cycle 3: palindrome check counters (registered in Cycle 3)
  reg [5:0] pair3_max_reg;  // capture pair_j_max3 when entering Cycle 3
  reg [5:0] pairs_done3;    // pairs processed in current substring
  reg [5:0] match_count3;   // matched symmetric pairs (k)
  reg [5:0] mismatches3;    // count of mismatched positions (m)
  reg sm3, sm2, sm1, sm0;   // swapped char holder per step (registered in Cycle 3)
  reg [5:0] swap_idx3;      // index of char to swap (registered in Cycle 3)
  reg swap_done3;           // whether swap has been chosen (registered in Cycle 3)
  reg almost_flag3;         // accumulated flag for this substring (registered in Cycle 3)

  // Cycle 4: accumulation for almost-palindromes (for the evaluated substring)
  reg substr_valid4;        // indicates the current substring evaluated in Cycle 4
  reg [5:0] total_accepted; // final accumulation register (4 cycles behind)

  // Character fetch helper
  function [4:0] get_char;
    input [5:0] idx;
    begin
      case (idx)
        6'd0: get_char = char_array[0];
        6'd1: get_char = char_array[1];
        6'd2: get_char = char_array[2];
        6'd3: get_char = char_array[3];
        6'd4: get_char = char_array[4];
        6'd5: get_char = char_array[5];
        6'd6: get_char = char_array[6];
        6'd7: get_char = char_array[7];
        default: get_char = 5'b0;
      endcase
    end
  endfunction

  // State machine next-state logic
  always_comb begin
    state_d = state;
    if (!rst_n) begin
      state_d = S_IDLE;
    end else begin
      case (state)
        S_IDLE: state_d = start ? S_RUN : S_IDLE;
        S_RUN:  state_d = S_DONE; // latch DONE for exactly 1 cycle
        S_DONE: state_d = S_IDLE; // return to idle
        default: state_d = S_IDLE;
      endcase
    end
  end

  // Main synchronous logic (clocked)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      // Reset all pipeline registers
      start1 <= 6'b0; end1 <= 6'b0; start2 <= 6'b0; end2 <= 6'b0;
      len1 <= 6'b0; len2 <= 6'b0; len3 <= 6'b0; len4 <= 6'b0;
      pair_j1 <= 6'b0; pair_j2 <= 6'b0; pair_j3 <= 6'b0; pair_j4 <= 6'b0;
      pair_j_max1 <= 6'b0; pair_j_max2 <= 6'b0; pair_j_max3 <= 6'b0; pair_j_max4 <= 6'b0;
      active1 <= 1'b0; active2 <= 1'b0; active3 <= 1'b0; active4 <= 1'b0;
      v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0; v4 <= 1'b0;
      total_i <= 6'b0; total_j <= 6'b0; total_k <= 6'b0;
      pair3_max_reg <= 6'b0; pairs_done3 <= 6'b0; match_count3 <= 6'b0; mismatches3 <= 6'b0;
      sm3 <= 1'b0; sm2 <= 1'b0; sm1 <= 1'b0; sm0 <= 1'b0; swap_idx3 <= 6'b0; swap_done3 <= 1'b0; almost_flag3 <= 1'b0;
      substr_valid4 <= 1'b0; total_accepted <= 6'b0;
      count <= 6'b0; done <= 1'b0;
    end else begin
      // State update
      state <= state_d;
      done <= (state == S_RUN); // done in the 5th cycle of the 4-stage pipeline

      // Total substring enumeration counters
      if (state == S_IDLE) begin
        total_i <= 6'b0; total_j <= 6'b0; total_k <= 6'b0;
      end else begin
        // Enumerate start indices (i) over [L-1, R-1]
        total_i <= (state == S_RUN) ? (total_i + 1) : total_i;
        // Enumerate end indices (j) from i to R-1
        if (state == S_RUN) begin
          if (total_j < total_i) total_j <= total_i;
          else if (total_j < R) total_j <= total_j + 1;
        end
        // If all substrings for this start are done, move to next start
        if (state == S_RUN) begin
          if (total_j >= R) begin
            total_j <= total_i;
          end
        end
        // K counter marks when all substrings are emitted (after R-L+1 starts)
        if (state == S_RUN) begin
          if (total_i < (L - 1)) total_k <= 6'b0;
          else if (total_i < (R)) total_k <= total_k + (total_j == (L - 1) ? 1 : 0);
        end
      end

      // Cycle 1: compute start/end and pair_j_max for this substring
      if (state == S_IDLE) begin
        start1 <= 6'b0; end1 <= 6'b0; active1 <= 1'b0; v1 <= 1'b0; pair_j1 <= 6'b0; pair_j_max1 <= 6'b0; len1 <= 6'b0;
      end else begin
        active1 <= (state == S_RUN);
        if (state == S_RUN) begin
          start1 <= total_i;
          end1 <= total_j;
          len1 <= (end1 - start1 + 1);
          // For a substring of length Ls, pairs to check are floor(Ls/2)
          pair_j1 <= 6'b0;
          pair_j_max1 <= (end1 - start1) >> 1; // floor((len)/2)
          v1 <= (total_i >= (L - 1)) && (total_i < R) && (total_j >= total_i) && (total_j < R);
        end else begin
          v1 <= 1'b0;
        end
      end

      // Cycle 2: stream pair index for the current substring (pipeline register from C1)
      start2 <= start1; end2 <= end1; len2 <= len1; active2 <= active1; v2 <= v1; pair_j2 <= pair_j1; pair_j_max2 <= pair_j_max1;

      // Cycle 3: palindrome/swap check logic (registered within this cycle)
      start3: begin
        logic [4:0] c_left, c_right;
        logic [5:0] idx_left, idx_right;
        logic last_pair;
        logic [5:0] next_pairs_done, next_mismatches, next_match_count;
        logic [5:0] next_swap_idx;
        logic next_swap_done, next_almost_flag;
        logic [4:0] next_sm3, next_sm2, next_sm1, next_sm0;

        // default holds (for reset or invalid stream)
        c_left = 5'b0; c_right = 5'b0; idx_left = 6'b0; idx_right = 6'b0;
        last_pair = 1'b0;
        next_pairs_done = 6'b0;
        next_mismatches = mismatches3;
        next_match_count = match_count3;
        next_swap_idx = swap_idx3;
        next_swap_done = swap_done3;
        next_almost_flag = almost_flag3;
        next_sm3 = sm3; next_sm2 = sm2; next_sm1 = sm1; next_sm0 = sm0;

        if (active2 && v2) begin
          // Capture per-substring constants at start of new substring
          if (pair_j2 == 6'b0) begin
            pair3_max_reg <= pair_j_max2;
            pairs_done3 <= 6'b0;
            match_count3 <= 6'b0;
            mismatches3 <= 6'b0;
            swap_done3 <= 1'b0;
            almost_flag3 <= 1'b0; // start as palindrome; will be cleared if violation found
            sm3 <= 1'b0; sm2 <= 1'b0; sm1 <= 1'b0; sm0 <= 1'b0;
            swap_idx3 <= 6'b0;
          end

          // Indices to compare in this pair
          idx_left = start2 + pair_j2;
          idx_right = end2 - pair_j2;
          c_left = get_char(idx_left);
          c_right = get_char(idx_right);

          // Update counts for this pair
          next_pairs_done = pairs_done3 + 1;
          next_mismatches = mismatches3;
          next_match_count = match_count3;
          next_swap_idx = swap_idx3;
          next_swap_done = swap_done3;
          next_almost_flag = almost_flag3;
          next_sm3 = sm3; next_sm2 = sm2; next_sm1 = sm1; next_sm0 = sm0;

          if (c_left == c_right) begin
            // Matching pair: count it
            next_match_count = match_count3 + 1;
          end else begin
            // Mismatched pair handling
            next_mismatches = mismatches3 + 1;

            if (!swap_done3) begin
              // First time we see a mismatch -> potential single-swap candidate
              if ((c_left == sm0) || (sm0 == 5'b0)) begin
                // Capture left char to swap with later
                next_sm3 = c_left;  // store for now in sm3 to keep pipeline timing
                next_sm1 = c_left;  // sm1 will hold char at idx_left
                next_sm2 = c_right; // sm2 will hold char at idx_right
                next_swap_idx = idx_left;
                next_swap_done = 1'b0; // will be verified next cycle
              end else if (c_left == sm1) begin
                // We already have c_left stored in sm1 from previous mismatch
                next_sm2 = c_right;
                next_swap_done = 1'b1; // now verify in the next step
              end else if (c_left == sm2) begin
                // Symmetric case: use previous swap candidate
                next_sm1 = sm1;
                next_swap_done = 1'b1;
              end else begin
                // More than 2 distinct chars involved: cannot fix with one swap
                next_almost_flag = 1'b0;
              end

              // If a swap has already been recorded, check if current mismatch can be fixed by it
            end else if (swap_done3) begin
              // This is the 2nd mismatch: check if swapping idx_left with previous swap_idx fixes both
              // That requires char at idx_left equals the previously stored sm2, and sm3 equals char at idx_right
              if ((c_left == sm2) && (c_right == sm3)) begin
                // Both mismatches will be fixed by the single swap
                next_almost_flag = 1'b1;
              end else begin
                next_almost_flag = 1'b0; // cannot fix with one swap
              end
            end
          end

          // Finish this substring when all pairs processed
          if (pair_j2 == pair_j_max2) last_pair = 1'b1;
          else last_pair = 1'b0;
        end else begin
          // Inactive stream -> hold defaults
          last_pair = 1'b0;
        end

        // Finalize cycle registers for Cycle 3
        start3 <= start2; end3 <= end2; len3 <= len2; active3 <= active2; v3 <= v2; pair_j3 <= pair_j2; pair_j_max3 <= pair_j_max2;
        pairs_done3 <= next_pairs_done;
        match_count3 <= next_match_count;
        mismatches3 <= next_mismatches;
        swap_idx3 <= next_swap_idx;
        swap_done3 <= next_swap_done;
        almost_flag3 <= next_almost_flag;
        sm3 <= next_sm3; sm2 <= next_sm2; sm1 <= next_sm1; sm0 <= next_sm0;
        substr_valid3 <= (active2 && v2); // carry valid for Cycle 4
        end3 <= end2; start3 <= start2; len3 <= len2; // explicit copy for clarity
        last_pair3 <= last_pair;
      end

      // Cycle 4: accumulate for the substring evaluated in Cycle 3
      start4: begin
        logic is_almost;
        // A substring is an almost-palindrome if:
        // - all pairs matched (palindrome), OR
        // - exactly two mismatches and a single-swap fixes them (flag set in C3)
        is_almost = (substr_valid3 && ((mismatches3 == 0) || (mismatches3 == 2 && almost_flag3)));
        substr_valid4 <= is_almost;
        if (is_almost) total_accepted <= total_accepted + 1;
        // also register-through to output staging (count and done are set one cycle later in FSM)
        start4_reg <= start3; end4_reg <= end3; len4_reg <= len3; active4 <= active3; v4 <= v3;
      end

      // Final pipeline: wire to outputs (done is controlled by FSM separately)
      count <= (state == S_DONE) ? total_accepted : 6'b0;

      // Keep only essential pipeline signals here; logic already handled above
    end
  end

endmodule
