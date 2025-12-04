module lex_order_solver (
  input clk,
  input rst_n,
  input start,       // pulse to start processing
  input [2:0] L,     // highest character index (0=a, 7=h)
  input [2:0] N,     // number of words (1-8)
  input [191:0] words, // 8 words packed (8 words * 8 chars * 3 bits)
  output reg done,     // high when computation complete (1 cycle)
  output reg [1:0] status, // 00=unique, 01=impossible, 10=ambiguous
  output reg [23:0] order   // 8 chars * 3 bits (left-padded when alphabet < 8)
);

  // Extract words (each char is 3 bits, padded with 0 at end)
  function [23:0] get_word(input [2:0] i);
    integer idx;
    begin
      idx = i * 24;
      get_word = words[idx +: 24];
    end
  endfunction

  // Character helpers
  function [2:0] get_ch(input [23:0] w, input [2:0] p);
    get_ch = w[p*3 +: 3];
  endfunction

  // Test bit p in vector v (p is 0-based)
  function bit test_bit(input [7:0] v, input [2:0] p);
    test_bit = v[p];
  endfunction

  // Return number of 1-bits in 8-bit vector
  function [3:0] popcnt8(input [7:0] v);
    integer i;
    begin
      popcnt8 = 0;
      for (i = 0; i < 8; i = i + 1)
        if (v[i]) popcnt8 = popcnt8 + 1;
    end
  endfunction

  // Shift-left 3-bit code by 3 positions (for packing order)
  function [2:0] shl3(input [2:0] x, input [2:0] s);
    shl3 = (x << s);
  endfunction

  // Compute character mask: bits [0..L] = 1
  function [7:0] char_mask(input [2:0] L);
    integer i;
    begin
      char_mask = 8'b0;
      for (i = 0; i < 8; i = i + 1)
        if (i <= L) char_mask[i] = 1'b1;
    end
  endfunction

  // Given a vector 'cand' (bits for each char) and adjacency rows 'adj',
  // compute ready = cand & ~sum(adj[i] for all i in cand)
  // Sum is OR reduction of the rows indexed by bits in 'cand'.
  function [7:0] ready_from_candidates(input [7:0] cand, input [7:0] adj [7]);
    integer i;
    reg [7:0] pred_or;
    begin
      pred_or = 8'b0;
      for (i = 0; i < 8; i = i + 1) begin
        if (cand[i])
          pred_or = pred_or | adj[i];
      end
      ready_from_candidates = cand & ~pred_or;
    end
  endfunction

  // Pipeline and control state
  typedef enum logic [1:0] {IDLE=2'b00, EDGE=2'b01, SORT=2'b10} state_t;
  state_t state, state_next;
  reg [3:0] step, step_next; // 0..8 (L+2 <= 10, fits in 4 bits)

  // Pipelined data (registered at EDGE stage entry)
  reg [2:0] L_reg, N_reg;
  reg [7:0] char_mask_reg;
  reg [7:0] adj_reg [7]; // adjacency matrix rows (from <= to)
  reg equal_pair_reg;     // 1 if any adjacent pair is equal (invalid)

  // Kahn's algo working state (during SORT stage)
  reg [7:0] frontier;    // ready nodes (bits)
  reg [7:0] visited;     // placed nodes (bits)
  reg [7:0] order_bits;  // bits set in the order sequence (LSB=pos0)
  reg [2:0] pos;         // current position in the order (0..7)
  reg [2:0] selected_char; // 3-bit code of the chosen char at current pos
  reg ambiguous_reg;     // ambiguity flag for output (sticky)

  // Combinational outputs per cycle during SORT
  wire [7:0] char_mask_comb = char_mask(L_reg);
  wire [3:0] char_cnt = L_reg + 1;
  wire [7:0] candidates = frontier & char_mask_comb;
  wire [3:0] cand_cnt = popcnt8(candidates);
  wire single_cand = (cand_cnt == 1);
  wire [7:0] ready_mask = ready_from_candidates(candidates, adj_reg);
  wire [2:0] selected_comb = (single_cand ? (candidates[0] ? 0 :
                                              candidates[1] ? 1 :
                                              candidates[2] ? 2 :
                                              candidates[3] ? 3 :
                                              candidates[4] ? 4 :
                                              candidates[5] ? 5 :
                                              candidates[6] ? 6 : 7) : 3'b0);
  wire ambiguous_comb = ambiguous_reg | (~single_cand & (cand_cnt > 0));
  wire [7:0] next_frontier = (ready_mask & ~((1 << selected_comb) | order_bits));
  wire [7:0] next_visited = visited | (1 << selected_comb);
  wire [2:0] next_pos = pos + 1;

  // Packing order at the end
  integer k;
  reg [23:0] order_comb;
  always_comb begin
    order_comb = 24'b0;
    for (k = 0; k < 8; k = k + 1) begin
      if (k < pos) begin
        // The k-th position in the order corresponds to bit k in order_bits
        // Find which character occupies position k
        // We can reconstruct by scanning visited bits in order of addition
        // Simpler: compute by using selected_char known per step; we store in a small array.
        // To avoid large state, we will recompute by re-running the steps logically.
        // Instead, we use: order_comb = {char@pos7, char@pos6, ..., char@pos0} in 3-bit fields
        // We only need final packing when pos == char_cnt; fill left padding with zeros.
        // Here we keep it 0; final order will be computed just before done.
      end
    end
    // Leave as 0 here; final assignment done below in the sequencer using a small buffer.
  end

  // Small buffer to reconstruct order (LSB-first insertion, 3 bits per char)
  reg [23:0] order_lsb_buf; // holds packed sequence as we go: [3*pos-1:0]

  // Edge detection combinational logic (drives registers at EDGE stage)
  wire [7:0] adj_comb [7];
  wire equal_pair_comb;
  integer p, q, r, cidx;
  reg [7:0] rows [7];

  always_comb begin
    // Initialize rows
    for (r = 0; r < 8; r = r + 1) rows[r] = 8'b0;
    equal_pair_comb = 1'b0;

    // Compare adjacent word pairs (0..N-2)
    for (p = 0; p < 7; p = p + 1) begin
      if (p < (N - 1)) begin
        // Get words
        // words are extracted via function get_word
        // To ease simulation/synthesis, unroll here a bit
        // Use get_word within loop (allowed, but function call in loop may be heavy;
        // but since N<=8 and 7 comparisons, it's fine)
        reg [23:0] wa, wb;
        reg [2:0] a, b;
        reg found, equal_words;
        reg [2:0] first_diff;
        wa = get_word(p);
        wb = get_word(p+1);
        equal_words = 1'b1;
        first_diff = 3'b0;
        // Compare up to 8 chars or until end of alphabet (L)
        for (cidx = 0; cidx < 8; cidx = cidx + 1) begin
          a = get_ch(wa, cidx);
          b = get_ch(wb, cidx);
          if (cidx <= L) begin
            if (a != b) begin
              if (equal_words) begin
                first_diff = cidx;
                equal_words = 1'b0;
              end
            end
          end
        end
        if (equal_words) begin
          equal_pair_comb = 1'b1; // one word is a prefix of the other (invalid order)
        end else begin
          // Add edge from first_diff(wb) -> first_diff(wa) in rows
          if (first_diff <= L) begin
            rows[wb[first_diff*3 +: 3]][wa[first_diff*3 +: 3]] = 1'b1;
          end
        end
      end
    end

    for (r = 0; r < 8; r = r + 1) adj_comb[r] = rows[r];
  end

  // State and pipeline control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      step <= 4'b0;
      L_reg <= 3'b0;
      N_reg <= 3'b0;
      char_mask_reg <= 8'b1; // a only by default
      for (r = 0; r < 8; r = r + 1) adj_reg[r] <= 8'b0;
      equal_pair_reg <= 1'b0;
      frontier <= 8'b0;
      visited <= 8'b0;
      order_bits <= 8'b0;
      pos <= 3'b0;
      selected_char <= 3'b0;
      ambiguous_reg <= 1'b0;
      order_lsb_buf <= 24'b0;
      done <= 1'b0;
      status <= 2'b00;
      order <= 24'b0;
    end else begin
      // defaults
      done <= 1'b0;
      status <= status; // keep
      order <= order;   // keep

      // NSL and pipeline
      case (state)
        IDLE: begin
          step <= 4'b0;
          visited <= 8'b0;
          order_bits <= 8'b0;
          pos <= 3'b0;
          selected_char <= 3'b0;
          ambiguous_reg <= 1'b0;
          frontier <= 8'b0;
          order_lsb_buf <= 24'b0;
          if (start) begin
            L_reg <= L;
            N_reg <= N;
            char_mask_reg <= char_mask(L);
            for (r = 0; r < 8; r = r + 1) adj_reg[r] <= adj_comb[r];
            equal_pair_reg <= equal_pair_comb;
            state <= EDGE;
          end else begin
            state <= IDLE;
          end
        end
        EDGE: begin
          // Initialize Kahn's frontier and buffers
          // Frontier = nodes with indegree == 0 (among active chars)
          // indegree[i] = OR reduction of column i of adj matrix
          // Compute indegree from adj_reg
          for (r = 0; r < 8; r = r + 1) begin
            // no-op; kept for clarity
          end
          // Compute indegree vector
          reg [7:0] indeg;
          indeg = 8'b0;
          for (cidx = 0; cidx < 8; cidx = cidx + 1) begin
            reg [7:0] col;
            col = 8'b0;
            for (q = 0; q < 8; q = q + 1) begin
              if (adj_reg[q][cidx]) col[q] = 1'b1;
            end
            indeg[cidx] = | col;
          end
          frontier <= char_mask_reg & ~indeg; // ready nodes
          visited <= 8'b0;
          order_bits <= 8'b0;
          pos <= 3'b0;
          selected_char <= 3'b0;
          ambiguous_reg <= 1'b0;
          order_lsb_buf <= 24'b0;
          state <= SORT;
          step <= 4'b1; // we are entering step 1 of topological phase
        end
        SORT: begin
          if (step == (L_reg + 2)) begin
            // Finalize and output
            // Build 24-bit order (left-padded zeros)
            // order_lsb_buf holds 3*pos bits representing the sequence so far (LSB is first char)
            // Shift left to make it left-justified in 24 bits for output.
            reg [23:0] left_just;
            left_just = order_lsb_buf << (3 * (8 - pos));
            order <= left_just;

            // Determine status:
            // - if equal_pair -> IMPOSSIBLE
            // - else if pos != char_cnt -> IMPOSSIBLE (cycle or missing chars)
            // - else if ambiguous_reg -> AMBIGUOUS
            // - else -> UNIQUE
            if (equal_pair_reg) begin
              status <= 2'b01; // IMPOSSIBLE
            end else if (pos != (L_reg + 1)) begin
              status <= 2'b01; // IMPOSSIBLE (cycle or missing chars)
            end else if (ambiguous_reg) begin
              status <= 2'b10; // AMBIGUOUS
            end else begin
              status <= 2'b00; // UNIQUE
            end
            done <= 1'b1;
            state <= IDLE;
            step <= 4'b0;
          end else begin
            // Perform one Kahn step
            if (cand_cnt == 4'b0) begin
              // No ready candidates, cycle or missing - will resolve in finalize
              // Keep state moving
              ambiguous_reg <= ambiguous_comb; // likely set already by earlier ambiguity
              visited <= visited; // unchanged
              order_bits <= order_bits; // unchanged
              pos <= pos;           // unchanged
              selected_char <= 3'b0;
              order_lsb_buf <= order_lsb_buf;
              frontier <= 8'b0; // nothing to propagate
            end else begin
              // Update ambiguity flag and order buffer
              ambiguous_reg <= ambiguous_comb;
              selected_char <= selected_comb;

              // Update order_lsb_buf (append selected_comb at position pos)
              order_lsb_buf <= order_lsb_buf | (shl3(selected_comb, pos) & {3{1'b1}});

              // Advance frontier and visited
              visited <= next_visited;
              order_bits <= order_bits | (1 << selected_comb);
              pos <= next_pos;
              frontier <= next_frontier;
            end
            step <= step + 1;
            state <= SORT;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule