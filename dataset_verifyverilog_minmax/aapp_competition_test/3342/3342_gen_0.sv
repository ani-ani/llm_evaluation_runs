module onion_protection(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0] N, // Number of onions (max 8)
  input [3:0] M, // Number of fence posts (max 8)
  input [3:0] K, // Number of upgraded posts (max 4)
  input [11:0] onion_x [0:7], // Q4.8 fixed point X coord (8 onions max)
  input [11:0] onion_y [0:7], // Q4.8 fixed point Y coord (8 onions max)
  input [11:0] post_x [0:7],  // Q4.8 fixed point X coord (8 posts max)
  input [11:0] post_y [0:7],  // Q4.8 fixed point Y coord (8 posts max)
  output reg [3:0] max_count, // Maximum protected onions (will be <=8)
  output reg done // High when computation complete
);

  // ---------- Local parameters ----------
  localparam MAX_N = 8;
  localparam MAX_M = 8;
  localparam MAX_K = 4;
  localparam COORD_W = 12; // Q4.8 (4 integer bits, 8 fractional bits)
  // 12-bit signed can hold Q4.8 range [-8, 7.996...]
  // Cross product uses 24-bit signed to avoid overflow:
  // (12b * 12b) fits in 24b with margin.
  localparam CROSS_W = 24;

  // ---------- State machine ----------
  typedef enum logic [3:0] {
    S_IDLE    = 4'd0,
    S_SKIP    = 4'd1,
    S_LOAD    = 4'd2,
    S_HULL    = 4'd3,
    S_COUNT   = 4'd4
  } state_t;

  state_t state, next_state;

  // ---------- Combination generator ----------
  // Represent K-out-of-M combination by bitmask over MAX_M bits
  logic [MAX_M-1:0] comb;
  logic [$clog2(1<<MAX_M):0] comb_idx; // up to 256 (fits in 9 bits)
  logic [$clog2(1<<MAX_M):0] total_combs;
  logic [3:0] popcnt_k;

  // popcount of comb
  logic [3:0] popcnt;
  function [3:0] popcount (input [MAX_M-1:0] v);
    integer i;
    popcount = 0;
    for (i = 0; i < MAX_M; i = i + 1) begin
      if (v[i]) popcount = popcount + 1;
    end
  endfunction

  // ---------- Selected post buffers ----------
  logic [CROSS_W-1:0] sel_x [0:MAX_K-1]; // sign-extended to 24-bit for arithmetic
  logic [CROSS_W-1:0] sel_y [0:MAX_K-1];
  logic [3:0] K_used; // actual K for this iteration (K or 0 if skipped)
  logic [3:0] load_ptr; // pointer while loading selected posts
  logic [3:0] load_ptr_next;
  logic [3:0] K_eff; // K_used

  // ---------- Convex hull storage ----------
  // Hull is built CCW; max hull size = K_used (worst case collinear kept)
  logic [CROSS_W-1:0] hull_x [0:MAX_K-1];
  logic [CROSS_W-1:0] hull_y [0:MAX_K-1];
  logic [3:0] hull_size;
  logic [3:0] hull_size_next;
  logic [3:0] add_ptr, add_ptr_next;
  logic [3:0] i_hull, i_hull_next;
  logic [3:0] j_hull, j_hull_next;
  logic [3:0] nxt_i, nxt_j;

  // ---------- Counting inside onions ----------
  logic [3:0] onion_idx; // which onion is being tested
  logic [3:0] inside_count, inside_count_next;
  logic cross_pos; // result of cross product > 0
  logic cross_pos_next;
  logic is_inside, is_inside_next;

  // ---------- Cross product (strict left test) ----------
  // cross( B - A, P - A ) > 0  <=>  P is strictly to the left of directed edge A->B
  function cross_pos_strict_left (
    input [CROSS_W-1:0] ax, ay,
    input [CROSS_W-1:0] bx, by,
    input [CROSS_W-1:0] px, py
  );
    logic [CROSS_W-1:0] ux, uy, vx, vy;
    logic signed [CROSS_W-1:0] ux_s, uy_s, vx_s, vy_s;
    logic signed [CROSS_W*2-1:0] cross_s; // up to 24b * 2 = 48b (safe)
    ux = bx - ax; // 24b unsigned range; reinterpret as signed for math
    uy = by - ay;
    vx = px - ax;
    vy = py - ay;
    ux_s = $signed(ux);
    uy_s = $signed(uy);
    vx_s = $signed(vx);
    vy_s = $signed(vy);
    cross_s = ux_s * vy_s - uy_s * vx_s; // signed 48b
    // > 0 means strictly left (not on or right)
    cross_pos_strict_left = (cross_s > 0);
  endfunction

  // ---------- Convex hull (Andrew's monotone chain), keep collinear on hull ----------
  function automatic void build_convex_hull (
    input [3:0] k_in,
    input [CROSS_W-1:0] px [0:MAX_K-1],
    input [CROSS_W-1:0] py [0:MAX_K-1],
    output logic [3:0] hull_sz,
    output logic [CROSS_W-1:0] hx [0:MAX_K-1],
    output logic [CROSS_W-1:0] hy [0:MAX_K-1]
  );
    // Local arrays of size MAX_K for sorting + hull building
    logic [CROSS_W-1:0] sx [0:MAX_K-1];
    logic [CROSS_W-1:0] sy [0:MAX_K-1];
    logic [MAX_K-1:0] used_mask;
    integer i, j;
    logic [$clog2(MAX_K)-1:0] uniq_cnt, u;

    // Remove duplicates by merging duplicates into a mask
    for (i = 0; i < MAX_K; i = i + 1) begin
      used_mask[i] = 1'b0;
      sx[i] = px[i];
      sy[i] = py[i];
    end
    for (i = 0; i < MAX_K; i = i + 1) begin
      if (i < k_in) begin
        for (j = i+1; j < k_in; j = j + 1) begin
          if ((px[i] == px[j]) && (py[i] == py[j])) begin
            // duplicate; mark j as used
            used_mask[j] = 1'b1;
          end
        end
      end
    end
    // Compact unique points into sx/sy, keep order of first occurrence
    uniq_cnt = 0;
    for (i = 0; i < MAX_K; i = i + 1) begin
      if (i < k_in) begin
        if (!used_mask[i]) begin
          sx[uniq_cnt] = px[i];
          sy[uniq_cnt] = py[i];
          uniq_cnt = uniq_cnt + 1;
        end
      end
    end

    if (uniq_cnt <= 1) begin
      hull_sz = uniq_cnt;
      for (i = 0; i < MAX_K; i = i + 1) begin
        if (i < uniq_cnt) begin
          hx[i] = sx[i];
          hy[i] = sy[i];
        end else begin
          hx[i] = 0;
          hy[i] = 0;
        end
      end
      return;
    end

    // Sort by x, then y
    for (i = 0; i < uniq_cnt - 1; i = i + 1) begin
      for (j = i + 1; j < uniq_cnt; j = j + 1) begin
        if ((sx[j] < sx[i]) || ((sx[j] == sx[i]) && (sy[j] < sy[i]))) begin
          logic [CROSS_W-1:0] tx, ty;
          tx = sx[i]; ty = sy[i];
          sx[i] = sx[j]; sy[i] = sy[j];
          sx[j] = tx; sy[j] = ty;
        end
      end
    end

    // Build lower hull
    logic [MAX_K-1:0] lower_mask;
    lower_mask = '0;
    for (i = 0; i < uniq_cnt; i = i + 1) begin
      while (2 > 0) begin
        // Count active points in lower_mask so far
        logic [3:0] count_lower;
        count_lower = 0;
        for (u = 0; u < MAX_K; u = u + 1) begin
          if (lower_mask[u]) count_lower = count_lower + 1;
        end
        if (count_lower < 2) break;
        // Indices of last two in lower hull
        integer i1, i2;
        i2 = -1; i1 = -1;
        for (u = 0; u < MAX_K; u = u + 1) begin
          if (lower_mask[u]) begin
            i1 = i2;
            i2 = u;
          end
        end
        // i2 is last, i1 is second last
        // Check orientation: (i1 -> i2 -> i) should be CCW, i.e., cross > 0
        if (i1 < 0) break;
        if (cross_pos_strict_left(sx[i1], sy[i1], sx[i2], sy[i2], sx[i], sy[i])) begin
          break;
        end else begin
          // Remove i2 (last) from hull
          lower_mask[i2] = 1'b0;
        end
      end
      // Add i to lower hull
      for (u = 0; u < MAX_K; u = u + 1) begin
        if (!lower_mask[u]) begin
          lower_mask[u] = 1'b1;
          break;
        end
      end
    end

    // Build upper hull
    logic [MAX_K-1:0] upper_mask;
    upper_mask = '0;
    for (i = uniq_cnt - 1; i >= 0; i = i - 1) begin
      while (2 > 0) begin
        logic [3:0] count_upper;
        count_upper = 0;
        for (u = 0; u < MAX_K; u = u + 1) begin
          if (upper_mask[u]) count_upper = count_upper + 1;
        end
        if (count_upper < 2) break;
        integer i1, i2;
        i2 = -1; i1 = -1;
        for (u = 0; u < MAX_K; u = u +  1) begin
          if (upper_mask[u]) begin
            i1 = i2;
            i2 = u;
          end
        end
        if (i1 < 0) break;
        // For upper we want CCW, same as lower: remove if not left turn
        if (cross_pos_strict_left(sx[i1], sy[i1], sx[i2], sy[2], sx[i], sy[i])) begin
          break;
        end else begin
          upper_mask[i2] = 1'b0;
        end
      end
      for (u = 0; u < MAX_K; u = u + 1) begin
        if (!upper_mask[u]) begin
          upper_mask[u] = 1'b1;
          break;
        end
      end
    end

    // Concatenate lower + upper (excluding duplicate endpoints)
    // The hull will be CCW.
    logic [MAX_K-1:0] final_mask;
    final_mask = '0;
    for (i = 0; i < MAX_K; i = i + 1) begin
      if (lower_mask[i]) final_mask[i] = 1'b1;
    end
    // Skip first and last point of upper when concatenating to avoid duplicates
    // Extract first and last indices in upper for exclusion.
    integer first_upper, last_upper;
    first_upper = -1; last_upper = -1;
    for (u = 0; u < MAX_K; u = u + 1) begin
      if (upper_mask[u]) begin
        if (first_upper == -1) first_upper = u;
        last_upper = u;
      end
    end
    for (i = 0; i < MAX_K; i = i + 1) begin
      if (upper_mask[i]) begin
        if ((i != first_upper) && (i != last_upper)) begin
          final_mask[i] = 1'b1;
        end
      end
    end

    // Compact final hull
    hull_sz = 0;
    for (i = 0; i < MAX_K; i = i + 1) begin
      if (final_mask[i]) begin
        hx[hull_sz] = sx[i];
        hy[hull_sz] = sy[i];
        hull_sz = hull_sz + 1;
      end
    end
  endfunction

  // ---------- Helper: sign-extend 12-bit coord to 24-bit ----------
  function [CROSS_W-1:0] sxt12 (input [11:0] a);
    logic [CROSS_W-1:0] s;
    s = {{(CROSS_W-12){a[11]}}, a};
    sxt12 = s;
  endfunction

  // ---------- Combinational next-state logic ----------
  always_comb begin
    // Defaults
    next_state = state;
    done = 1'b0;

    load_ptr_next = load_ptr;
    K_eff = K_used;

    hull_size_next = hull_size;
    add_ptr_next = add_ptr;
    i_hull_next = i_hull;
    j_hull_next = j_hull;
    nxt_i = 0; nxt_j = 0;

    onion_idx_next = onion_idx;
    inside_count_next = inside_count;
    cross_pos_next = cross_pos;
    is_inside_next = is_inside;

    case (state)
      S_IDLE: begin
        if (start) begin
          // Initialize combination generator
          comb_idx = 0;
          // Total combinations C(M, K)
          if ((K == 0) || (K > M)) begin
            total_combs = 0;
          end else begin
            // Use builtin $clog2(1<<MAX_M) range, compute via popcount over vector
            // Compute combinatorics by iterating all masks is simpler and OK for M<=8.
            total_combs = 0;
            for (int t = 0; t < (1<<MAX_M); t++) begin
              if (popcount(t[MAX_M-1:0]) == K) total_combs = total_combs + 1;
            end
          end
          comb = '0;
          popcnt_k = popcount(comb);
          K_used = (popcnt_k == K) ? K : 4'd0;
          load_ptr_next = 0;
          inside_count_next = 0;
          next_state = (total_combs == 0) ? S_IDLE : ((K_used == 0) ? S_SKIP : S_LOAD);
        end else begin
          done = 1'b0;
        end
      end

      S_SKIP: begin
        // Skip non-K popcount combinations quickly
        if (!start) begin
          next_state = S_IDLE;
        end else begin
          // Done if all combinations processed
          if (comb_idx >= total_combs) begin
            done = 1'b1;
            next_state = S_IDLE;
          end else begin
            // Advance to next mask with popcount K
            comb_idx = comb_idx + 1;
            if (comb_idx >= (1<<MAX_M)) comb = '0; // wrap to 0 safely
            else comb = comb + 1;
            popcnt_k = popcount(comb);
            K_used = (popcnt_k == K) ? K : 4'd0;
            inside_count_next = 0;
            load_ptr_next = 0;
            if (K_used == 4'd0) next_state = S_SKIP;
            else next_state = S_LOAD;
          end
        end
      end

      S_LOAD: begin
        // Load selected posts (sign-extend to 24b)
        if (!start) begin
          next_state = S_IDLE;
        end else begin
          if (load_ptr < K_used) begin
            // Find the load_ptr-th '1' in comb and load that post
            int bits_found;
            bits_found = -1;
            for (int p = 0; p < MAX_M; p = p + 1) begin
              if (comb[p]) begin
                bits_found = bits_found + 1;
                if (bits_found == load_ptr) begin
                  sel_x[load_ptr] = sxt12(post_x[p]);
                  sel_y[load_ptr] = sxt12(post_y[p]);
                  break;
                end
              end
            end
            load_ptr_next = load_ptr + 1;
            next_state = S_LOAD;
          end else begin
            // Compute convex hull (single cycle call)
            build_convex_hull(K_used, sel_x, sel_y, hull_sz, hull_x, hull_y);
            hull_size_next = hull_sz;
            // Initialize counting
            onion_idx_next = 0;
            inside_count_next = 0;
            next_state = S_COUNT;
          end
        end
      end

      S_COUNT: begin
        if (!start) begin
          next_state = S_IDLE;
        end else begin
          if (onion_idx < N) begin
            // Check point-in-convex-polygon strictly
            if (hull_size >= 3) begin
              // Iterate edges: onion must be strictly left of every edge
              cross_pos_next = 1'b1;
              for (int e = 0; e < MAX_K; e = e + 1) begin
                if (e < hull_size) begin
                  int j;
                  j = (e + 1) % hull_size;
                  if (!cross_pos_strict_left(hull_x[e], hull_y[e], hull_x[j], hull_y[j],
                                             sxt12(onion_x[onion_idx]), sxt12(onion_y[onion_idx]))) begin
                    cross_pos_next = 1'b0;
                    break;
                  end
                end
              end
            end else begin
              // Degenerate hull: not strictly inside any interior point
              cross_pos_next = 1'b0;
            end
            is_inside_next = cross_pos_next;
            inside_count_next = inside_count + (is_inside_next ? 1 : 0);
            onion_idx_next = onion_idx + 1;
            next_state = S_COUNT;
          end else begin
            // Finished counting this combination
            if (inside_count_next > max_count) begin
              // Update max_count
            end
            // Decide next step
            if (comb_idx + 1 >= total_combs) begin
              done = 1'b1;
              next_state = S_IDLE;
            end else begin
              comb_idx = comb_idx + 1;
              if (comb_idx >= (1<<MAX_M)) comb = '0;
              else comb = comb + 1;
              popcnt_k = popcount(comb);
              K_used = (popcnt_k == K) ? K : 4'd0;
              inside_count_next = 0;
              load_ptr_next = 0;
              if (K_used == 4'd0) next_state = S_SKIP;
              else next_state = S_LOAD;
            end
          end
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // ---------- Sequential logic ----------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      max_count <= 4'd0;
      comb <= '0;
      comb_idx <= 0;
      popcnt_k <= 0;
      total_combs <= 0;
      K_used <= 4'd0;
      load_ptr <= 0;
      inside_count <= 0;
      onion_idx <= 0;
      hull_size <= 0;
      add_ptr <= 0;
      i_hull <= 0;
      j_hull <= 0;
      cross_pos <= 1'b0;
      is_inside <= 1'b0;
      for (int i = 0; i < MAX_K; i = i + 1) begin
        sel_x[i] <= 0; sel_y[i] <= 0;
        hull_x[i] <= 0; hull_y[i] <= 0;
      end
    end else begin
      // Update state
      state <= next_state;

      // Update outputs
      if (state == S_IDLE && !start) begin
        done <= 1'b0;
        max_count <= 4'd0;
      end else if (state == S_COUNT && next_state != S_COUNT) begin
        // Just finished a combination
        if (inside_count_next > max_count) begin
          max_count <= inside_count_next;
        end
      end else if (next_state == S_IDLE && done) begin
        // keep max_count until next start
        max_count <= max_count;
        done <= 1'b1;
      end

      // Update generator and buffers
      if (state == S_IDLE && start) begin
        comb <= '0;
        comb_idx <= 0;
        popcnt_k <= popcount('0);
        // total_combs computed in S_IDLE path; keep it
        K_used <= (popcount('0) == K) ? K : 4'd0;
        load_ptr <= 0;
        inside_count <= 0;
      end else if (state == S_SKIP) begin
        // Advance if not done
        if (comb_idx < total_combs) begin
          comb <= (comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1);
          comb_idx <= comb_idx + 1;
          popcnt_k <= popcount((comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1));
          K_used <= (popcount((comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1)) == K) ? K : 4'd0;
          inside_count <= 0;
          load_ptr <= 0;
        end
      end else if (state == S_LOAD) begin
        load_ptr <= load_ptr_next;
        if (load_ptr < K) begin
          // sel_x/sel_y are filled in S_LOAD combinational path using comb;
          // keep them stable during the load stage
        end else begin
          // hull_x/hull_y are produced in one-shot at S_LOAD->S_COUNT transition.
        end
      end else if (state == S_COUNT) begin
        onion_idx <= onion_idx_next;
        inside_count <= inside_count_next;
        cross_pos <= cross_pos_next;
        is_inside <= is_inside_next;
        if (onion_idx >= N) begin
          // Start next combination
          if (comb_idx + 1 < total_combs) begin
            comb <= (comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1);
            comb_idx <= comb_idx + 1;
            popcnt_k <= popcount((comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1));
            K_used <= (popcount((comb_idx + 1 >= (1<<MAX_M)) ? '0 : (comb + 1)) == K) ? K : 4'd0;
            load_ptr <= 0;
            inside_count <= 0;
            onion_idx <= 0;
          end
        end
      end

      // Update hull size if just computed
      if (state == S_LOAD && next_state == S_COUNT) begin
        hull_size <= hull_size_next;
        for (int i = 0; i < MAX_K; i = i + 1) begin
          if (i < hull_size_next) begin
            hull_x[i] <= hull_x[i]; // already set by function
            hull_y[i] <= hull_y[i];
          end else begin
            hull_x[i] <= 0;
            hull_y[i] <= 0;
          end
        end
      end

      // Ensure total_combs is initialized at start
      if (state == S_IDLE && start && total_combs == 0) begin
        if ((K == 0) || (K > M)) begin
          total_combs <= 0;
        end else begin
          int tc;
          tc = 0;
          for (int t = 0; t < (1<<MAX_M); t++) begin
            if (popcount(t[MAX_M-1:0]) == K) tc = tc + 1;
          end
          total_combs <= tc;
        end
      end
    end
  end

  // Note: The function build_convex_hull is combinatorial; call it during S_LOAD->S_COUNT
  // by driving hull_* from the function's outputs via an always_comb block.
  // To make it synthesizable, we bridge function outputs to registers in the S_COUNT entry.
  always_comb begin
    // Bridge from function outputs (these are recomputed every cycle where needed)
    logic [3:0] tmp_hull_sz;
    logic [CROSS_W-1:0] tmp_hx [0:MAX_K-1];
    logic [CROSS_W-1:0] tmp_hy [0:MAX_K-1];
    if (state == S_LOAD) begin
      // Only compute when we are about to transition to S_COUNT
      build_convex_hull(K_used, sel_x, sel_y, tmp_hull_sz, tmp_hx, tmp_hy);
      // The actual registered capture happens in the sequential block at S_LOAD->S_COUNT
    end
  end

endmodule