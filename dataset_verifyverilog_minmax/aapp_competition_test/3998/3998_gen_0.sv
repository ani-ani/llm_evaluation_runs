module team_rating_equalizer(
  input clk,                // 125 MHz system clock
  input rst_n,              // active-low reset
  input start,              // pulse high to start processing
  input [7:0] r0,           // rating for player 0 (8-bit unsigned)
  input [7:0] r1,           // rating for player 1
  input [7:0] r2,           // rating for player 2
  input [7:0] r3,           // rating for player 3
  output reg [7:0] final_R, // final equal rating
  output reg [3:0] match_vec, // current match vector (1 bit per player)
  output reg valid_match,     // high when match_vec is valid
  output reg done             // high when ratings equalized
);

  // Internal registers and state definitions
  typedef enum logic [2:0] {INIT=3'b000, FIND_MAX=3'b001, SELECT_PLAYERS=3'b010, UPDATE=3'b011, CHECK=3'b100, DONE=3'b101} state_t;
  state_t state, next_state;

  reg [7:0] cur0, cur1, cur2, cur3;
  reg [7:0] nxt0, nxt1, nxt2, nxt3;

  reg [7:0] max_r, min_r;
  reg [3:0] sel_vec;

  // cycle counter for 100-cycle budget
  reg [6:0] cycle_cnt, cycle_cnt_d;
  reg budget_overflow;

  // Helper functions: max/min of two 8-bit values
  function [7:0] fmax8;
    input [7:0] a, b;
    fmax8 = (a > b) ? a : b;
  endfunction

  function [7:0] fmin8;
    input [7:0] a, b;
    fmin8 = (a < b) ? a : b;
  endfunction

  // Find max and min of 4 values
  function [7:0] find_max4;
    input [7:0] a, b, c, d;
    find_max4 = fmax8(fmax8(a, b), fmax8(c, d));
  endfunction

  function [7:0] find_min4;
    input [7:0] a, b, c, d;
    find_min4 = fmin8(fmin8(a, b), fmin8(c, d));
  endfunction

  // Determine how many players can be decremented (>=1)
  function [2:0] decr_count;
    input [7:0] a, b, c, d;
    reg [2:0] cnt;
    begin
      cnt = 3'd0;
      if (a > 8'd0) cnt = cnt + 1'd1;
      if (b > 8'd0) cnt = cnt + 1'd1;
      if (c > 8'd0) cnt = cnt + 1'd1;
      if (d > 8'd0) cnt = cnt + 1'd1;
      decr_count = cnt;
    end
  endfunction

  // Select top players with highest ratings (2-4 players, never 1 or 0)
  // Tie-breaking prefers lower index; includes at most 4 players.
  function [3:0] select_top_players;
    input [7:0] a, b, c, d;
    reg [7:0] p0, p1, p2, p3;
    reg [1:0] id0, id1, id2, id3;
    reg [7:0] t0, t1, t2, t3;
    reg [1:0] ti0, ti1, ti2, ti3;
    reg [1:0] u0, u1, u2, u3;
    reg eq01, eq23, eq02, eq13, eq03, eq12, eq13b, eq03b, eq23b;
    reg [3:0] v;
    reg [2:0] cnt;
    begin
      // Attach IDs
      p0 = a; id0 = 2'd0;
      p1 = b; id1 = 2'd1;
      p2 = c; id2 = 2'd2;
      p3 = d; id3 = 2'd3;

      // Sort network: 4 inputs to sorted (t3 >= t2 >= t1 >= t0) by rating
      // Stage 1: sort pairs
      if (p0 >= p1) begin t0 = p0; ti0 = id0; t1 = p1; ti1 = id1; end
      else          begin t0 = p1; ti0 = id1; t1 = p0; ti1 = id0; end
      if (p2 >= p3) begin t2 = p2; ti2 = id2; t3 = p3; ti3 = id3; end
      else          begin t2 = p3; ti2 = id3; t3 = p2; ti3 = id2; end

      // Stage 2: merge first pair
      if (t0 >= t2) begin u0 = t0; u1 = ti0; u2 = t2; u3 = ti2; end
      else          begin u0 = t2; u1 = ti2; u2 = t0; u3 = ti0; end

      // Stage 3: merge second pair and final arrangement
      if (t1 >= t3) begin
        // t1 vs t3, t2 vs result of (t1,t3)
        if (t1 >= t3) begin
          if (t1 >= t3) begin
            // t1 is max or equal to t3
            if (t1 >= t3) begin
              // This branch is for readability; actual final compare below
            end
          end
        end
      end

      // Simpler final sort (2-compare network)
      // 4th place
      if (u2 <= u3) begin u2 = u2; u3 = u3; end
      else          begin u3 = u2; u3 = u3; end
      // After swap, u3 is 4th, u2 is candidate 3rd

      // Determine selection vector: always 2-4 players, limited by non-zero count
      v = 4'd0;
      cnt = decr_count(a, b, c, d);
      if (cnt == 3'd0) begin
        // nothing to select, keep v=0
      end else begin
        // select highest (u1, then u0, then u2, then u3) until min(cnt,4) players, but never 1
        // Always select at least 2; we handle cnt==1 by adding next best
        // Step 1: select top candidate
        if (u1 > 8'd0) v[ u1 ] = 1'b1;
        // Step 2: select second candidate based on tie-aware ordering
        // Candidates in descending order: u1, u0, u2, u3
        // Exclude already selected, prefer non-zero, but ensure 2 total or 3/4 if cnt permits
        // We'll add by priority list
        if (u0 > 8'd0 && !v[u0]) v[u0] = 1'b1;
        else if (u2 > 8'd0 && !v[u2]) v[u2] = 1'b1;
        else if (u3 > 8'd0 && !v[u3]) v[u3] = 1'b1;

        // If we selected only 1 due to cnt==1, pick next best non-zero
        if (v != 4'd0 && (v & (v - 1)) == 0) begin
          // only one bit set
          if (u0 > 8'd0 && !v[u0]) v[u0] = 1'b1;
          else if (u2 > 8'd0 && !v[u2]) v[u2] = 1'b1;
          else if (u3 > 8'd0 && !v[u3]) v[u3] = 1'b1;
        end

        // Limit to available count if needed (cnt <= 4 always here)
        // Count ones
        if (v[0] + v[1] + v[2] + v[3] > cnt) begin
          // Remove lowest priority (u3, then u2, then u0) until match cnt
          if (v[u3]) v[u3] = 1'b0;
          if (v[u2]) v[u2] = 1'b0;
          if (v[u0]) v[u0] = 1'b0;
          if (v[u1]) v[u1] = 1'b0;
        end
        // Ensure never 0 selected
        if (v == 4'd0) v[0] = 1'b1;
        // Ensure never 1 selected if any non-zero exists
        if ((v & (v - 1)) == 0) begin
          // Add any other non-zero if present
          if (u0 > 8'd0 && !v[u0]) v[u0] = 1'b1;
          else if (u2 > 8'd0 && !v[u2]) v[u2] = 1'b1;
          else if (u3 > 8'd0 && !v[u3]) v[u3] = 1'b1;
          else if (u1 > 8'd0 && !v[u1]) v[u1] = 1'b1;
        end
      end
      select_top_players = v;
    end
  endfunction

  // State register update and outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= INIT;
      cur0    <= 8'd0;
      cur1    <= 8'd0;
      cur2    <= 8'd0;
      cur3    <= 8'd0;
      final_R <= 8'd0;
      match_vec <= 4'd0;
      valid_match <= 1'b0;
      done    <= 1'b0;
      cycle_cnt <= 7'd0;
      budget_overflow <= 1'b0;
    end else begin
      state   <= next_state;
      cur0    <= nxt0;
      cur1    <= nxt1;
      cur2    <= nxt2;
      cur3    <= nxt3;
      cycle_cnt <= cycle_cnt_d;
      // Outputs update on clock edge
      match_vec <= sel_vec;
      valid_match <= (next_state == UPDATE);
      if (next_state == DONE) begin
        final_R <= max_r;
        done    <= 1'b1;
      end else if (next_state == INIT) begin
        // clear done and final_R when entering INIT due to start
        if (state != INIT) begin
          done    <= 1'b0;
          final_R <= 8'd0;
        end
      end
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    nxt0 = cur0;
    nxt1 = cur1;
    nxt2 = cur2;
    nxt3 = cur3;
    sel_vec = 4'd0;
    max_r = 8'd0;
    min_r = 8'd0;
    next_state = state;
    cycle_cnt_d = cycle_cnt;
    budget_overflow = 1'b0;

    case (state)
      INIT: begin
        if (start) begin
          // Load inputs and start
          nxt0 = r0;
          nxt1 = r1;
          nxt2 = r2;
          nxt3 = r3;
          cycle_cnt_d = 7'd1; // first cycle consumed
          next_state = FIND_MAX;
        end else begin
          cycle_cnt_d = 7'd0;
          next_state = INIT;
        end
      end

      FIND_MAX: begin
        max_r = find_max4(cur0, cur1, cur2, cur3);
        min_r = find_min4(cur0, cur1, cur2, cur3);
        cycle_cnt_d = cycle_cnt + 1'd1;
        if (max_r == min_r) begin
          next_state = DONE;
        end else begin
          next_state = SELECT_PLAYERS;
        end
      end

      SELECT_PLAYERS: begin
        sel_vec = select_top_players(cur0, cur1, cur2, cur3);
        max_r = find_max4(cur0, cur1, cur2, cur3);
        min_r = find_min4(cur0, cur1, cur2, cur3);
        cycle_cnt_d = cycle_cnt + 1'd1;
        next_state = UPDATE;
      end

      UPDATE: begin
        // Decrement selected players by 1, but not below 0
        nxt0 = (sel_vec[0] && cur0 > 8'd0) ? (cur0 - 1'd1) : cur0;
        nxt1 = (sel_vec[1] && cur1 > 8'd0) ? (cur1 - 1'd1) : cur1;
        nxt2 = (sel_vec[2] && cur2 > 8'd0) ? (cur2 - 1'd1) : cur2;
        nxt3 = (sel_vec[3] && cur3 > 8'd0) ? (cur3 - 1'd1) : cur3;
        max_r = find_max4(nxt0, nxt1, nxt2, nxt3);
        min_r = find_min4(nxt0, nxt1, nxt2, nxt3);
        cycle_cnt_d = cycle_cnt + 1'd1;
        next_state = CHECK;
      end

      CHECK: begin
        // Check equality or budget
        if (max_r == min_r) begin
          next_state = DONE;
        end else if (cycle_cnt >= 7'd99) begin
          // budget exceeded: finalize with current max (safe bound)
          next_state = DONE;
        end else begin
          next_state = FIND_MAX;
        end
      end

      DONE: begin
        // Hold final_R and done asserted. Allow immediate restart via start.
        sel_vec = 4'd0;
        max_r = find_max4(cur0, cur1, cur2, cur3);
        min_r = find_min4(cur0, cur1, cur2, cur3);
        cycle_cnt_d = 7'd0; // reset counter for next run
        if (start) begin
          // back-to-back start
          nxt0 = r0;
          nxt1 = r1;
          nxt2 = r2;
          nxt3 = r3;
          next_state = FIND_MAX;
          cycle_cnt_d = 7'd1;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = INIT;
    endcase
  end

endmodule
