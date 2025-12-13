module longest_repeating_substring(
  input  logic                clk,
  input  logic                rst_n,
  input  logic                start,
  input  logic [15:0][7:0]    str,
  input  logic [3:0]          length,
  output logic [3:0]          max_len,
  output logic                done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT_LEN  = 3'd1,
    S_INIT_I    = 3'd2,
    S_INIT_J    = 3'd3,
    S_INIT_K    = 3'd4,
    S_COMPARE   = 3'd5,
    S_NEXT_LEN  = 3'd6,
    S_DONE      = 3'd7
  } state_t;

  state_t state, next_state;

  // Counters / indices
  logic [3:0] current_len;      // 1..15
  logic [3:0] i_idx;            // start index of first substring
  logic [3:0] j_idx;            // start index of second substring
  logic [3:0] k_idx;            // character index within substring

  // Derived bounds
  logic [4:0] max_start_idx;    // length - current_len

  // Internal flags
  logic       found_match;
  logic       checking;

  // 9-bit cycle counter for latency constraint (not used for control stop)
  logic [8:0] cycle_cnt;

  // Combinational: max_start_idx
  always_comb begin
    if (length > current_len)
      max_start_idx = length - current_len; // valid start indices: 0..(length-current_len)
    else
      max_start_idx = 5'd0;
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      max_len     <= 4'd0;
      done        <= 1'b0;
      current_len <= 4'd0;
      i_idx       <= 4'd0;
      j_idx       <= 4'd0;
      k_idx       <= 4'd0;
      found_match <= 1'b0;
      checking    <= 1'b0;
      cycle_cnt   <= 9'd0;
    end else begin
      state <= next_state;

      // Cycle counter: runs while not in IDLE
      if (state != S_IDLE && !done)
        cycle_cnt <= cycle_cnt + 9'd1;
      else if (state == S_IDLE)
        cycle_cnt <= 9'd0;

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          max_len     <= 4'd0;
          current_len <= 4'd0;
          i_idx       <= 4'd0;
          j_idx       <= 4'd0;
          k_idx       <= 4'd0;
          found_match <= 1'b0;
          checking    <= 1'b0;
        end

        // Initialize current_len = min(length-1, 15)
        S_INIT_LEN: begin
          done        <= 1'b0;
          found_match <= 1'b0;
          checking    <= 1'b0;
          if (length > 4'd1) begin
            if ((length - 4'd1) > 4'd15)
              current_len <= 4'd15;
            else
              current_len <= length - 4'd1;
          end else begin
            current_len <= 4'd0; // length <=1, no repeating substring
          end
        end

        // Initialize i_idx for the current length
        S_INIT_I: begin
          found_match <= 1'b0;
          checking    <= 1'b0;
          i_idx       <= 4'd0;
        end

        // Initialize j_idx for given i_idx
        S_INIT_J: begin
          j_idx       <= i_idx + 4'd1;
          found_match <= 1'b0;
          checking    <= 1'b0;
        end

        // Initialize k_idx for new (i,j) pair
        S_INIT_K: begin
          k_idx    <= 4'd0;
          checking <= 1'b1; // start comparing
        end

        // Perform character-by-character compare for current (i,j,current_len)
        S_COMPARE: begin
          if (checking) begin
            if (str[i_idx + k_idx] != str[j_idx + k_idx]) begin
              // mismatch: stop checking this pair
              checking <= 1'b0;
            end else begin
              // match for this character
              if (k_idx + 4'd1 == current_len) begin
                // Entire substring matches
                checking    <= 1'b0;
                found_match <= 1'b1;
              end else begin
                // Continue with next character
                k_idx <= k_idx + 4'd1;
              end
            end
          end
        end

        // Decide next length if none found for this length
        S_NEXT_LEN: begin
          found_match <= 1'b0;
          checking    <= 1'b0;
          if (current_len > 4'd1)
            current_len <= current_len - 4'd1;
          else
            current_len <= 4'd0; // triggers done with 0
        end

        // Latch result
        S_DONE: begin
          done <= 1'b1;
          // max_len is set in next_state logic when match found or at zero-length exit
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT_LEN;
      end

      S_INIT_LEN: begin
        if (current_len == 4'd0) begin
          // No valid length to check
          next_state = S_DONE;
        end else begin
          next_state = S_INIT_I;
        end
      end

      S_INIT_I: begin
        // Check if i_idx is within bound for this length
        if (i_idx > max_start_idx) begin
          // No positions left for this length
          next_state = S_NEXT_LEN;
        end else begin
          next_state = S_INIT_J;
        end
      end

      S_INIT_J: begin
        if (j_idx > max_start_idx) begin
          // No more j for this i, move to next i
          next_state = S_INIT_I;
        end else begin
          next_state = S_INIT_K;
        end
      end

      S_INIT_K: begin
        // Immediately go to compare on next cycle
        next_state = S_COMPARE;
      end

      S_COMPARE: begin
        if (checking) begin
          // still comparing; remain until mismatch or full match
          next_state = S_COMPARE;
        end else begin
          // comparison for this pair finished
          if (found_match) begin
            // Found longest for this current_len
            next_state = S_DONE;
          end else begin
            // Try next j
            if (j_idx + 4'd1 > max_start_idx) begin
              // no more j; go to next i
              if (i_idx + 4'd1 > max_start_idx) begin
                // no more i; reduce length
                next_state = S_NEXT_LEN;
              end else begin
                next_state = S_INIT_I;
              end
            end else begin
              // more j values
              next_state = S_INIT_J;
            end
          end
        end
      end

      S_NEXT_LEN: begin
        if (current_len == 4'd0) begin
          // no repeating substring found
          next_state = S_DONE;
        end else begin
          next_state = S_INIT_I;
        end
      end

      S_DONE: begin
        // Wait for start to be deasserted then asserted again for new run
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Output / index update dependent on decisions (separate combinational for clarity)
  // This block updates indices and max_len that depend on transitions out of S_COMPARE and others.
  // Implemented as part of sequential block using current/next_state relationships.

  // Additional sequential block to handle index increments and max_len updates cleanly
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_len <= 4'd0;
      i_idx   <= 4'd0;
      j_idx   <= 4'd0;
    end else begin
      // Handle index progressions when state changes
      if (state == S_COMPARE && !checking && !found_match) begin
        // Finished this (i,j) pair without match
        if (j_idx + 4'd1 <= max_start_idx) begin
          // Next j
          j_idx <= j_idx + 4'd1;
        end else if (i_idx + 4'd1 <= max_start_idx) begin
          // Next i, reset j will occur in S_INIT_J
          i_idx <= i_idx + 4'd1;
        end
      end else if (state == S_INIT_LEN && next_state == S_INIT_I) begin
        // Start with first i
        i_idx <= 4'd0;
      end else if (state == S_NEXT_LEN && next_state == S_INIT_I) begin
        // New length, restart i
        i_idx <= 4'd0;
      end else if (state == S_INIT_J && next_state == S_INIT_K) begin
        // j already set in main seq block
      end else if (state == S_INIT_J && next_state == S_INIT_I) begin
        // No j; handled via i increment in COMPARE block or here if needed
      end

      // Update max_len when match found and moving to DONE
      if (state == S_COMPARE && !checking && found_match && next_state == S_DONE) begin
        max_len <= current_len;
      end

      // If no substring found at all and going to DONE with current_len==0
      if (state == S_NEXT_LEN && current_len == 4'd0 && next_state == S_DONE) begin
        max_len <= 4'd0;
      end

      // Clear indices when going IDLE
      if (state == S_DONE && next_state == S_IDLE) begin
        i_idx <= 4'd0;
        j_idx <= 4'd0;
      end
    end
  end

endmodule