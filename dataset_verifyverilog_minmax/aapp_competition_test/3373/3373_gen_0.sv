module longest_balanced_parentheses (
  input clk,                // clock
  input rst_n,              // active-low reset
  input start,              // pulse high to start computation
  input [5:0] pieces [0:2], // Array of 3 pieces (6-bit strings) - '('=1, ')'=0
  output reg [4:0] max_length, // Maximum balanced length (0-30)
  output reg done              // High when computation complete
);

  // --- Precompute per-piece metrics (combinational) ---
  // For each piece (6 bits):
  //   piece_balance: sum(1) - sum(0)
  //   min_prefix: minimum prefix sum (can be negative)
  //   max_valid_piece: longest balanced substring entirely within the piece
  //   is_balanced: 1 if the entire piece is balanced
  function [3:0] f_min4 (input [3:0] a, input [3:0] b);
    f_min4 = (a < b) ? a : b;
  endfunction

  function [4:0] f_max5 (input [4:0] a, input [4:0] b);
    f_max5 = (a > b) ? a : b;
  endfunction

  function [3:0] f_min5 (input signed [3:0] a, input signed [3:0] b);
    f_min5 = (a < b) ? a : b;
  endfunction

  // For each piece (0..2), compute:
  //   balance[i], minPref[i], maxValid[i], isBalanced[i]
  reg signed [3:0] balance [0:2];
  reg signed [3:0] minPref [0:2];
  reg [4:0]        maxValid [0:2];
  reg              isBalanced [0:2];

  reg [2:0] j;
  reg [5:0] bit_j;
  reg signed [3:0] running;
  reg signed [3:0] minrunning;
  reg [4:0] best;
  reg signed [3:0] startSum;
  reg signed [3:0] endSum;

  always @(*) begin
    for (j = 0; j < 3; j = j + 1) begin
      running     = 0;
      minrunning  = 0;
      best        = 0;
      startSum    = 0;
      endSum      = 0;
      for (bit_j = 0; bit_j < 6; bit_j = bit_j + 1) begin
        bit_j = bit_j; // avoid warnings
        if (pieces[j][bit_j]) begin
          running = running + 1;
          endSum = endSum + 1;
        end else begin
          running = running - 1;
          endSum = endSum - 1;
        end
        if (running < minrunning) minrunning = running;
        if (running == 0) best = bit_j + 1;
      end
      balance[j]     = endSum;       // total balance of the piece
      minPref[j]     = minrunning;   // minimum prefix sum
      maxValid[j]    = best;         // longest balanced substring inside piece
      isBalanced[j]  = (endSum == 0) && (minrunning >= 0);
    end
  end

  // --- State machine to combine pieces (3 cycles) ---
  localparam S_IDLE = 2'b00;
  localparam S_RUN  = 2'b01;
  localparam S_DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [1:0] piece_idx; // 0, 1, 2 across the 3 cycles

  // Sequential: state and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      piece_idx  <= 2'b0;
      max_length <= 5'b0;
      done       <= 1'b0;
    end else begin
      state      <= next_state;

      if (state == S_IDLE) begin
        piece_idx  <= 2'b0;
        max_length <= 5'b0;
        done       <= 1'b0;
      end else if (state == S_RUN) begin
        piece_idx  <= piece_idx + 1; // 0->1->2
        // Update max_length each cycle with the best valid concatenated length so far
        max_length <= f_max5(max_length, best_len_current);
        done       <= 1'b0;
      end else begin // S_DONE
        piece_idx  <= 2'b0;
        done       <= 1'b1;
        // keep max_length unchanged
      end
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      S_IDLE: next_state = start ? S_RUN : S_IDLE;
      S_RUN:  next_state = (piece_idx == 2'd2) ? S_DONE : S_RUN;
      S_DONE: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // Best length achievable after combining pieces[0..piece_idx]
  reg [4:0] best_len_current;
  reg signed [3:0] curBal, minCur;
  reg [4:0] curLen;

  always @(*) begin
    // Defaults (safe for S_IDLE)
    best_len_current = 5'b0;

    if (state == S_RUN) begin
      curLen = piece_idx * 6;  // 0, 6, 12 after each cycle
      curBal = 0;
      minCur = 0;

      // Accumulate across selected pieces
      if (piece_idx >= 2'd0) begin
        curBal = curBal + balance[0];
        minCur = f_min5(minCur, minPref[0]);
      end
      if (piece_idx >= 2'd1) begin
        curBal = curBal + balance[1];
        minCur = f_min5(minCur, curBal + minPref[1]);
      end
      if (piece_idx >= 2'd2) begin
        curBal = curBal + balance[2];
        minCur = f_min5(minCur, curBal + minPref[2]);
      end

      // Extend previous valid prefix with next piece if the total stays balanced
      if (minCur >= 0) best_len_current = curLen + 6;
      else             best_len_current = 5'b0;

      // Consider longest substring fully contained in the last processed piece
      case (piece_idx)
        2'd0: best_len_current = f_max5(best_len_current, maxValid[0]);
        2'd1: best_len_current = f_max5(best_len_current, maxValid[1]);
        2'd2: best_len_current = f_max5(best_len_current, maxValid[2]);
      endcase
    end
  end

endmodule