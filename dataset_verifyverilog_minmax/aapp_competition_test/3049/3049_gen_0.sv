module sub_cipher_matcher (
  input clk,
  input rst_n,
  input start,
  input [79:0] encrypted_msg, // 16 chars x 5 bits
  input [19:0] fragment,       // 4 chars x 5 bits
  output reg [4:0] count,      // number of valid matches (0-16)
  output reg done              // high when computation completes
);

  // --- Parameters and types ---
  localparam NPOS = 16;              // Max number of starting positions (16 - 4 + 1)
  localparam FLEN = 4;               // Fragment length in characters
  localparam W = 5;                  // Bits per character (a-z)
  localparam POS_BITS = $clog2(NPOS+1);

  typedef logic [W-1:0] char5_t;

  // States
  typedef enum logic [2:0] {
    ST_IDLE   = 3'b000,
    ST_CHECK  = 3'b001,
    ST_ITER   = 3'b010,
    ST_VERIFY = 3'b011,
    ST_DONE   = 3'b100
  } state_t;
  state_t state, next_state;

  // --- Verification registers (for the current position) ---
  char5_t frag2_map[0:25];      // Mapping: fragment char -> message char (partial)
  logic [NPOS-1:0] active;      // Which positions are still valid so far
  logic [NPOS-1:0] active_next; // Next value of 'active'

  // --- Iteration control ---
  logic [POS_BITS-1:0] pos;      // Current starting position (0..NPOS-1)
  logic [2:0] fidx;             // Fragment character index (0..3)
  logic valid_pos;              // Precomputed length validity for current pos

  // Convenience signals
  wire [4:0] frag_len;          // Fragment length is fixed at 4 (but kept for clarity)
  wire [4:0] msg_len;           // Message length is 16
  assign frag_len = 5'd4;
  assign msg_len  = 5'd16;

  // --- Helper: set/clear a single bit in a vector ---
  function [NPOS-1:0] set_bit(input [NPOS-1:0] vec, input [POS_BITS-1:1] idx, input bit val);
    set_bit = vec;
    if (val) set_bit[idx] = 1'b1;
    else     set_bit[idx] = 1'b0;
  endfunction

  function [NPOS-1:0] clear_bit(input [NPOS-1:0] vec, input [POS_BITS-1:1] idx);
    clear_bit = vec;
    clear_bit[idx] = 1'b0;
  endfunction

  // --- FSM sequential logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      count <= 5'd0;
      done  <= 1'b0;
      active <= {NPOS{1'b0}};
      pos    <= {POS_BITS{1'b0}};
      fidx   <= 3'd0;
      // Initialize mapping to a known value (unused in IDLE, but keeps sim sane)
      for (int k = 0; k < 26; k++) frag2_map[k] <= {W{1'b0}};
    end else begin
      state <= next_state;
      done  <= (next_state == ST_DONE);
      if (state == ST_IDLE) begin
        count <= 5'd0;
        active <= {NPOS{1'b0}};
        pos    <= {POS_BITS{1'b0}};
        fidx   <= 3'd0;
      end else if (state == ST_CHECK) begin
        // Length check handled by valid_pos; no register changes needed
      end else if (state == ST_ITER) begin
        // Start checking a new position
        if (valid_pos) begin
          // Activate exactly this position
          for (int k = 0; k < NPOS; k++) active[k] = 1'b0;
          active[pos] = 1'b1;
          // Reset mapping (fresh position)
          for (int k = 0; k < 26; k++) frag2_map[k] <= {W{1'b0}};
        end else begin
          // Not a valid starting position -> nothing to do
        end
      end else if (state == ST_VERIFY) begin
        // Update mapping validity flags for the current position
        active <= active_next;
      end else if (state == ST_DONE) begin
        // Count final active bits and hold result
        count <= count; // held
        // Keep active[pos] cleared for the last position (no change needed)
      end
      // Iteration counters advance in ITER (start of processing) and VERIFY (end)
      if (state == ST_ITER) begin
        pos  <= pos;
        fidx <= 3'd0;
      end else if (state == ST_VERIFY) begin
        if (fidx == 3'd3) begin
          // Move to next starting position
          pos  <= pos + 1'b1;
          fidx <= 3'd0;
        end else begin
          pos  <= pos;
          fidx <= fidx + 1'b1;
        end
      end
      // Latch the mapping char-by-char in VERIFY
      if (state == ST_VERIFY) begin
        // Set mapping for the current fragment character to this message char
        frag2_map[ fragment[fidx*5 +: 5] ] <= encrypted_msg[(pos*4 + fidx + 1)*5 - 1 -: 5];
      end
    end
  end

  // --- FSM combinational logic ---
  always_comb begin
    next_state = state;
    unique case (state)
      ST_IDLE:   next_state = start ? ST_CHECK : ST_IDLE;
      ST_CHECK:  next_state = ST_ITER;
      ST_ITER:   next_state = (pos < NPOS) ? ST_VERIFY : ST_DONE;
      ST_VERIFY: next_state = (fidx == 3'd3) ? ST_ITER : ST_VERIFY;
      ST_DONE:   next_state = start ? ST_CHECK : ST_DONE; // allow re-run without reset
    endcase
  end

  // --- Position validity (length check) ---
  // Message is fixed at 16 characters, fragment at 4.
  // Valid starting positions: 0 .. 12 (inclusive) -> 13 positions.
  assign valid_pos = (pos <= (NPOS - FLEN)); // 16 - 4 = 12

  // --- Verify logic (combinational derived for next_active) ---
  always_comb begin
    // Default: no change to active bits
    active_next = active;
    if (state == ST_ITER) begin
      if (!valid_pos) begin
        // If not a valid starting position, clear the corresponding bit
        for (int k = 0; k < NPOS; k++) active_next[k] = 1'b0;
      end else begin
        // Keep the bit set for this position for now (mapping will update in VERIFY)
        active_next = active; // unchanged; will be set in ST_ITER sequential block
      end
    end else if (state == ST_VERIFY) begin
      // We are checking fragment[fidx] against message[pos*4 + fidx]
      if (!active[pos]) begin
        // Already invalid; keep it that way
        active_next = active;
      end else begin
        // Duplicate check within fragment: has this fragment char appeared earlier in the same position?
        // At fidx==0, no earlier characters -> dupe_bit = 0 (no duplicate)
        bit dupe_bit = 1'b0;
        for (int j = 0; j < FLEN; j++) begin
          if (j < fidx) begin
            if (fragment[fidx*5 +: 5] == fragment[j*5 +: 5]) begin
              dupe_bit = 1'b1;
            end
          end
        end
        if (dupe_bit) begin
          // Inconsistent: same fragment char mapping to two different message chars not allowed
          active_next = clear_bit(active, pos);
        end else begin
          // Consistency: if mapped before, must map to same message char now
          char5_t prev_map;
          prev_map = frag2_map[ fragment[fidx*5 +: 5] ];
          char5_t cur_msg;
          cur_msg = encrypted_msg[(pos*4 + fidx + 1)*5 - 1 -: 5];
          if (|prev_map) begin // if previously mapped (at least one '1' in char)
            if (prev_map != cur_msg) begin
              active_next = clear_bit(active, pos);
            end else begin
              // still valid after this char
              active_next = set_bit(active, pos, 1'b1);
            end
          end else begin
            // First time seeing this fragment char; it's always okay at this character
            active_next = set_bit(active, pos, 1'b1);
          end
        end
      end
    end else begin
      // In other states, keep active unchanged
      active_next = active;
    end
  end

  // --- Count accumulation: count matches after processing each position ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 5'd0;
    end else begin
      if (state == ST_IDLE) begin
        count <= 5'd0;
      end else if (state == ST_ITER) begin
        // When starting a new position (fidx==0), if the last position just finished (fidx rolled over),
        // we add the result of the just-finished position. To do that safely, we count right when
        // we enter ITER and fidx==0 (meaning VERIFY just finished for the previous position).
        if (fidx == 3'd0) begin
          // After finishing processing a full fragment (4 chars), update count by the newly finalized position.
          // We can compute it on-the-fly using active_next (which equals the finalized active bits).
          // active_next at this moment is from previous VERIFY cycle and corresponds to the completed position.
          // We also include the current position only if it will start now.
          // Simpler: sum current active bits (which reflect completed position(s)) and keep it.
          // Since we process positions one-by-one and clear the bit on failure, count is just popcount(active).
          count <= $countones(active);
        end
      end else if (state == ST_DONE) begin
        // Hold the final count
        count <= count;
      end
    end
  end

endmodule
