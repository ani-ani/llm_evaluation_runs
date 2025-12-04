module playlist_finder(
  input clk,
  input rst_n,
  input start,
  input [3:0] max_songs,
  input [15:0][3:0] artist_ids,
  input [15:0][3:0] t_counts,
  input [15:0][3:0][3:0] next_ids,
  output reg [3:0] playlist [0:8],
  output reg done,
  output reg found
);

  typedef enum logic [1:0] { IDLE = 2'b00, SEARCHING = 2'b01, FOUND = 2'b10, FAIL = 2'b11 } state_t;
  state_t state, state_next;

  reg [3:0] path [0:8];        // current DFS path (up to 9 songs)
  reg [3:0] path_len;          // number of songs in current path (0..9)
  reg [15:0] used_artist_mask; // bit i set if artist_ids[i] has been used

  reg [3:0] cur_song;          // current node (song index) at top of path
  reg [3:0] cur_tidx;          // transition index to try next for cur_song
  reg [3:0] t_remaining;       // remaining transitions to try for cur_song

  reg [3:0] max_songs_r;       // registered max_songs to avoid metastability
  reg [15:0][3:0] artist_ids_r;
  reg [15:0][3:0] t_counts_r;
  reg [15:0][3:0][3:0] next_ids_r;

  function is_valid_transition(input [3:0] s, input [3:0] n);
    reg [3:0] i, cnt;
    begin
      is_valid_transition = 1'b0;
      cnt = t_counts_r[s];
      for (i = 0; i < 4; i = i + 1) begin
        if (i < cnt) begin
          if (next_ids_r[s][i] == n) begin
            is_valid_transition = 1'b1;
            return;
          end
        end
      end
    end
  endfunction

  function used_artist(input [3:0] s, input [15:0] mask);
    reg [3:0] aid;
    begin
      aid = artist_ids_r[s];
      used_artist = mask[aid];
    end
  endfunction

  // Register inputs on reset to initialize all song data on power-up
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_songs_r    <= 4'd9;
      artist_ids_r   <= '0;
      t_counts_r     <= '0;
      next_ids_r     <= '0;
    end else begin
      max_songs_r    <= max_songs;
      artist_ids_r   <= artist_ids;
      t_counts_r     <= t_counts;
      next_ids_r     <= next_ids;
    end
  end

  // Sequential control: state and control signals
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      found <= 1'b0;
    end else begin
      state <= state_next;
      // Outputs
      if (state_next == FOUND) begin
        done  <= 1'b1;
        found <= 1'b1;
      end else if (state_next == FAIL) begin
        done  <= 1'b1;
        found <= 1'b0;
      end else begin
        done  <= 1'b0;
        found <= 1'b0;
      end
    end
  end

  // Sequential data updates for DFS and stack mechanics
  always @(posedge clk) begin
    // Defaults: unchanged
    path_len       <= path_len;
    used_artist_mask <= used_artist_mask;
    cur_song       <= cur_song;
    cur_tidx       <= cur_tidx;
    t_remaining    <= t_remaining;
    // Maintain playlist snapshot on FOUND
    if (state == FOUND) begin
      playlist[0] <= playlist[0]; // keep value
    end
  end

  // Combinatorial next-state logic
  always_comb begin
    state_next = state; // default hold
    case (state)
      IDLE: begin
        if (start) begin
          // Initialize DFS state
          path_len       = 4'd0;
          used_artist_mask = 16'h0;
          cur_song       = 4'd0; // arbitrary default, not used until we push first song
          cur_tidx       = 4'd0;
          t_remaining    = 4'd0;
          state_next = SEARCHING;
        end
      end

      SEARCHING: begin
        // Control signals: pop and take (push) decisions for this cycle
        reg pop, take;
        pop = 1'b0;
        take = 1'b0;

        // If path full, we have a 9-song playlist -> FOUND
        if (path_len == 4'd9) begin
          state_next = FOUND;
        end else begin
          // Try to take a transition from current node if we have any remaining
          if ((path_len > 0) && (t_remaining > 0)) begin
            reg [3:0] next_song;
            next_song = next_ids_r[cur_song][cur_tidx];
            // Check bounds and uniqueness
            if ((next_song < max_songs_r) && !used_artist(next_song, used_artist_mask) &&
                is_valid_transition(cur_song, next_song)) begin
              take = 1'b1;
            end
          end

          if (take) begin
            // Push next_song onto path
            path[path_len] = next_ids_r[cur_song][cur_tidx];
            path_len = path_len + 1;
            used_artist_mask = used_artist_mask | (1 << artist_ids_r[next_song]);
            cur_song = next_song;
            cur_tidx = 4'd0; // start scanning transitions for the new node
            t_remaining = t_counts_r[next_song];
          end else begin
            // No valid take: either first node or all transitions exhausted for cur node
            if ((path_len > 0) && (t_remaining > 0)) begin
              // Still have transitions left but they are all invalid -> advance transition index
              cur_tidx = cur_tidx + 1;
              t_remaining = t_remaining - 1;
            end else begin
              // No transitions left (or path is empty), need to backtrack
              pop = 1'b1;
            end
          end
        end

        // Handle pop (backtrack) on the same cycle when no take is possible
        if (!take && (path_len > 0) && (t_remaining == 0)) begin
          // Pop current node
          path_len = path_len - 1;
          used_artist_mask = used_artist_mask & ~(1 << artist_ids_r[cur_song]);
          if (path_len > 0) begin
            // Restore parent node state
            cur_song = path[path_len - 1];
            cur_tidx = 4'd0;
            t_remaining = t_counts_r[cur_song];
            // If we just popped the last transition of parent, we will clean it up next cycle
          end
        end

        // If we popped the last item and have no more nodes, search is exhausted -> FAIL
        if (pop && (path_len == 0)) begin
          state_next = FAIL;
        end
      end

      FOUND: begin
        // Hold until start pulses again or reset
        if (start) state_next = FOUND; // remain until reset or new start
      end

      FAIL: begin
        // Hold until start pulses again or reset
        if (start) state_next = FAIL; // remain until reset or new start
      end

      default: state_next = IDLE;
    endcase
  end

  // Capture playlist when FOUND (combinatorial write; stable after FOUND asserted)
  always_comb begin
    if (state == SEARCHING && path_len == 4'd9) begin
      // Snapshot current path into playlist output
      for (int i = 0; i < 9; i = i + 1) begin
        playlist[i] = path[i];
      end
    end
  end

endmodule