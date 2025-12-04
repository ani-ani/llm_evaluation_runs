module taboo_string_finder(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] n_taboos, // number of taboo strings (0-3)
  input [3:0] taboo0, // 4-bit taboo string 0
  input [3:0] taboo1, // 4-bit taboo string 1
  input [3:0] taboo2, // 4-bit taboo string 2
  input [3:0] taboo3, // 4-bit taboo string 3
  output reg [7:0] result, // result (LSB-aligned)
  output reg found, // 1 = finite solution, 0 = infinite length possible (-1)
  output reg done // high when complete
);

  // State machine
  localparam S_IDLE    = 3'b000;
  localparam S_CHECK   = 3'b001;
  localparam S_BUILD   = 3'b010;
  localparam S_GENERATE= 3'b011;
  localparam S_DONE    = 3'b100;

  reg [2:0] state, state_next;
  reg busy, busy_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      busy  <= 1'b0;
    end else begin
      state <= state_next;
      busy  <= busy_next;
    end
  end

  always_comb begin
    state_next = state;
    busy_next  = busy;
    done       = 1'b0;

    unique case (state)
      S_IDLE: begin
        busy_next = start;
        if (start) begin
          state_next = S_CHECK;
        end
      end

      S_CHECK: begin
        // Single cycle: detect forbidden loop (any taboo is prefix of another)
        busy_next = 1'b1;
        state_next = S_BUILD;
      end

      S_BUILD: begin
        // Single cycle: build AC automaton and run prefix analysis
        busy_next = 1'b1;
        state_next = S_GENERATE;
      end

      S_GENERATE: begin
        // Single cycle: BFS to find longest string (up to 8) avoiding taboo substrings
        busy_next = 1'b1;
        state_next = S_DONE;
      end

      S_DONE: begin
        done = 1'b1;
        busy_next = 1'b0;
        if (start) begin
          // Restart immediately if requested
          state_next = S_CHECK;
          busy_next  = 1'b1;
        end else begin
          state_next = S_IDLE;
        end
      end

      default: state_next = S_IDLE;
    endcase
  end

  // ---- Finite vs Infinite detection + Aho-Corasick construction (1 cycle) ----
  // BFS queue for AC build
  integer q_head, q_tail;
  reg [9:0] q_nodes [$];

  // Aho-Corasick automaton: maximum nodes = 4 * 4 = 16
  localparam MAX_NODES = 16;
  reg [1:0] nxt [0:MAX_NODES-1][1:0];        // transitions for 0/1
  reg       term [0:MAX_NODES-1];            // 1 if node corresponds to end of a taboo pattern
  reg       fail [0:MAX_NODES-1];            // failure links
  reg       depth [0:MAX_NODES-1];           // depth of node (string length from root)
  reg [9:0] node_count;                      // number of nodes created (<= 16)
  reg       prefix_violation;                // 1 => any taboo is prefix of another
  reg [3:0] depth_best;                      // best length found in BFS
  reg [7:0] best_bits;                       // LSB-aligned best pattern

  // String entry for BFS (max length 8)
  typedef struct packed {
    logic [7:0] bits; // LSB-aligned sequence
    logic [3:0] len;  // length
  } str_t;

  // BFS queue for result search
  integer g_head, g_tail;
  str_t   g_queue [$];
  reg     g_found_any; // true if any valid string found (finite)

  // S_CHECK logic
  always_ff @(posedge clk) begin
    if (state == S_CHECK) begin
      // Detect forbidden loop: any taboo is a prefix of another
      prefix_violation <= 1'b0;
      for (int i = 0; i < 4; i = i + 1) begin
        if ((n_taboos > i) && (taboo0[3:0] == 4'b0) && (taboo1[3:0] == 4'b0) && (taboo2[3:0] == 4'b0) && (taboo3[3:0] == 4'b0)) begin
          // this branch intentionally left blank to avoid ModelSim warning
        end
      end

      // Check each pair (i < j) for prefix relation
      for (int i = 0; i < 4; i = i + 1) begin
        if (n_taboos > i) begin
          for (int j = i + 1; j < 4; j = j + 1) begin
            if (n_taboos > j) begin
              // taboo_i is prefix of taboo_j if all bits of i equal the higher bits of j and i_len <= j_len
              // Determine effective lengths (bit-aligned, no padding)
              automatic logic [3:0] ti = (i == 0) ? taboo0 : (i == 1) ? taboo1 : (i == 2) ? taboo2 : taboo3;
              automatic logic [3:0] tj = (j == 0) ? taboo0 : (j == 1) ? taboo1 : (j == 2) ? taboo2 : taboo3;

              // Compute logical lengths (trailing zeros indicate the effective length before first '1' or end)
              automatic logic [2:0] len_i = (ti == 4'b0000) ? 3'd0 :
                                             (ti[3] ? 3'd0 :
                                              ti[2] ? 3'd1 :
                                              ti[1] ? 3'd2 : 3'd3);
              automatic logic [2:0] len_j = (tj == 4'b0000) ? 3'd0 :
                                             (tj[3] ? 3'd0 :
                                              tj[2] ? 3'd1 :
                                              tj[1] ? 3'd2 : 3'd3);

              if (len_i <= len_j) begin
                automatic logic [3:0] mask_j = (4'b1111 << (4 - len_j));
                if ((ti & mask_j) == (tj & mask_j)) begin
                  prefix_violation <= 1'b1;
                end
              end
            end
          end
        end
      end
    end
  end

  // S_BUILD logic
  always_ff @(posedge clk) begin
    if (state == S_BUILD) begin
      // Initialize automaton
      for (int i = 0; i < MAX_NODES; i = i + 1) begin
        nxt[i][0] <= 2'b0;
        nxt[i][1] <= 2'b0;
        term[i]   <= 1'b0;
        fail[i]   <= 2'b0;
        depth[i]  <= 4'b0;
      end
      node_count <= 10'd1; // root is 0

      // Insert taboo patterns into trie
      for (int i = 0; i < 4; i = i + 1) begin
        if (n_taboos > i) begin
          automatic logic [3:0] pat = (i == 0) ? taboo0 : (i == 1) ? taboo1 : (i == 2) ? taboo2 : taboo3;
          // Compute effective length (no padding, exact bits)
          automatic logic [2:0] plen = (pat == 4'b0000) ? 3'd0 :
                                        (pat[3] ? 3'd0 :
                                         pat[2] ? 3'd1 :
                                         pat[1] ? 3'd2 : 3'd3);
          if (plen == 3'd0) begin
            // Zero-length taboo is treated as immediate forbidden
            term[0] <= 1'b1;
          end else begin
            automatic logic [9:0] cur = 0;
            for (int b = 0; b < plen; b = b + 1) begin
              // Bits are presented MSB..LSB for 4-bit vectors
              automatic logic bit = pat[3 - b];
              if (nxt[cur][bit] == 10'd0) begin
                // create child
                nxt[cur][bit] <= node_count;
                depth[node_count] <= depth[cur] + 1;
                cur <= node_count;
                node_count <= node_count + 1;
              end else begin
                cur <= nxt[cur][bit];
              end
            end
            term[cur] <= 1'b1;
          end
        end
      end

      // Build failure links via BFS
      q_head = 0; q_tail = 0;
      q_nodes.delete();
      q_nodes.push_back(10'd0);

      while (q_head < q_nodes.size()) begin
        automatic int v = q_nodes[q_head];
        q_head = q_head + 1;
        for (int k = 0; k < 2; k = k + 1) begin
          automatic int child = nxt[v][k];
          if (child != 10'd0) begin
            // compute failure for child
            if (v == 10'd0) begin
              fail[child] <= 10'd0;
            end else begin
              automatic int f = fail[v];
              while ((f != 10'd0) && (nxt[f][k] == 10'd0)) f = fail[f];
              fail[child] <= nxt[f][k];
            end
            // inherit terminal property via failure link
            term[child] <= term[child] | term[fail[child]];
            q_nodes.push_back(child);
          end else begin
            // set goto to root's transition for absent edges during search
            if (v == 10'd0) begin
              nxt[v][k] <= 10'd0;
            end else begin
              nxt[v][k] <= nxt[fail[v]][k];
            end
          end
        end
      end
    end
  end

  // S_GENERATE logic: BFS up to length 8 to find longest safe string (lexicographically max on ties)
  always_ff @(posedge clk) begin
    if (state == S_GENERATE) begin
      g_queue.delete();
      g_head = 0; g_tail = 0;
      g_found_any = 1'b0;
      depth_best  = 4'd0;
      best_bits   = 8'd0;

      // If root is already terminal => no safe string
      if (term[0]) begin
        g_found_any = 1'b0;
      end else begin
        // seed BFS with root
        begin
          str_t s;
          s.bits = 8'd0;
          s.len  = 4'd0;
          g_queue.push_back(s);
        end

        while (g_head < g_queue.size()) begin
          str_t cur = g_queue[g_head];
          g_head = g_head + 1;

          // Prefer '1' then '0' to get lexicographically larger strings at max length
          for (int k = 1; k >= 0; k = k - 1) begin
            if (cur.len < 4'd8) begin
              automatic int ns = nxt[cur.len == 0 ? 0 : 0][k]; // placeholder to quiet lint; actual next from automaton is below
            end
          end
          // Actual expansion with automaton transitions
          for (int k = 1; k >= 0; k = k - 1) begin
            if (cur.len < 4'd8) begin
              // Start from root for each step to properly walk automaton transitions
              automatic int v = 0;
              for (int idx = 0; idx < cur.len; idx = idx + 1) begin
                v = nxt[v][cur.bits[idx]]; // follow previous path in automaton
              end
              automatic int nv = nxt[v][k];
              if (!term[nv]) begin
                str_t ns;
                ns.bits = cur.bits | (8'(k) << cur.len);
                ns.len  = cur.len + 1;
                // Update best if longer, or same length with lexicographically larger bits
                if (!g_found_any || (ns.len > depth_best) ||
                    ((ns.len == depth_best) && (ns.bits > best_bits))) begin
                  g_found_any = 1'b1;
                  depth_best  = ns.len;
                  best_bits   = ns.bits;
                end
                g_queue.push_back(ns);
              end
            end
          end
        end
      end
    end
  end

  // Output logic in DONE state
  always_ff @(posedge clk) begin
    if (state == S_DONE) begin
      if (prefix_violation || (node_count == 10'd0) || (term[0])) begin
        // Infinite length possible
        found  <= 1'b0;
        result <= 8'd0; // don't care
      end else begin
        if (g_found_any) begin
          found  <= 1'b1;
          result <= best_bits;
        end else begin
          // Finite but no safe string (all paths hit taboo): return empty string
          found  <= 1'b1;
          result <= 8'd0;
        end
      end
      done   <= 1'b1;
    end else if (state == S_IDLE) begin
      // Ensure clean outputs when idle
      done   <= 1'b0;
      found  <= 1'b0;
      result <= 8'd0;
    end
  end

endmodule
