module string_factoring_weight (
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [3:0] length, // input string length (1-16)
  input [7:0] chars [15:0], // 16x8-bit ASCII characters
  output reg [4:0] weight, // resulting weight
  output reg done // high when calculation complete
);

  // Internal state machine and data structures
  typedef enum {
    S_IDLE,
    S_INIT,
    S_LOOP_L,
    S_ITER_CHECK,
    S_EXPLORE,
    S_BACKTRACK,
    S_DONE
  } state_t;

  state_t state, state_next;

  reg [4:0] l;            // current substring length being tried (1..length/2)
  reg [4:0] i;            // temporary index
  reg [4:0] k;            // temporary index for loops
  reg [4:0] segStart;     // start position of candidate segment
  reg [4:0] segLen;       // length of candidate segment (== l)
  reg [4:0] endPos;       // end position of candidate segment
  reg [4:0] start2;       // start position of 2nd copy
  reg [4:0] end2;         // end position of 2nd copy
  reg [4:0] curPos;       // current position in string (0..length)
  reg [4:0] minPos;       // best progress this outer iteration (>= curPos)
  reg [4:0] minPosNext;   // temporary holding the next best progress
  reg [4:0] bestWeight;   // minimal weight found so far
  reg foundCandidate;     // any candidate found this outer iteration?
  reg foundCandidateNext; // temp copy of foundCandidate
  reg [4:0] saved_l;
  reg [4:0] saved_curPos;
  reg [4:0] saved_minPos;
  reg [4:0] saved_bestWeight;
  reg [4:0] saved_weight;
  reg stack_valid;        // indicates stack valid for backtrack
  reg [4:0] curWeight;
  reg [4:0] nextWeight;
  reg [7:0] seen [25:0];  // up to 26 unique characters (ASCII A-Z)
  reg [7:0] seen_next [25:0];
  reg [4:0] seenCount;
  reg [4:0] seenCountNext;

  task init_caches;
    integer ii;
    for (ii = 0; ii < 26; ii = ii + 1) begin
      seen[ii] = 8'h00;
    end
    seenCount = 5'h0;
  endtask

  task reset_caches;
    integer ii;
    for (ii = 0; ii < 26; ii = ii + 1) begin
      seen_next[ii] = 8'h00;
    end
    seenCountNext = 5'h0;
  endtask

  function [4:0] char_index;
    input [7:0] c;
    // Assuming chars are uppercase letters (0x41..0x5A). Others map into [0..25] via lower 5 bits.
    char_index = c[4:0];
  endfunction

  function [4:0] weight_of_segment;
    input [4:0] segStartIn;
    input [4:0] segLenIn;
    input [7:0] seen_in [25:0];
    input [4:0] seenCountIn;
    reg [4:0] localCount;
    reg [7:0] localSeen [25:0];
    integer ii;
    reg hit;
    reg [4:0] idx;
    begin
      for (ii = 0; ii < 26; ii = ii + 1) localSeen[ii] = seen_in[ii];
      localCount = seenCountIn;
      for (ii = 0; ii < 16; ii = ii + 1) begin
        if (ii < segLenIn) begin
          idx = char_index(chars[segStartIn + ii]);
          hit = 1'b0;
          for (k = 0; k < localCount; k = k + 1) begin
            if (localSeen[k] == idx) begin
              hit = 1'b1;
              break;
            end
          end
          if (!hit) begin
            localSeen[localCount] = idx;
            localCount = localCount + 1;
          end
        end
      end
      weight_of_segment = localCount;
    end
  endfunction

  function is_valid_candidate;
    input [4:0] segStartIn;
    input [4:0] segLenIn;
    input [4:0] curPosIn;
    input [4:0] lIn;
    // Returns 1'b1 if there exists a start2 such that:
    //   - endPos = segStartIn + lIn - 1, end2 = start2 + lIn - 1
    //   - segStartIn + lIn <= start2 (non-overlapping, at least one char gap)
    //   - end2 < length (both copies fully inside string)
    //   - For all t in [0, lIn-1], chars[segStartIn + t] == chars[start2 + t]
    reg [4:0] endPosIn;
    reg [4:0] s2;
    reg [4:0] e2;
    reg [4:0] len;
    integer t;
    begin
      is_valid_candidate = 1'b0;
      endPosIn = segStartIn + lIn - 1;
      len = lIn;
      // s2 must be at least one char after endPos to avoid overlap, and leave room for a full copy
      for (s2 = endPosIn + 1; s2 + len <= length; s2 = s2 + 1) begin
        e2 = s2 + len - 1;
        // Ensure non-overlap: segStartIn + len <= s2 (already ensured by s2 start)
        // Now verify content equality
        for (t = 0; t < 16; t = t + 1) begin
          if (t < len) begin
            if (chars[segStartIn + t] != chars[s2 + t]) break;
          end else begin
            is_valid_candidate = 1'b1;
          end
        end
        if (is_valid_candidate) break;
      end
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      weight <= 5'h0;
      done <= 1'b0;
      l <= 5'h0;
      i <= 5'h0;
      k <= 5'h0;
      segStart <= 5'h0;
      segLen <= 5'h0;
      endPos <= 5'h0;
      start2 <= 5'h0;
      end2 <= 5'h0;
      curPos <= 5'h0;
      minPos <= 5'h0;
      minPosNext <= 5'h0;
      bestWeight <= 5'h1F; // big number
      foundCandidate <= 1'b0;
      foundCandidateNext <= 1'b0;
      stack_valid <= 1'b0;
      saved_l <= 5'h0;
      saved_curPos <= 5'h0;
      saved_minPos <= 5'h0;
      saved_bestWeight <= 5'h0;
      saved_weight <= 5'h0;
      curWeight <= 5'h0;
      nextWeight <= 5'h0;
      seenCount <= 5'h0;
      seenCountNext <= 5'h0;
      init_caches;
    end else begin
      // State update and datapath
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= S_INIT;
          end else begin
            state <= S_IDLE;
          end
        end

        S_INIT: begin
          // Initialize algorithm state and caches
          l <= 5'h1;
          i <= 5'h0;
          curPos <= 5'h0;
          minPos <= 5'h0;
          minPosNext <= 5'h0;
          bestWeight <= 5'h1F;
          foundCandidate <= 1'b0;
          foundCandidateNext <= 1'b0;
          stack_valid <= 1'b0;
          init_caches;
          state <= S_LOOP_L;
        end

        S_LOOP_L: begin
          // Outer loop: try substring length l from 1 to length/2
          if (l <= (length >> 1)) begin
            state <= S_ITER_CHECK;
          end else begin
            // Exhausted all l. If we made any progress (foundCandidate) we continue,
            // otherwise we are done (no factoring with a double exists).
            if (foundCandidate) begin
              // Start a new pass with l=1 and updated minPos/curPos
              l <= 5'h1;
              curPos <= minPos;
              minPos <= minPos;
              foundCandidate <= 1'b0; // reset the flag for next pass
              state <= S_LOOP_L;
            end else begin
              // No progress -> finished exploration
              weight <= bestWeight;
              done <= 1'b1;
              state <= S_DONE;
            end
          end
        end

        S_ITER_CHECK: begin
          // Check if we've reached the end with progress, or continue scanning positions i
          if (curPos >= length) begin
            // We consumed the entire string with at least one double -> compute weight
            nextWeight = weight_of_segment(5'h0, length, seen, seenCount);
            if (nextWeight < bestWeight) begin
              bestWeight <= nextWeight;
            end
            // Backtrack one level if stack valid, else finish pass
            if (stack_valid) begin
              // Restore saved state
              l <= saved_l;
              curPos <= saved_curPos;
              minPos <= saved_minPos;
              bestWeight <= saved_bestWeight;
              // Restore seen/weight
              seenCount <= seenCount;
              for (k = 0; k < 26; k = k + 1) seen[k] <= seen[k];
              curWeight <= saved_weight;
              state <= S_LOOP_L;
            end else begin
              // No stack to backtrack -> move to new pass with updated minPos
              if (minPos < length) begin
                l <= 5'h1;
                curPos <= minPos;
                foundCandidate <= 1'b0;
                state <= S_LOOP_L;
              end else begin
                // All consumed -> done
                weight <= bestWeight;
                done <= 1'b1;
                state <= S_DONE;
              end
            end
          end else begin
            // Not at end yet: scan i from curPos to length-l
            if (i <= (length - l)) begin
              segStart <= i;
              segLen <= l;
              // Compute endPos and start2 bounds
              endPos <= i + l - 1;
              start2 <= endPos + 1;
              // Precompute end2 for quick bounds checking later
              // We'll just use start2 + l - 1 during validation.
              state <= S_EXPLORE;
            end else begin
              // End of scan: finalize this outer iteration and either continue pass or new pass
              if (minPos == curPos) begin
                // No progress this pass -> no valid factoring exists
                weight <= bestWeight;
                done <= 1'b1;
                state <= S_DONE;
              end else begin
                // Make a new pass from minPos
                l <= 5'h1;
                curPos <= minPos;
                minPos <= minPos;
                foundCandidate <= 1'b0;
                state <= S_LOOP_L;
              end
            end
          end
        end

        S_EXPLORE: begin
          // Validate candidate at segStart with length l
          if (is_valid_candidate(segStart, segLen, curPos, l)) begin
            // Found a candidate: push state and recurse
            saved_l <= l;
            saved_curPos <= curPos;
            saved_minPos <= minPos;
            saved_bestWeight <= bestWeight;
            saved_weight <= curWeight;
            stack_valid <= 1'b1;

            // Update minPos with progress on this segment end
            if (endPos >= minPos) begin
              minPosNext <= endPos + 1;
              foundCandidateNext <= 1'b1;
            end else begin
              minPosNext <= minPos;
              foundCandidateNext <= foundCandidate;
            end
            minPos <= minPosNext;
            foundCandidate <= foundCandidateNext;

            // Extend weight with this segment and move l back to 1
            nextWeight = weight_of_segment(segStart, segLen, seen, seenCount);
            // Update seen and seenCount for deeper recursion
            // Prepare seen_next and seenCountNext
            reset_caches;
            for (k = 0; k < 26; k = k + 1) begin
              seen_next[k] <= seen[k];
            end
            seenCountNext = seenCount;
            for (k = 0; k < 16; k = k + 1) begin
              if (k < segLen) begin
                // copy of weight_of_segment logic to update caches
                reg [4:0] idx;
                reg hit;
                idx = char_index(chars[segStart + k]);
                hit = 1'b0;
                for (i = 0; i < seenCountNext; i = i + 1) begin
                  if (seen_next[i] == idx) begin
                    hit = 1'b1;
                    break;
                  end
                end
                if (!hit) begin
                  seen_next[seenCountNext] = idx;
                  seenCountNext = seenCountNext + 1;
                end
              end
            end
            for (k = 0; k < 26; k = k + 1) seen[k] <= seen_next[k];
            seenCount <= seenCountNext;
            curWeight <= nextWeight;

            // Recurse: start from after the matched segment
            curPos <= endPos + 1;
            l <= 5'h1;
            i <= 5'h0; // reset i for inner scanning
            state <= S_LOOP_L;
          end else begin
            // Not a valid candidate; move to next i
            i <= i + 1;
            state <= S_ITER_CHECK;
          end
        end

        S_BACKTRACK: begin
          // Not used directly; backtracking is handled in S_ITER_CHECK by restoring state.
          state <= S_ITER_CHECK;
        end

        S_DONE: begin
          // Hold done until a new start or reset
          if (!start) begin
            done <= 1'b0; // clear done when start is deasserted
            state <= S_IDLE;
          end else begin
            state <= S_DONE;
          end
        end
      endcase
    end
  end

endmodule
