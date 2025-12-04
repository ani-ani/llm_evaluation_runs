module optimal_subsequence (
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] k, // min subsequence length (1-8)
  input [15:0] data, // 16-bit input string (0=wrong, 1=correct)
  output reg [3:0] first_idx, // 1-based start index (4-bit: 1-16)
  output reg [3:0] length, // subsequence length (4-bit: 1-16)
  output reg done // high when computation completes
);

  // Behavioral description implemented:
  // 1) On start pulse, iterate over all continuous subsequences with length >= k.
  // 2) success = (# of 1s) / length (implemented as a > b comparison to avoid FP).
  // 3) Track best; ties: prefer longer length, then earlier start.
  // 4) Sequential state machine iterates lengths L from k..16, positions S from 0..(16-L).
  // 5) Compute ones using a combinational bin(count) to emulate prefix-sum behavior efficiently.
  // 6) Outputs valid when done=1.

  localparam MAXLEN = 16;
  localparam IDLE = 2'b00;
  localparam EVAL = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, state_next;
  reg [3:0] k_r, L, S, S_next;
  reg [4:0] ones; // # of 1s in current window (0..16)

  // Best-so-far trackers
  reg [3:0] best_start;  // 0-based
  reg [3:0] best_len;
  reg [4:0] best_ones;
  reg [4:0] best_ones_next;
  reg [3:0] best_start_next;
  reg [3:0] best_len_next;

  // Compare as fractions: (ones/len) vs (best_ones/best_len)
  // Equivalent to cross-multiplication with 5-bit values fits in 10 bits safely.
  wire [9:0] lhs = ones * best_len;
  wire [9:0] rhs = best_ones * L;
  wire better = (lhs > rhs);

  // Tie-breaking: prefer longer length, then earlier start
  wire eq_rate = (lhs == rhs);
  wire better_len = (L > best_len);
  wire better_start = (S < best_start);

  // Count ones in the 16-bit data (combinational; acts as our "prefix" helper)
  function [4:0] count_ones;
    input [15:0] din;
    reg [7:0] byte0;
    reg [7:0] byte1;
    reg [3:0] pop0;
    reg [3:0] pop1;
  begin
    byte0 = din[7:0];
    byte1 = din[15:8];
    // 4-bit population counts for each byte (0..8)
    pop0 = byte0[0] + byte0[1] + byte0[2] + byte0[3] +
           byte0[4] + byte0[5] + byte0[6] + byte0[7];
    pop1 = byte1[0] + byte1[1] + byte1[2] + byte1[3] +
           byte1[4] + byte1[5] + byte1[6] + byte1[7];
    count_ones = pop0 + pop1;
  end
  endfunction

  // Next-position logic for S (avoids wrap inside inner loop prematurely)
  function [3:0] next_S;
    input [3:0] curS, curL;
    reg [4:0] maxS;
  begin
    maxS = (MAXLEN - curL); // inclusive max start (0-based)
    if (curS < maxS) next_S = curS + 1'b1;
    else next_S = curS; // stay; handled by outer length incrementer
  end
  endfunction

  // Sequential block: state update and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      first_idx <= 4'd0;
      length <= 4'd0;
      k_r <= 4'd0;
      L <= 4'd0;
      S <= 4'd0;
      ones <= 5'd0;
      best_start <= 4'd0;
      best_len <= 4'd0;
      best_ones <= 5'd0;
      // Next holders
      S_next <= 4'd0;
      best_start_next <= 4'd0;
      best_len_next <= 4'd0;
      best_ones_next <= 5'd0;
    end else begin
      // Defaults (combinational overrides below per state)
      state_next <= state;
      S_next <= S;
      best_start_next <= best_start;
      best_len_next <= best_len;
      best_ones_next <= best_ones;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs and initialize
            k_r <= (k == 4'd0) ? 4'd1 : k; // safety: k must be >=1
            L <= (k == 4'd0) ? 4'd1 : k;
            S <= 4'd0;
            ones <= count_ones(data);
            // Initialize best to first window (L,0)
            best_start <= 4'd0;
            best_len <= (k == 4'd0) ? 4'd1 : k;
            best_ones <= count_ones(data);
            state_next <= EVAL;
          end else begin
            state_next <= IDLE;
          end
        end

        EVAL: begin
          // Update best if current window is better
          if (better || (eq_rate && (better_len || (better_len === 1'b0 && better_start)))) begin
            best_start_next <= S;
            best_len_next <= L;
            best_ones_next <= ones;
          end else begin
            best_start_next <= best_start;
            best_len_next <= best_len;
            best_ones_next <= best_ones;
          end

          // Advance start position S within the current length
          S_next <= next_S(S, L);

          // If finished this length, move to the next length; else recompute ones for next S
          if (S_next == S) begin
            // Completed all starts for current L, move to next L
            if (L < MAXLEN) begin
              L <= L + 1'b1;
              S <= 4'd0;
              // At the start of a new length, recompute ones at position 0
              // Evaluate data[S +: L] with S=0, i.e., bits [L-1:0]
              // This combinational read is acceptable; it effectively uses a prefix-sum approach.
              ones <= count_ones(data & ((1'b1 << L) - 1));
            end else begin
              // All lengths processed -> done
              state_next <= DONE;
              done <= 1'b1;
            end
          end else begin
            // Next start in same length
            // Compute ones for next window by bit-slicing: bits[(S_next + L - 1) : S_next]
            // This combinatorial read per cycle is equivalent to using prefix sums.
            ones <= count_ones(data >> S_next) & ((1'b1 << L) - 1);
          end

          // Propagate best trackers forward in time
          best_start <= best_start_next;
          best_len <= best_len_next;
          best_ones <= best_ones_next;
        end

        DONE: begin
          // Hold outputs valid until next start pulse
          done <= 1'b1;
          state_next <= start ? IDLE : DONE;
          if (start) begin
            // New run will initialize in IDLE path on next cycle
            L <= (k == 4'd0) ? 4'd1 : k;
            S <= 4'd0;
            ones <= count_ones(data);
            best_start <= 4'd0;
            best_len <= (k == 4'd0) ? 4'd1 : k;
            best_ones <= count_ones(data);
          end else begin
            // Maintain final results
            L <= L;
            S <= S;
            ones <= ones;
            best_start <= best_start;
            best_len <= best_len;
            best_ones <= best_ones;
          end
        end

        default: begin
          state_next <= IDLE;
        end
      endcase
    end
  end

  // Drive state updates (next-state flops)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      best_start <= 4'd0;
      best_len <= 4'd0;
      best_ones <= 5'd0;
    end else begin
      state <= state_next;
      best_start <= best_start_next;
      best_len <= best_len_next;
      best_ones <= best_ones_next;
    end
  end

  // Final output (registered) with 1-based indexing for first_idx
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      first_idx <= 4'd0;
      length <= 4'd0;
    end else begin
      if (state == DONE) begin
        first_idx <= best_start + 1'b1; // 1-based
        length <= best_len;
      end else begin
        first_idx <= 4'd0;
        length <= 4'd0;
      end
    end
  end

endmodule
