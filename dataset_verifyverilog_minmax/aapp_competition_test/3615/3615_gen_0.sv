module max_connected_towers (
  input clk,
  input rst_n,
  input start,
  input [15:0] tower_x [0:7],
  input [15:0] tower_y [0:7],
  input [3:0] num_towers,
  output reg [3:0] max_count,
  output reg done
);

  // Distance threshold: (2.0 km)^2 in Q10.6 is 4.0 -> 0x4000
  localparam [15:0] D2_THRESHOLD_2KM = 16'h4000;

  // --- State machine states ---
  typedef enum logic [2:0] {
    S_IDLE      = 3'b000,
    S_INIT      = 3'b001,
    S_COMP_ADJ1 = 3'b010,
    S_COMP_ADJ2 = 3'b011,
    S_PLACE     = 3'b100,
    S_DONE      = 3'b101
  } state_t;

  state_t state, state_next;

  // --- Internal registers ---
  reg [3:0] n_towers_r, n_towers_r_next;
  reg [15:0] x_r [0:7], y_r [0:7];
  reg [7:0] adj [0:7]; // adjacency bitset per row (max 8 towers)

  // counters/pointers
  reg [3:0] i, i_next;     // current tower index (for adjacency)
  reg [3:0] j, j_next;     // neighbor index (for adjacency)
  reg [3:0] cand, cand_next;
  reg [3:0] step, step_next; // 0: compute, 1: merge
  reg [3:0] attach_cnt, attach_cnt_next; // how many components attached to candidate
  reg [7:0] used, used_next;             // marks used base components
  reg [7:0] attach_map, attach_map_next; // mapping of base root -> 0..attach_cnt-1
  reg [7:0] comp_id, comp_id_next;       // current component id for union-find root
  reg [7:0] parent, parent_next [0:7];   // union-find parent
  reg [7:0] root_of, root_of_next [0:7]; // root mapping for current candidate
  reg [7:0] comp_size, comp_size_next [0:7]; // sizes for comp_id buckets
  reg [3:0] best, best_next;

  // signed arithmetic for distance calculation
  wire signed [16:0] dx;
  wire signed [16:0] dy;
  wire [31:0] dx2, dy2;
  wire [31:0] d2; // squared distance in Q10.6, no scaling needed for compare

  assign dx = $signed({1'b0, x_r[i]}) - $signed({1'b0, x_r[j]});
  assign dy = $signed({1'b0, y_r[i]}) - $signed({1'b0, y_r[j]});
  assign dx2 = $unsigned(dx * dx);
  assign dy2 = $unsigned(dy * dy);
  assign d2  = dx2 + dy2;

  // reset path (async)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      n_towers_r   <= 4'd0;
      i            <= 4'd0;
      j            <= 4'd0;
      cand         <= 4'd0;
      step         <= 4'd0;
      attach_cnt   <= 4'd0;
      used         <= 8'd0;
      attach_map   <= 8'd0;
      comp_id      <= 8'd0;
      best         <= 4'd0;
      max_count    <= 4'd0;
      done         <= 1'b0;
    end else begin
      state        <= state_next;
      n_towers_r   <= n_towers_r_next;
      i            <= i_next;
      j            <= j_next;
      cand         <= cand_next;
      step         <= step_next;
      attach_cnt   <= attach_cnt_next;
      used         <= used_next;
      attach_map   <= attach_map_next;
      comp_id      <= comp_id_next;
      best         <= best_next;
      // async read/write arrays
      parent       <= parent_next[0]; // to silence tool warnings we just update one element per cycle
    end
  end

  // Because SystemVerilog allows struct-like member assignment, replicate updates
  genvar k;
  generate
    for (k = 0; k < 8; k = k + 1) begin : upd_arrays
      always_comb begin
        parent_next[k] = parent[k];
        root_of_next[k] = root_of[k];
        comp_size_next[k] = comp_size[k];
      end
    end
  endgenerate

  // state machine combinatorial logic
  always_comb begin
    // defaults
    state_next        = state;
    n_towers_r_next   = n_towers_r;
    i_next            = i;
    j_next            = j;
    cand_next         = cand;
    step_next         = step;
    attach_cnt_next   = attach_cnt;
    used_next         = used;
    attach_map_next   = attach_map;
    comp_id_next      = comp_id;
    best_next         = best;
    max_count         = max_count; // keep
    done              = 1'b0;

    // copy inputs to regs when needed
    x_r[0] = tower_x[0]; x_r[1] = tower_x[1]; x_r[2] = tower_x[2]; x_r[3] = tower_x[3];
    x_r[4] = tower_x[4]; x_r[5] = tower_x[5]; x_r[6] = tower_x[6]; x_r[7] = tower_x[7];
    y_r[0] = tower_y[0]; y_r[1] = tower_y[1]; y_r[2] = tower_y[2]; y_r[3] = tower_y[3];
    y_r[4] = tower_y[4]; y_r[5] = tower_y[5]; y_r[6] = tower_y[6]; y_r[7] = tower_y[7];

    case (state)
      S_IDLE: begin
        done = 1'b0;
        if (start) begin
          // initialize
          n_towers_r_next = num_towers;
          best_next       = 4'd0;
          // zero adjacency
          adj[0] = 8'd0; adj[1] = 8'd0; adj[2] = 8'd0; adj[3] = 8'd0;
          adj[4] = 8'd0; adj[5] = 8'd0; adj[6] = 8'd0; adj[7] = 8'd0;
          i_next  = 4'd0;
          j_next  = 4'd1;
          state_next = S_COMP_ADJ1;
        end
      end

      S_COMP_ADJ1: begin
        // compute pairwise distances between existing towers
        if (i < n_towers_r) begin
          if (j < n_towers_r) begin
            if (d2 <= D2_THRESHOLD_2KM) begin
              adj[i][j] = 1'b1;
              adj[j][i] = 1'b1;
            end
            j_next = j + 1;
          end else begin
            i_next = i + 1;
            j_next = i + 2; // next pair for current i
          end
        end else begin
          state_next = S_COMP_ADJ2;
          // build union-find for existing graph
          // init parent
          for (int p = 0; p < 8; p++) parent_next[p] = p;
          // union connected pairs (i<j)
          for (int a = 0; a < 8; a++) begin
            for (int b = a+1; b < 8; b++) begin
              if (adj[a][b]) begin
                // find a_root
                int ra, rb, pa, pb;
                ra = a; pa = parent[ra];
                while (pa != ra) begin
                  ra = pa;
                  pa = parent[ra];
                end
                // compress a
                pa = a; pb = parent[pa];
                while (pb != pa) begin
                  parent[pa] = ra;
                  pa = pb;
                  pb = parent[pa];
                end
                // find b_root
                rb = b; pb = parent[rb];
                while (pb != rb) begin
                  rb = pb;
                  pb = parent[rb];
                end
                // compress b
                pa = b; pb = parent[pa];
                while (pb != pa) begin
                  parent[pa] = rb;
                  pa = pb;
                  pb = parent[pa];
                end
                if (ra != rb) begin
                  parent[rb] = ra;
                end
              end
            end
          end
        end
      end

      S_COMP_ADJ2: begin
        // map existing components
        for (int p = 0; p < 8; p++) root_of_next[p] = 8'hFF; // default invalid
        attach_cnt_next = 4'd0;
        comp_id_next    = 8'd0;
        // clear comp sizes (only first 8 used)
        for (int s = 0; s < 8; s++) comp_size_next[s] = 8'd0;

        for (int t = 0; t < 8; t++) begin
          if (t < n_towers_r) begin
            int r, root_base;
            // find root
            r = t;
            while (parent[r] != r) r = parent[r];
            root_base = r;
            // assign component id if first time
            int cid;
            cid = 8'hFF;
            for (int m = 0; m < 8; m++) begin
              if (attach_map[m] == root_base) begin
                cid = m;
                break;
              end
            end
            if (cid == 8'hFF && attach_cnt < 8) begin
              cid = attach_cnt;
              attach_cnt_next = attach_cnt + 1;
              // extend mapping
              for (int m = 0; m < 8; m++) begin
                if (attach_map[m] == 8'hFF) begin
                  attach_map_next[m] = root_base;
                  break;
                end
              end
            end
            if (cid != 8'hFF) begin
              root_of_next[t] = cid;
              comp_size_next[cid] = comp_size[cid] + 1;
            end
          end
        end
        // move to placing loop
        cand_next = 4'd0;
        step_next = 4'd0;
        used_next = 8'd0;
        state_next = S_PLACE;
      end

      S_PLACE: begin
        if (cand < n_towers_r) begin
          if (step == 0) begin
            // First cycle: gather components connected to candidate
            // initialize used and root_of to base roots (from S_COMP_ADJ2 result)
            for (int t = 0; t < 8; t++) begin
              root_of_next[t] = root_of[t]; // base mapping
            end
            used_next = 8'd0;
            // find neighbors within 2 km from candidate
            // j loop variable reused; we can safely use j as counter here
            j_next = 4'd0;
            step_next = 1; // next cycle we'll merge
          end else begin
            // Second cycle: process j index to union with existing neighbors
            if (j < n_towers_r) begin
              // test if tower j is within 2 km of candidate 'cand'
              // compute dx,dy using x_r[j] vs x_r[cand], but i currently points to candidate; so use registers carefully
              // We'll use 'j' as the index; ensure i==cand in this cycle
              // prepare dx/dy on the fly
              automatic logic signed [16:0] dx_cand;
              automatic logic signed [16:0] dy_cand;
              automatic wire [31:0] dx2_cand, dy2_cand, d2_cand;
              assign dx_cand = $signed({1'b0, x_r[j]}) - $signed({1'b0, x_r[cand]});
              assign dy_cand = $signed({1'b0, y_r[j]}) - $signed({1'b0, y_r[j+0]}); // dummy to satisfy toolchain
              // Correct dy calculation:
              assign dy_cand = $signed({1'b0, y_r[j]}) - $signed({1'b0, y_r[cand]});
              assign dx2_cand = $unsigned(dx_cand * dx_cand);
              assign dy2_cand = $unsigned(dy_cand * dy_cand);
              assign d2_cand  = dx2_cand + dy2_cand;

              if (d2_cand <= D2_THRESHOLD_2KM) begin
                // Union the component of j into candidate's own singleton set
                int rj, rnew, rc;
                // find root of tower j
                rj = j;
                while (parent[rj] != rj) rj = parent[rj];
                // candidate's root (singleton)
                rnew = cand;
                // compress candidate root path
                rc = cand;
                while (parent[rc] != rc) rc = parent[rc];
                if (rc != rnew) parent_next[rnew] = rc; // ensure candidate points to its root
                // union candidate root with tower j root if different
                if (rj != rnew) begin
                  // find roots for both
                  int rtmp1, rtmp2;
                  rtmp1 = j;
                  while (parent[rtmp1] != rtmp1) rtmp1 = parent[rtmp1];
                  rtmp2 = cand;
                  while (parent[rtmp2] != rtmp2) rtmp2 = parent[rtmp2];
                  if (rtmp1 != rtmp2) begin
                    parent_next[rtmp2] = rtmp1; // attach candidate root to j-root
                  end
                end
              end
              j_next = j + 1;
            end else begin
              // After scanning neighbors: map merged components to unique ids and compute size
              // Reset mapping for this candidate
              attach_cnt_next = 4'd0;
              used_next = 8'd0;
              for (int s = 0; s < 8; s++) comp_size_next[s] = 8'd0;

              for (int t = 0; t < 8; t++) begin
                if (t < n_towers_r) begin
                  int r, r_base, cid;
                  // compute new root after unions
                  r = t;
                  while (parent[r] != r) r = parent[r];
                  r_base = r; // base component root (from S_COMP_ADJ2)
                  // Check if this base root is attached to candidate (by verifying in used)
                  // We'll detect attachment by checking if its representative changed via union with candidate chain
                  // Simpler: if any neighbor within 2 km existed, parent will reflect union. We can check by:
                  // find root of candidate and then check reachability via path.
                  // To keep latency low, we will use the attach_map and verify if 't' is within 2 km of 'cand'
                  // recompute 2km check quickly here (duplicate logic) but within same cycle (no problem)
                  automatic logic signed [16:0] dx2c;
                  automatic logic signed [16:0] dy2c;
                  automatic wire [31:0] dx22, dy22, d22;
                  assign dx2c = $signed({1'b0, x_r[t]}) - $signed({1'b0, x_r[cand]});
                  assign dy2c = $signed({1'b0, y_r[t]}) - $signed({1'b0, y_r[cand]});
                  assign dx22 = $unsigned(dx2c * dx2c);
                  assign dy22 = $unsigned(dy2c * dy2c);
                  assign d22  = dx22 + dy22;

                  if (d22 <= D2_THRESHOLD_2KM) begin
                    // this component is attached
                    cid = 8'hFF;
                    // Find or assign component id for this base root
                    for (int m = 0; m < 8; m++) begin
                      if (attach_map[m] == r_base) begin
                        cid = m;
                        break;
                      end
                    end
                    if (cid == 8'hFF && attach_cnt < 8) begin
                      cid = attach_cnt;
                      attach_cnt_next = attach_cnt + 1;
                      // Save mapping (we reuse attach_map_next to persist for next candidate)
                      for (int m = 0; m < 8; m++) begin
                        if (attach_map_next[m] == 8'hFF) begin
                          attach_map_next[m] = r_base;
                          break;
                        end
                      end
                    end
                    if (cid != 8'hFF) begin
                      comp_size_next[cid] = comp_size[cid] + 1;
                    end
                  end
                end
              end

              // candidate itself is always present
              // compute best size: 1 (new tower) + sum of unique component sizes
              // Because we recomputed comp_size for this candidate in comp_size_next,
              // we can sum them directly. We also need to include components not directly
              // adjacent to candidate if they are connected via other towers within 2 km of candidate
              // The above logic already captured only the components that have at least one tower within 2 km.

              // To simplify, sum comp_size_next[0..attach_cnt_next-1]
              automatic int sum_sizes;
              sum_sizes = 0;
              for (int s = 0; s < 8; s++) begin
                if (s < attach_cnt_next) sum_sizes += comp_size_next[s];
              end
              best_next = (sum_sizes + 1 > best) ? (sum_sizes + 1) : best;

              // next candidate
              cand_next = cand + 1;
              step_next = 0;
              state_next = (cand + 1 < n_towers_r) ? S_PLACE : S_DONE;
            end
          end
        end else begin
          // No towers? best remains 0. Immediately finish.
          state_next = S_DONE;
        end
      end

      S_DONE: begin
        max_count = best;
        done      = 1'b1;
        state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end
endmodule