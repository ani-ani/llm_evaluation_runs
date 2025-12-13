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

  // State encoding
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    SEARCHING = 2'b01,
    FOUND     = 2'b10,
    FAIL      = 2'b11
  } state_t;

  state_t state, next_state;

  // DFS control signals
  reg [3:0] depth;                     // current depth: 0..8
  reg [3:0] stack_song [0:8];          // song id at each depth
  reg [1:0] stack_next_idx [0:8];      // next transition index to try (0..3)
  reg [15:0] used_artists;             // bitmask of used artists (max 16 artists)

  // Helper wires
  wire [3:0] cur_song;
  wire [1:0] cur_next_idx;
  wire [3:0] cur_artist;
  wire [3:0] candidate_song;
  wire [3:0] candidate_artist;
  wire [3:0] cur_t_count;

  assign cur_song      = stack_song[depth];
  assign cur_next_idx  = stack_next_idx[depth];
  assign cur_artist    = artist_ids[cur_song];
  assign cur_t_count   = t_counts[cur_song];
  assign candidate_song   = next_ids[cur_song][cur_next_idx];
  assign candidate_artist = artist_ids[candidate_song];

  // Combinational check helpers
  function automatic logic artist_used(
    input [15:0] mask,
    input [3:0] artist
  );
    artist_used = mask[artist];
  endfunction

  // Next-state / control logic
  reg        push_start_level;     // when starting from a new root song
  reg        step_valid;           // found a valid next song to go deeper
  reg        advance_idx;          // advance transition index at current depth
  reg        backtrack;            // pop stack / decrease depth
  reg        path_complete;        // found valid depth==8 path (9 songs)
  reg [3:0]  next_song_sel;        // chosen candidate song when step_valid
  reg [15:0] next_used_mask;       // updated used_artists when step_valid

  always @(*) begin
    // defaults
    next_state       = state;
    push_start_level = 1'b0;
    step_valid       = 1'b0;
    advance_idx      = 1'b0;
    backtrack        = 1'b0;
    path_complete    = 1'b0;
    next_song_sel    = 4'd0;
    next_used_mask   = used_artists;

    case (state)
      IDLE: begin
        if (start) begin
          // prepare to begin search from song 0
          next_state       = SEARCHING;
          push_start_level = 1'b1;
        end
      end

      SEARCHING: begin
        // Check if current path length is 9 songs (depth 0..8)
        if (depth == 4'd8) begin
          // Already have 9 songs on stack, found path
          path_complete = 1'b1;
          next_state    = FOUND;
        end else begin
          // Not yet complete, try transitions from current node
          if (cur_next_idx < cur_t_count) begin
            // Candidate exists
            // Candidate validity checks:
            // 1) candidate_song < max_songs
            // 2) candidate artist unused
            // 3) avoid simple self-loop if desired (not required by problem)
            if ((candidate_song < max_songs) &&
                (!artist_used(used_artists, candidate_artist))) begin
              // Valid candidate: move deeper
              step_valid     = 1'b1;
              next_song_sel  = candidate_song;
              next_used_mask = used_artists;
              next_used_mask[candidate_artist] = 1'b1;
            end else begin
              // Invalid candidate, try next transition at this depth
              advance_idx = 1'b1;
            end
          end else begin
            // No more transitions at this depth, need to backtrack
            if (depth == 4'd0) begin
              // Exhausted all roots, search failed
              next_state = FAIL;
            end else begin
              backtrack = 1'b1;
            end
          end
        end
      end

      FOUND: begin
        // Hold until next start or reset
        if (start) begin
          next_state = SEARCHING;
          push_start_level = 1'b1;
        end
      end

      FAIL: begin
        // Hold until next start or reset
        if (start) begin
          next_state = SEARCHING;
          push_start_level = 1'b1;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      done          <= 1'b0;
      found         <= 1'b0;
      depth         <= 4'd0;
      used_artists  <= 16'd0;
      for (i = 0; i < 9; i = i + 1) begin
        playlist[i]     <= 4'd0;
        stack_song[i]   <= 4'd0;
        stack_next_idx[i] <= 2'd0;
      end
    end else begin
      state <= next_state;

      // Default sticky behavior for done/found; overridden in states below
      if (state == IDLE && !start) begin
        done  <= 1'b0;
        found <= 1'b0;
      end

      case (state)
        IDLE: begin
          if (push_start_level) begin
            // Initialize DFS starting from song 0
            depth        <= 4'd0;
            used_artists <= 16'd0;
            // If max_songs > 0, pick song 0 as root; otherwise immediate FAIL
            if (max_songs != 4'd0) begin
              stack_song[0]      <= 4'd0;
              stack_next_idx[0]  <= 2'd0;
              used_artists[artist_ids[0]] <= 1'b1;
            end
            done  <= 1'b0;
            found <= 1'b0;
          end
        end

        SEARCHING: begin
          // Handle DFS mechanics
          if (path_complete) begin
            // Copy stack into playlist
            for (i = 0; i < 9; i = i + 1) begin
              playlist[i] <= stack_song[i];
            end
            done  <= 1'b1;
            found <= 1'b1;
          end else begin
            if (step_valid) begin
              // Move deeper: store candidate, reset its next_idx
              depth <= depth + 4'd1;
              stack_song[depth + 4'd1]     <= next_song_sel;
              stack_next_idx[depth + 4'd1] <= 2'd0;
              used_artists                 <= next_used_mask;

              // Also advance current depth's next index so future backtracks skip used edge
              stack_next_idx[depth] <= stack_next_idx[depth] + 2'd1;
            end else if (advance_idx) begin
              // Try next transition at current depth
              stack_next_idx[depth] <= stack_next_idx[depth] + 2'd1;
            end else if (backtrack) begin
              // Backtrack one level: remove artist of current song from mask
              // Remove artist of stack_song[depth]
              used_artists[artist_ids[stack_song[depth]]] <= 1'b0;
              depth <= depth - 4'd1;
              // Advance transition index at new depth to avoid retrying same edge
              stack_next_idx[depth - 4'd1] <= stack_next_idx[depth - 4'd1] + 2'd1;
            end
          end
        end

        FOUND: begin
          done  <= 1'b1;
          found <= 1'b1;
          if (push_start_level) begin
            // Restart search on new start pulse
            depth        <= 4'd0;
            used_artists <= 16'd0;
            if (max_songs != 4'd0) begin
              stack_song[0]      <= 4'd0;
              stack_next_idx[0]  <= 2'd0;
              used_artists[artist_ids[0]] <= 1'b1;
            end
            done  <= 1'b0;
            found <= 1'b0;
          end
        end

        FAIL: begin
          done  <= 1'b1;
          found <= 1'b0;
          if (push_start_level) begin
            // Restart search on new start pulse
            depth        <= 4'd0;
            used_artists <= 16'd0;
            if (max_songs != 4'd0) begin
              stack_song[0]      <= 4'd0;
              stack_next_idx[0]  <= 2'd0;
              used_artists[artist_ids[0]] <= 1'b1;
            end
            done  <= 1'b0;
            found <= 1'b0;
          end
        end

        default: begin
          // Should not occur; reset to IDLE
          state <= IDLE;
        end
      endcase
    end
  end

endmodule