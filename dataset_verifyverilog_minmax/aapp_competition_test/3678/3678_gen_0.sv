module loop_validator(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start processing
  input [2:0] num_points, // number of points (1-8)
  input [15:0] x_in, // x-coordinate (signed 16-bit)
  input [15:0] y_in, // y-coordinate (signed 16-bit)
  input point_valid, // high when x_in/y_in are valid
  output reg valid_loop, // 1=YES, 0=NO
  output reg done // high when result is valid
);

  // FSM states
  localparam IDLE       = 2'b00;
  localparam LOADING    = 2'b01;
  localparam PROCESSING = 2'b01; // reusing 2'b01 for clarity in case merge desired
  localparam STATE_LOAD = 2'b01; // alias
  localparam STATE_PROC = 2'b10; // distinct value for PROCESSING
  localparam STATE_DONE = 2'b11;

  // Storage for up to 8 points
  localparam MAX_P = 8;
  logic [15:0] xs [0:MAX_P-1];
  logic [15:0] ys [0:MAX_P-1];

  // Internal state and counters
  logic [1:0] state, next_state;
  logic [3:0] load_cnt;       // how many points loaded (0..8)
  logic [3:0] load_cnt_next;
  logic [2:0] np_save;        // num_points captured at start
  logic [3:0] target;         // 10 + 2*num_points
  logic [3:0] cycle_cnt;      // cycles since start
  logic [3:0] cycle_cnt_next;
  logic valid_loop_d;         // combinational result

  // Edge and graph property signals
  logic closed_ok;
  logic even_deg_ok;
  logic no_loose_ends;
  logic cycle_ok;
  logic [7:0] deg; // degree of each point (0..7)
  logic [7:0] deg_eq2; // 1 where degree == 2
  logic [MAX_P-1:0] has_x_neighbor, has_y_neighbor;
  logic [MAX_P-1:0] x_nbr_mask, y_nbr_mask;

  // Orientation flags and checks
  logic [7:0] hor, ver;   // 1 if edge i (Pi->P(i+1)) is horiz/vert
  logic [7:0] h_cnt, v_cnt;
  logic orient_ok; // alternation check

  // Self-intersection checks
  logic collinear_overlap;   // non-adjacent collinear segments overlap beyond endpoint
  logic improper_cross;      // non-adjacent segments cross improperly (not endpoint-only)

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_cnt <= 4'd0;
      np_save <= 3'd0;
      target <= 4'd0;
      cycle_cnt <= 4'd0;
      valid_loop <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      load_cnt <= load_cnt_next;
      cycle_cnt <= cycle_cnt_next;
      // Capture np_save and target at start
      if (start && state == IDLE) begin
        np_save <= num_points;
        target <= 4'd10 + {1'b0, num_points}; // 10 + 2*n (n up to 8 => max 26 fits in 5 bits; we use 4 bits as cycles counted beyond start up to 26; 4 bits can hold up to 15 only; adjust below)
      end
      // Cycle counter increments in non-IDLE; if target may exceed 15, we handle modulo but spec uses <= 26 which needs 5 bits
      // For simplicity, we keep cycle_cnt as 5 bits below and cast here.

      // Output timing: valid_loop and done appear at t = target
      // Done should be a single-cycle pulse
      if (({1'b0, cycle_cnt} == 5'd0) || (state == IDLE)) begin
        done <= 1'b0;
        valid_loop <= 1'b0;
      end

      if (state == DONE) begin
        // In DONE, hold valid_loop until next start; done should already be asserted on entry
        // valid_loop will be set combinatorially before DONE
      end
    end
  end

  // Adjust cycle_cnt width for target up to 26
  logic [4:0] cycle_cnt_int;
  logic [4:0] cycle_cnt_next_int;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt_int <= 5'd0;
    end else begin
      cycle_cnt_int <= cycle_cnt_next_int;
    end
  end
  assign cycle_cnt = cycle_cnt_int[3:0]; // low 4 bits not used beyond 15, but kept for compatibility
  assign cycle_cnt_next = cycle_cnt_int[3:0];
  assign cycle_cnt_next_int = (state == IDLE) ? 5'd0 : (cycle_cnt_int + 5'd1);

  // Next-state logic and point loading
  always @(*) begin
    next_state = state;
    load_cnt_next = load_cnt;

    case (state)
      IDLE: begin
        load_cnt_next = 4'd0;
        if (start) begin
          next_state = LOADING;
          load_cnt_next = 4'd0;
        end
      end

      LOADING: begin
        // Load points while point_valid is high; ignore when not valid
        if (point_valid && (load_cnt < np_save)) begin
          load_cnt_next = load_cnt + 1;
        end
        if (load_cnt == np_save) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Stay here until time to present result
        if (cycle_cnt_next_int == (5'd10 + {2'b0, np_save})) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Hold result one cycle, then return to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Load points into arrays
  always @(posedge clk) begin
    if (state == LOADING && point_valid && (load_cnt < np_save)) begin
      xs[load_cnt] <= x_in;
      ys[load_cnt] <= y_in;
    end
  end

  // Compute results combinatorially during PROCESSING
  // Save result into valid_loop_d and set done when we enter DONE
  always @(*) begin
    // defaults
    valid_loop_d = 1'b0;

    if (state == PROCESSING) begin
      // Quick rejects
      if (np_save < 3) begin
        valid_loop_d = 1'b0;
      end else if (load_cnt != np_save) begin
        // Shouldn't happen; if not all points loaded, invalid
        valid_loop_d = 1'b0;
      end else begin
        // Graph checks
        // Check for any duplicate point
        valid_loop_d = 1'b1;

        // Compute degrees and neighbor masks
        for (int i = 0; i < 8; i++) begin
          deg[i] = 1'b0;
          has_x_neighbor[i] = 1'b0;
          has_y_neighbor[i] = 1'b0;
        end

        for (int i = 0; i < MAX_P; i++) begin
          if (i < np_save) begin
            for (int j = 0; j < MAX_P; j++) begin
              if (j < np_save && j != i) begin
                if (xs[i] == xs[j]) begin
                  deg[i] = deg[i] + 1'b1;
                  has_x_neighbor[i] = 1'b1;
                end
                if (ys[i] == ys[j]) begin
                  deg[i] = deg[i] + 1'b1;
                  has_y_neighbor[i] = 1'b1;
                end
              end
            end
          end
        end

        // Degree checks
        even_deg_ok = 1'b1;
        no_loose_ends = 1'b1;
        for (int i = 0; i < 8; i++) begin
          if (i < np_save) begin
            if (deg[i] != 2) no_loose_ends = 1'b0;
            // loop only needs even degree 2 for all vertices, but we require exactly 2
            if (deg[i] != 2) even_deg_ok = 1'b0;
          end
        end

        // Closedness: last and first must share x or y
        if (np_save > 0) begin
          closed_ok = (xs[0] == xs[np_save-1]) || (ys[0] == ys[np_save-1]);
        end else begin
          closed_ok = 1'b0;
        end

        // Single cycle: traverse from p0 following degree-2 graph and ensure we return to p0 after np steps
        cycle_ok = 1'b1;
        if (closed_ok && no_loose_ends) begin
          logic [2:0] nxt;
          nxt = 3'd0;
          for (int step = 0; step < 8; step++) begin
            if (step < np_save) begin
              // choose next neighbor that is not the previous one (except at first step)
              logic [7:0] cand_mask;
              logic [2:0] next_cand;
              logic found;
              int count_cand;
              int prev_idx;
              // Build candidate mask
              cand_mask = 8'd0;
              for (int k = 0; k < 8; k++) begin
                if (k < np_save && k != nxt) begin
                  if ((xs[nxt] == xs[k]) || (ys[nxt] == ys[k])) begin
                    cand_mask[k] = 1'b1;
                  end
                end
              end
              // If step == 0, allow any valid neighbor
              // Else, avoid going back to previous index (nxt is current; we need prev to decide)
              // We'll track prev by using step and a temp variable for prev index
              // Simplify: keep a running 'prev' register
            end
          end
        end

        // Implement simple cycle check using prev tracking
        if (closed_ok && no_loose_ends) begin
          logic [2:0] prev_idx;
          logic [2:0] cur_idx;
          logic fail;
          fail = 1'b0;
          cur_idx = 3'd0;
          prev_idx = 3'd0; // undefined for first step
          for (int step = 0; step < 8; step++) begin
            if (step < np_save) begin
              logic [7:0] valid_mask;
              valid_mask = 8'd0;
              for (int k = 0; k < 8; k++) begin
                if (k < np_save && k != cur_idx) begin
                  // neighbor if shares x or y
                  if ((xs[cur_idx] == xs[k]) || (ys[cur_idx] == ys[k])) begin
                    valid_mask[k] = 1'b1;
                  end
                end
              end
              if (step > 0) begin
                // exclude going back to prev_idx
                valid_mask[prev_idx] = 1'b0;
              end
              // Count bits
              int cnt;
              cnt = 0;
              for (int b = 0; b < 8; b++) begin
                if (valid_mask[b]) cnt++;
              end
              if (cnt != 1) begin
                fail = 1'b1;
              end else begin
                // find next
                for (int b = 0; b < 8; b++) begin
                  if (valid_mask[b]) begin
                    prev_idx = cur_idx;
                    cur_idx = b[2:0];
                    break;
                  end
                end
              end
            end
          end
          // After np_save steps, must be back at start (0) and neighbor should be prev
          if (cur_idx != 3'd0) fail = 1'b1;
          // ensure that cur_idx (0) and prev_idx are neighbors (will be true if traversal worked)
          if (fail) cycle_ok = 1'b0; else cycle_ok = 1'b1;
        end else begin
          cycle_ok = 1'b0;
        end

        // Orientation (H/V) check
        for (int i = 0; i < 8; i++) begin
          hor[i] = 1'b0;
          ver[i] = 1'b0;
        end
        for (int i = 0; i < MAX_P; i++) begin
          if (i < np_save) begin
            int j;
            j = (i + 1) % np_save;
            if (ys[i] == ys[j]) hor[i] = 1'b1;
            if (xs[i] == xs[j]) ver[i] = 1'b1;
          end
        end
        h_cnt = 0;
        v_cnt = 0;
        for (int i = 0; i < 8; i++) begin
          if (i < np_save) begin
            if (hor[i]) h_cnt = h_cnt + 1;
            if (ver[i]) v_cnt = v_cnt + 1;
          end
        end
        orient_ok = (h_cnt == v_cnt);

        // Self-intersection checks
        collinear_overlap = 1'b0;
        improper_cross = 1'b0;

        for (int i = 0; i < 8 && !collinear_overlap; i++) begin
          if (!(i < np_save)) continue;
          int j;
          j = (i + 1) % np_save;
          // skip degenerate segments (identical points)
          if (xs[i] == xs[j] && ys[i] == ys[j]) begin
            collinear_overlap = 1'b1; // degenerate edge
          end
          for (int k = i + 1; k < 8 && !collinear_overlap && !improper_cross; k++) begin
            if (!(k < np_save)) continue;
            int l;
            l = (k + 1) % np_save;
            // Adjacent segments: i with i+1, and k with k+1; also first and last are adjacent
            int ip1, kp1;
            ip1 = (i + 1) % np_save;
            kp1 = (k + 1) % np_save;
            logic adjacent;
            adjacent = (i == k) || (i == kp1) || (ip1 == k);
            // Also consider wrap-around adjacency between last and first
            if (!adjacent) begin
              adjacent = ((i == np_save-1) && (k == 0)) || ((k == np_save-1) && (i == 0));
            end

            // If adjacent, only check they share exactly one endpoint (no collinear overlap)
            if (adjacent) begin
              // shared endpoint check
              logic share_one;
              share_one = 1'b0;
              if ((xs[i]==xs[k] && ys[i]==ys[k]) || (xs[i]==xs[l] && ys[i]==ys[l]) || (xs[j]==xs[k] && ys[j]==ys[k]) || (xs[j]==xs[l] && ys[j]==ys[l])) begin
                share_one = 1'b1;
              end
              if (!share_one) begin
                // Should share exactly one endpoint; if none, invalid (disconnected)
                collinear_overlap = 1'b1; // treat as invalid
              end else begin
                // If collinear and overlapping beyond endpoint, invalid
                // Determine if they are collinear on same line
                logic same_line;
                same_line = 1'b0;
                if (hor[i] && hor[k]) begin
                  if (ys[i] == ys[k]) same_line = 1'b1;
                end else if (ver[i] && ver[k]) begin
                  if (xs[i] == xs[k]) same_line = 1'b1;
                end
                if (same_line) begin
                  // Check for interior overlap beyond endpoint
                  // Gather x or y ranges
                  logic overl;
                  overl = 1'b0;
                  if (hor[i] && hor[k]) begin
                    // overlap if ranges on y==ys[i] intersect with more than a point
                    int a1, a2, b1, b2;
                    a1 = xs[i]; a2 = xs[j];
                    b1 = xs[k]; b2 = xs[l];
                    if (a1 > a2) begin int t; t=a1; a1=a2; a2=t; end
                    if (b1 > b2) begin int t; t=b1; b1=b2; b2=t; end
                    // overlap if intervals [a1,a2] and [b1,b2] overlap more than at a single point
                    overl = ( (a1 <= b2 && b1 <= a2) && !( (a1==b2) || (a2==b1) ) );
                  end else if (ver[i] && ver[k]) begin
                    int a1, a2, b1, b2;
                    a1 = ys[i]; a2 = ys[j];
                    b1 = ys[k]; b2 = ys[l];
                    if (a1 > a2) begin int t; t=a1; a1=a2; a2=t; end
                    if (b1 > b2) begin int t; t=b1; b1=b2; b2=t; end
                    overl = ( (a1 <= b2 && b1 <= a2) && !( (a1==b2) || (a2==b1) ) );
                  end
                  if (overl) collinear_overlap = 1'b1;
                end
              end
              continue;
            end

            // Non-adjacent segments: must not intersect at all (no endpoints touching, no crosses)
            // Only orthogonal crossing or endpoint touching is allowed if they are actually the same point (loop corners)
            // But since we require exactly two neighbors per point, endpoint touching apart from adjacency is not allowed.
            // So, simply disallow any intersection between non-adjacent segments.
            // Evaluate intersection
            logic inter;
            inter = 1'b0;
            // Orthogonal case
            if (hor[i] && ver[k]) begin
              // segment i: y=ys[i], x in [min(xs[i],xs[j]), max(xs[i],xs[j])]
              // segment k: x=xs[k], y in [min(ys[k],ys[l]), max(ys[k],ys[l])]
              logic [15:0] hx1, hx2, ky1, ky2;
              hx1 = (xs[i] < xs[j]) ? xs[i] : xs[j];
              hx2 = (xs[i] < xs[j]) ? xs[j] : xs[i];
              ky1 = (ys[k] < ys[l]) ? ys[k] : ys[l];
              ky2 = (ys[k] < ys[l]) ? ys[l] : ys[k];
              if ( (ys[i] >= ky1) && (ys[i] <= ky2) && (xs[k] >= hx1) && (xs[k] <= hx2) ) begin
                inter = 1'b1;
              end
            end else if (ver[i] && hor[k]) begin
              logic [15:0] vx1, vy1, vy2, hx1, hx2;
              vx1 = xs[i];
              vy1 = (ys[i] < ys[j]) ? ys[i] : ys[j];
              vy2 = (ys[i] < ys[j]) ? ys[j] : ys[i];
              hx1 = (xs[k] < xs[l]) ? xs[k] : xs[l];
              hx2 = (xs[k] < xs[l]) ? xs[l] : xs[k];
              if ( (xs[i] >= hx1) && (xs[i] <= hx2) && (ys[k] >= vy1) && (ys[k] <= vy2) ) begin
                inter = 1'b1;
              end
            end else begin
              // Collinear non-adjacent: any overlap beyond endpoint is forbidden
              logic same_line;
              same_line = 1'b0;
              if (hor[i] && hor[k]) begin
                if (ys[i] == ys[k]) same_line = 1'b1;
              end else if (ver[i] && ver[k]) begin
                if (xs[i] == xs[k]) same_line = 1'b1;
              end
              if (same_line) begin
                if (hor[i] && hor[k]) begin
                  int a1,a2,b1,b2;
                  a1 = xs[i]; a2 = xs[j];
                  b1 = xs[k]; b2 = xs[l];
                  if (a1 > a2) begin int t; t=a1; a1=a2; a2=t; end
                  if (b1 > b2) begin int t; t=b1; b1=b2; b2=t; end
                  inter = (a1 <= b2 && b1 <= a2);
                end else if (ver[i] && ver[k]) begin
                  int a1,a2,b1,b2;
                  a1 = ys[i]; a2 = ys[j];
                  b1 = ys[k]; b2 = ys[l];
                  if (a1 > a2) begin int t; t=a1; a1=a2; a2=t; end
                  if (b1 > b2) begin int t; t=b1; b1=b2; b2=t; end
                  inter = (a1 <= b2 && b1 <= a2);
                end
              end else begin
                inter = 1'b0;
              end
            end

            if (inter) begin
              // If they intersect only at an endpoint that is a shared vertex, that would make the vertex degree > 2 or create a chord.
              // By construction, any endpoint shared by non-adjacent segments means a vertex with degree > 2, which we already reject.
              // So treat any intersection as improper_cross.
              improper_cross = 1'b1;
            end
          end
        end

        // Combine all conditions
        valid_loop_d = closed_ok && no_loose_ends && even_deg_ok && cycle_ok && orient_ok && !collinear_overlap && !improper_cross;
      end
    end
  end

  // Drive output at the exact time
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      valid_loop <= 1'b0;
    end else begin
      if (next_state == DONE) begin
        done <= 1'b1;
        valid_loop <= valid_loop_d;
      end else if (state == IDLE) begin
        done <= 1'b0;
        valid_loop <= 1'b0;
      end
    end
  end

endmodule