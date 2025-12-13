module rocket_safety_checker(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [15:0] engine1_x [0:7],
  input [15:0] engine1_y [0:7],
  input [15:0] engine2_x [0:7],
  input [15:0] engine2_y [0:7],
  output reg result,
  output reg done
);

  // ------------------------------------------------------------
  // Parameters
  // ------------------------------------------------------------
  localparam MAX_PTS   = 8;
  localparam MAX_HULL  = 8;

  // FSM States
  typedef enum logic [4:0] {
    S_IDLE              = 5'd0,
    S_INIT              = 5'd1,
    S_CH1_FIND_P0       = 5'd2,
    S_CH1_SORT_SETUP    = 5'd3,
    S_CH1_SORT_OUTER    = 5'd4,
    S_CH1_SORT_INNER    = 5'd5,
    S_CH1_SORT_SWAP     = 5'd6,
    S_CH1_SCAN_INIT     = 5'd7,
    S_CH1_SCAN_LOOP     = 5'd8,
    S_CH2_FIND_P0       = 5'd9,
    S_CH2_SORT_SETUP    = 5'd10,
    S_CH2_SORT_OUTER    = 5'd11,
    S_CH2_SORT_INNER    = 5'd12,
    S_CH2_SORT_SWAP     = 5'd13,
    S_CH2_SCAN_INIT     = 5'd14,
    S_CH2_SCAN_LOOP     = 5'd15,
    S_COMPARE_PREP      = 5'd16,
    S_COMPARE_SIMPLE    = 5'd17,
    S_BUILD_FEATURES    = 5'd18,
    S_BUILD_TEXT        = 5'd19,
    S_Z_BUILD           = 5'd20,
    S_Z_RUN             = 5'd21,
    S_DONE              = 5'd22
  } state_t;

  state_t state, next_state;

  // ------------------------------------------------------------
  // Internal storage for engine points
  // ------------------------------------------------------------
  // Engine 1 working arrays
  reg [15:0] e1_x [0:MAX_PTS-1];
  reg [15:0] e1_y [0:MAX_PTS-1];

  // Engine 2 working arrays
  reg [15:0] e2_x [0:MAX_PTS-1];
  reg [15:0] e2_y [0:MAX_PTS-1];

  // Load inputs when start
  integer li;

  // ------------------------------------------------------------
  // Convex hull arrays (after Graham scan)
  // ------------------------------------------------------------
  reg [15:0] h1_x [0:MAX_HULL-1];
  reg [15:0] h1_y [0:MAX_HULL-1];
  reg [3:0]  h1_sz;

  reg [15:0] h2_x [0:MAX_HULL-1];
  reg [15:0] h2_y [0:MAX_HULL-1];
  reg [3:0]  h2_sz;

  // ------------------------------------------------------------
  // Shared indices and temporaries
  // ------------------------------------------------------------
  reg [3:0] idx_i, idx_j;
  reg [3:0] sort_outer_i, sort_inner_j;

  // Base point index for each engine
  reg [2:0] e1_p0_idx, e2_p0_idx;

  // Temporaries for min search
  reg [15:0] cur_min_y, cur_min_x;
  reg [15:0] tmp_x, tmp_y;

  // Scan stack pointer (size <= MAX_HULL)
  reg [3:0] sp;

  // Variables for Z algorithm and feature arrays
  // Each feature element is a 32-bit tuple encoded as:
  // [31:16] = distance_sq, [15:0] = signed dot_product[15:0] truncated
  // Distances are up to (2^16-1)^2*2 < 2^33, truncated to 16 LSBs for this tuple.

  localparam MAX_FEAT = MAX_HULL;

  reg [31:0] feat1 [0:MAX_FEAT-1];
  reg [31:0] feat2 [0:MAX_FEAT-1];

  // Concatenated text for Z algorithm: T = feat1, feat2, feat2
  // Maximum length = 8 + 8 + 8 = 24
  localparam MAX_TEXT = 24;
  reg [31:0] text [0:MAX_TEXT-1];
  reg [5:0]  text_len;

  // Z array
  reg [5:0] Z [0:MAX_TEXT-1];

  reg [5:0] z_l, z_r;
  reg [5:0] z_i;
  reg [5:0] z_k;

  // For simple two-point comparison
  reg [31:0] d1_sq, d2_sq;

  // Flags
  reg match_found;

  // 
  // Helper functions/tasks
  //

  // Cross product (P1-P0) x (P2-P0), using 16-bit coords -> 34-bit result
  function automatic signed [33:0] cross(
    input signed [15:0] x0,
    input signed [15:0] y0,
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2
  );
    signed [16:0] ax;
    signed [16:0] ay;
    signed [16:0] bx;
    signed [16:0] by;
    signed [33:0] c1;
    signed [33:0] c2;
    begin
      ax = x1 - x0;
      ay = y1 - y0;
      bx = x2 - x0;
      by = y2 - y0;
      c1 = ax * by;
      c2 = ay * bx;
      cross = c1 - c2;
    end
  endfunction

  // Squared distance between two points
  function automatic [31:0] dist_sq(
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2
  );
    signed [16:0] dx;
    signed [16:0] dy;
    signed [33:0] dx2;
    signed [33:0] dy2;
    begin
      dx = x2 - x1;
      dy = y2 - y1;
      dx2 = dx * dx;
      dy2 = dy * dy;
      dist_sq = dx2[31:0] + dy2[31:0];
    end
  endfunction

  // Dot product of consecutive edge vectors for feature generation
  function automatic signed [31:0] dot_vec(
    input signed [15:0] ax,
    input signed [15:0] ay,
    input signed [15:0] bx,
    input signed [15:0] by
  );
    signed [31:0] p1, p2;
    begin
      p1 = ax * bx;
      p2 = ay * by;
      dot_vec = p1 + p2;
    end
  endfunction

  // Comparator for polar angle around base point with distance tiebreak
  // Returns 1 if (x1,y1) should come after (x2,y2)
  function automatic logic polar_greater(
    input signed [15:0] bx,
    input signed [15:0] by,
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2
  );
    signed [33:0] c;
    reg [31:0] d1, d2;
    begin
      c = cross(bx, by, x1, y1, x2, y2);
      if (c == 0) begin
        d1 = dist_sq(bx, by, x1, y1);
        d2 = dist_sq(bx, by, x2, y2);
        polar_greater = (d1 > d2);
      end else begin
        // We want ascending angle: negative cross => x2 is to left of x1
        // For Graham scan, sort by increasing polar angle; treat c < 0 as x1 > x2
        polar_greater = (c < 0);
      end
    end
  endfunction

  // ------------------------------------------------------------
  // Sequential logic: state, outputs, main FSM
  // ------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      result      <= 1'b0;
      done        <= 1'b0;
      h1_sz       <= 4'd0;
      h2_sz       <= 4'd0;
      match_found <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        // ------------------------------------------------------
        // IDLE: wait for start
        // ------------------------------------------------------
        S_IDLE: begin
          done        <= 1'b0;
          result      <= 1'b0;
          match_found <= 1'b0;
          if (start) begin
            // latch inputs into working arrays
            for (li = 0; li < MAX_PTS; li = li + 1) begin
              e1_x[li] <= engine1_x[li];
              e1_y[li] <= engine1_y[li];
              e2_x[li] <= engine2_x[li];
              e2_y[li] <= engine2_y[li];
            end
          end
        end

        // ------------------------------------------------------
        // INIT: basic init, choose next state
        // ------------------------------------------------------
        S_INIT: begin
          h1_sz       <= 4'd0;
          h2_sz       <= 4'd0;
          match_found <= 1'b0;
          idx_i       <= 4'd0;
          idx_j       <= 4'd0;
        end

        // ------------------------------------------------------
        // Engine1: find P0 = lowest y then lowest x
        // ------------------------------------------------------
        S_CH1_FIND_P0: begin
          if (idx_i == 4'd0) begin
            e1_p0_idx <= 3'd0;
            cur_min_y <= e1_y[0];
            cur_min_x <= e1_x[0];
            idx_i     <= 4'd1;
          end else if (idx_i < n) begin
            if ((e1_y[idx_i] < cur_min_y) ||
                (e1_y[idx_i] == cur_min_y && e1_x[idx_i] < cur_min_x)) begin
              cur_min_y <= e1_y[idx_i];
              cur_min_x <= e1_x[idx_i];
              e1_p0_idx <= idx_i[2:0];
            end
            idx_i <= idx_i + 1'b1;
          end
        end

        // ------------------------------------------------------
        // Engine1: setup for polar sort (swap P0 to index 0)
        // ------------------------------------------------------
        S_CH1_SORT_SETUP: begin
          if (e1_p0_idx != 3'd0) begin
            tmp_x              <= e1_x[0];
            tmp_y              <= e1_y[0];
            e1_x[0]            <= e1_x[e1_p0_idx];
            e1_y[0]            <= e1_y[e1_p0_idx];
            e1_x[e1_p0_idx]    <= tmp_x;
            e1_y[e1_p0_idx]    <= tmp_y;
          end
          sort_outer_i <= 4'd2;
          sort_inner_j <= 4'd1;
        end

        // ------------------------------------------------------
        // Engine1: bubble sort by polar angle around e1_x[0], e1_y[0]
        // ------------------------------------------------------
        S_CH1_SORT_OUTER: begin
          if (n <= 2) begin
            // no sort needed
          end else begin
            sort_inner_j <= 4'd1;
          end
        end

        S_CH1_SORT_INNER: begin
          if (sort_inner_j < (n - (sort_outer_i - 1))) begin
            // compare j and j+1
            if (polar_greater(e1_x[0], e1_y[0],
                              e1_x[sort_inner_j], e1_y[sort_inner_j],
                              e1_x[sort_inner_j+1], e1_y[sort_inner_j+1])) begin
              // need swap -> handled in SWAP state
            end
          end
        end

        S_CH1_SORT_SWAP: begin
          if (polar_greater(e1_x[0], e1_y[0],
                            e1_x[sort_inner_j], e1_y[sort_inner_j],
                            e1_x[sort_inner_j+1], e1_y[sort_inner_j+1])) begin
            tmp_x                          <= e1_x[sort_inner_j];
            tmp_y                          <= e1_y[sort_inner_j];
            e1_x[sort_inner_j]             <= e1_x[sort_inner_j+1];
            e1_y[sort_inner_j]             <= e1_y[sort_inner_j+1];
            e1_x[sort_inner_j+1]           <= tmp_x;
            e1_y[sort_inner_j+1]           <= tmp_y;
          end
          sort_inner_j <= sort_inner_j + 1'b1;
        end

        // ------------------------------------------------------
        // Engine1: Graham scan
        // ------------------------------------------------------
        S_CH1_SCAN_INIT: begin
          if (n == 0) begin
            h1_sz <= 4'd0;
          end else if (n == 1) begin
            h1_x[0] <= e1_x[0];
            h1_y[0] <= e1_y[0];
            h1_sz   <= 4'd1;
          end else if (n == 2) begin
            h1_x[0] <= e1_x[0];
            h1_y[0] <= e1_y[0];
            h1_x[1] <= e1_x[1];
            h1_y[1] <= e1_y[1];
            h1_sz   <= 4'd2;
          end else begin
            // Initialize stack with first two points
            h1_x[0] <= e1_x[0];
            h1_y[0] <= e1_y[0];
            h1_x[1] <= e1_x[1];
            h1_y[1] <= e1_y[1];
            sp      <= 4'd1;   // top index
            idx_i   <= 4'd2;   // next point index
          end
        end

        S_CH1_SCAN_LOOP: begin
          if (idx_i < n) begin
            if (sp > 0) begin
              // While turn is not counter-clockwise, pop
              if (cross(h1_x[sp-1], h1_y[sp-1],
                        h1_x[sp],   h1_y[sp],
                        e1_x[idx_i], e1_y[idx_i]) <= 0) begin
                sp <= sp - 1'b1;
              end else begin
                sp <= sp + 1'b1;
                h1_x[sp+1] <= e1_x[idx_i];
                h1_y[sp+1] <= e1_y[idx_i];
                idx_i      <= idx_i + 1'b1;
              end
            end else begin
              sp <= sp + 1'b1;
              h1_x[sp+1] <= e1_x[idx_i];
              h1_y[sp+1] <= e1_y[idx_i];
              idx_i      <= idx_i + 1'b1;
            end
          end else begin
            h1_sz <= sp + 1'b1;
          end
        end

        // ------------------------------------------------------
        // Engine2: same sequence as Engine1
        // ------------------------------------------------------
        S_CH2_FIND_P0: begin
          if (idx_i == 4'd0) begin
            e2_p0_idx <= 3'd0;
            cur_min_y <= e2_y[0];
            cur_min_x <= e2_x[0];
            idx_i     <= 4'd1;
          end else if (idx_i < m) begin
            if ((e2_y[idx_i] < cur_min_y) ||
                (e2_y[idx_i] == cur_min_y && e2_x[idx_i] < cur_min_x)) begin
              cur_min_y <= e2_y[idx_i];
              cur_min_x <= e2_x[idx_i];
              e2_p0_idx <= idx_i[2:0];
            end
            idx_i <= idx_i + 1'b1;
          end
        end

        S_CH2_SORT_SETUP: begin
          if (e2_p0_idx != 3'd0) begin
            tmp_x              <= e2_x[0];
            tmp_y              <= e2_y[0];
            e2_x[0]            <= e2_x[e2_p0_idx];
            e2_y[0]            <= e2_y[e2_p0_idx];
            e2_x[e2_p0_idx]    <= tmp_x;
            e2_y[e2_p0_idx]    <= tmp_y;
          end
          sort_outer_i <= 4'd2;
          sort_inner_j <= 4'd1;
        end

        S_CH2_SORT_OUTER: begin
          if (m <= 2) begin
          end else begin
            sort_inner_j <= 4'd1;
          end
        end

        S_CH2_SORT_INNER: begin
          if (sort_inner_j < (m - (sort_outer_i - 1))) begin
            if (polar_greater(e2_x[0], e2_y[0],
                              e2_x[sort_inner_j], e2_y[sort_inner_j],
                              e2_x[sort_inner_j+1], e2_y[sort_inner_j+1])) begin
            end
          end
        end

        S_CH2_SORT_SWAP: begin
          if (polar_greater(e2_x[0], e2_y[0],
                            e2_x[sort_inner_j], e2_y[sort_inner_j],
                            e2_x[sort_inner_j+1], e2_y[sort_inner_j+1])) begin
            tmp_x                          <= e2_x[sort_inner_j];
            tmp_y                          <= e2_y[sort_inner_j];
            e2_x[sort_inner_j]             <= e2_x[sort_inner_j+1];
            e2_y[sort_inner_j]             <= e2_y[sort_inner_j+1];
            e2_x[sort_inner_j+1]           <= tmp_x;
            e2_y[sort_inner_j+1]           <= tmp_y;
          end
          sort_inner_j <= sort_inner_j + 1'b1;
        end

        S_CH2_SCAN_INIT: begin
          if (m == 0) begin
            h2_sz <= 4'd0;
          end else if (m == 1) begin
            h2_x[0] <= e2_x[0];
            h2_y[0] <= e2_y[0];
            h2_sz   <= 4'd1;
          end else if (m == 2) begin
            h2_x[0] <= e2_x[0];
            h2_y[0] <= e2_y[0];
            h2_x[1] <= e2_x[1];
            h2_y[1] <= e2_y[1];
            h2_sz   <= 4'd2;
          end else begin
            h2_x[0] <= e2_x[0];
            h2_y[0] <= e2_y[0];
            h2_x[1] <= e2_x[1];
            h2_y[1] <= e2_y[1];
            sp      <= 4'd1;
            idx_i   <= 4'd2;
          end
        end

        S_CH2_SCAN_LOOP: begin
          if (idx_i < m) begin
            if (sp > 0) begin
              if (cross(h2_x[sp-1], h2_y[sp-1],
                        h2_x[sp],   h2_y[sp],
                        e2_x[idx_i], e2_y[idx_i]) <= 0) begin
                sp <= sp - 1'b1;
              end else begin
                sp <= sp + 1'b1;
                h2_x[sp+1] <= e2_x[idx_i];
                h2_y[sp+1] <= e2_y[idx_i];
                idx_i      <= idx_i + 1'b1;
              end
            end else begin
              sp <= sp + 1'b1;
              h2_x[sp+1] <= e2_x[idx_i];
              h2_y[sp+1] <= e2_y[idx_i];
              idx_i      <= idx_i + 1'b1;
            end
          end else begin
            h2_sz <= sp + 1'b1;
          end
        end

        // ------------------------------------------------------
        // Prepare comparison / handle degenerate sizes
        // ------------------------------------------------------
        S_COMPARE_PREP: begin
          match_found <= 1'b0;
        end

        // Simple cases: hull size 2 -> compare distance_sq
        S_COMPARE_SIMPLE: begin
          if (h1_sz != h2_sz) begin
            match_found <= 1'b0;
          end else if (h1_sz == 0 || h1_sz == 1) begin
            // Treat 0 or 1-point hulls as trivially matching by size
            match_found <= 1'b1;
          end else if (h1_sz == 2) begin
            d1_sq <= dist_sq(h1_x[0], h1_y[0], h1_x[1], h1_y[1]);
            d2_sq <= dist_sq(h2_x[0], h2_y[0], h2_x[1], h2_y[1]);
            match_found <= (d1_sq == d2_sq);
          end
        end

        // ------------------------------------------------------
        // Build features for 3+ vertex hulls
        // feat[i] = {dist_sq(edge_i), dot(edge_i, next_edge)} (truncated)
        // ------------------------------------------------------
        S_BUILD_FEATURES: begin
          if (h1_sz == h2_sz && h1_sz >= 3) begin
            // build feat1 and feat2
            for (idx_i = 0; idx_i < h1_sz; idx_i = idx_i + 1) begin
              integer ni1, ni2;
              integer j1, j2;
              reg signed [15:0] e1_ax, e1_ay, e1_bx, e1_by;
              reg signed [15:0] e2_ax, e2_ay, e2_bx, e2_by;
              reg [31:0] d_sq1, d_sq2;
              reg signed [31:0] dp1, dp2;

              ni1 = (idx_i + 1) % h1_sz;
              j1  = (idx_i + 2) % h1_sz;
              e1_ax = h1_x[ni1] - h1_x[idx_i];
              e1_ay = h1_y[ni1] - h1_y[idx_i];
              e1_bx = h1_x[j1]  - h1_x[ni1];
              e1_by = h1_y[j1]  - h1_y[ni1];
              d_sq1 = dist_sq(h1_x[idx_i], h1_y[idx_i], h1_x[ni1], h1_y[ni1]);
              dp1   = dot_vec(e1_ax, e1_ay, e1_bx, e1_by);
              feat1[idx_i] <= {d_sq1[15:0], dp1[15:0]};

              ni2 = (idx_i + 1) % h2_sz;
              j2  = (idx_i + 2) % h2_sz;
              e2_ax = h2_x[ni2] - h2_x[idx_i];
              e2_ay = h2_y[ni2] - h2_y[idx_i];
              e2_bx = h2_x[j2]  - h2_x[ni2];
              e2_by = h2_y[j2]  - h2_y[ni2];
              d_sq2 = dist_sq(h2_x[idx_i], h2_y[idx_i], h2_x[ni2], h2_y[ni2]);
              dp2   = dot_vec(e2_ax, e2_ay, e2_bx, e2_by);
              feat2[idx_i] <= {d_sq2[15:0], dp2[15:0]};
            end
          end
        end

        // ------------------------------------------------------
        // Build concatenated text for Z algorithm: feat1 + feat2 + feat2
        // ------------------------------------------------------
        S_BUILD_TEXT: begin
          if (h1_sz == h2_sz && h1_sz >= 3) begin
            integer k;
            for (k = 0; k < h1_sz; k = k + 1) begin
              text[k] <= feat1[k];
            end
            for (k = 0; k < h2_sz; k = k + 1) begin
              text[h1_sz + k] <= feat2[k];
            end
            for (k = 0; k < h2_sz; k = k + 1) begin
              text[h1_sz + h2_sz + k] <= feat2[k];
            end
            text_len <= h1_sz + h2_sz + h2_sz;
          end
          // init Z vars
          z_l <= 6'd0;
          z_r <= 6'd0;
          z_i <= 6'd1;
        end

        // ------------------------------------------------------
        // Initialize Z[0] and boundaries
        // ------------------------------------------------------
        S_Z_BUILD: begin
          Z[0] <= 6'd0;
        end

        // ------------------------------------------------------
        // Run Z algorithm incrementally, also detect match
        // ------------------------------------------------------
        S_Z_RUN: begin
          if (!match_found && z_i < text_len) begin
            if (z_i > z_r) begin
              // explicit match from scratch
              z_l <= z_i;
              z_r <= z_i;
              while (z_r < text_len && text[z_r - z_l] == text[z_r]) begin
                z_r <= z_r + 1'b1;
              end
              Z[z_i] <= z_r - z_l;
              z_r    <= z_r - 1'b1;
            end else begin
              z_k = z_i - z_l;
              if (Z[z_k] < (z_r - z_i + 1)) begin
                Z[z_i] <= Z[z_k];
              end else begin
                z_l <= z_i;
                while (z_r + 1 < text_len && text[z_r + 1 - z_l] == text[z_r + 1]) begin
                  z_r <= z_r + 1'b1;
                end
                Z[z_i] <= z_r - z_l + 1'b0;
              end
            end

            // check for full pattern match starting within second+third segment
            if (Z[z_i] >= h1_sz && z_i >= h1_sz && z_i < (h1_sz + h2_sz)) begin
              match_found <= 1'b1;
            end

            z_i <= z_i + 1'b1;
          end
        end

        // ------------------------------------------------------
        // DONE: drive result and done
        // ------------------------------------------------------
        S_DONE: begin
          result <= match_found;
          done   <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Next-state logic (simple, conservative to stay <100 cycles)
  // ------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_CH1_FIND_P0;
      end

      // Engine1 P0 search
      S_CH1_FIND_P0: begin
        if (idx_i >= n)
          next_state = S_CH1_SORT_SETUP;
      end

      // Engine1 sort
      S_CH1_SORT_SETUP: begin
        if (n <= 2)
          next_state = S_CH1_SCAN_INIT;
        else
          next_state = S_CH1_SORT_OUTER;
      end

      S_CH1_SORT_OUTER: begin
        if (n <= 2) begin
          next_state = S_CH1_SCAN_INIT;
        end else if (sort_outer_i < n) begin
          next_state = S_CH1_SORT_INNER;
        end else begin
          next_state = S_CH1_SCAN_INIT;
        end
      end

      S_CH1_SORT_INNER: begin
        if (sort_inner_j < (n - (sort_outer_i - 1))) begin
          next_state = S_CH1_SORT_SWAP;
        end else begin
          if (sort_outer_i + 1 < n)
            next_state = S_CH1_SORT_OUTER;
          else
            next_state = S_CH1_SCAN_INIT;
          sort_outer_i = sort_outer_i + 1'b1;
        end
      end

      S_CH1_SORT_SWAP: begin
        if (sort_inner_j + 1 < (n - (sort_outer_i - 1))) begin
          next_state = S_CH1_SORT_INNER;
        end else begin
          if (sort_outer_i + 1 < n)
            next_state = S_CH1_SORT_OUTER;
          else
            next_state = S_CH1_SCAN_INIT;
          sort_outer_i = sort_outer_i + 1'b1;
        end
      end

      // Engine1 scan
      S_CH1_SCAN_INIT: begin
        if (n <= 2)
          next_state = S_CH2_FIND_P0;
        else
          next_state = S_CH1_SCAN_LOOP;
      end

      S_CH1_SCAN_LOOP: begin
        if (idx_i >= n)
          next_state = S_CH2_FIND_P0;
      end

      // Engine2
      S_CH2_FIND_P0: begin
        if (idx_i >= m)
          next_state = S_CH2_SORT_SETUP;
      end

      S_CH2_SORT_SETUP: begin
        if (m <= 2)
          next_state = S_CH2_SCAN_INIT;
        else
          next_state = S_CH2_SORT_OUTER;
      end

      S_CH2_SORT_OUTER: begin
        if (m <= 2) begin
          next_state = S_CH2_SCAN_INIT;
        end else if (sort_outer_i < m) begin
          next_state = S_CH2_SORT_INNER;
        end else begin
          next_state = S_CH2_SCAN_INIT;
        end
      end

      S_CH2_SORT_INNER: begin
        if (sort_inner_j < (m - (sort_outer_i - 1))) begin
          next_state = S_CH2_SORT_SWAP;
        end else begin
          if (sort_outer_i + 1 < m)
            next_state = S_CH2_SORT_OUTER;
          else
            next_state = S_CH2_SCAN_INIT;
          sort_outer_i = sort_outer_i + 1'b1;
        end
      end

      S_CH2_SORT_SWAP: begin
        if (sort_inner_j + 1 < (m - (sort_outer_i - 1))) begin
          next_state = S_CH2_SORT_INNER;
        end else begin
          if (sort_outer_i + 1 < m)
            next_state = S_CH2_SORT_OUTER;
          else
            next_state = S_CH2_SCAN_INIT;
          sort_outer_i = sort_outer_i + 1'b1;
        end
      end

      S_CH2_SCAN_INIT: begin
        if (m <= 2)
          next_state = S_COMPARE_PREP;
        else
          next_state = S_CH2_SCAN_LOOP;
      end

      S_CH2_SCAN_LOOP: begin
        if (idx_i >= m)
          next_state = S_COMPARE_PREP;
      end

      S_COMPARE_PREP: begin
        if (h1_sz != h2_sz || h1_sz <= 2)
          next_state = S_COMPARE_SIMPLE;
        else
          next_state = S_BUILD_FEATURES;
      end

      S_COMPARE_SIMPLE: begin
        if (h1_sz >= 3 && h1_sz == h2_sz)
          next_state = S_BUILD_FEATURES;
        else
          next_state = S_DONE;
      end

      S_BUILD_FEATURES: begin
        next_state = S_BUILD_TEXT;
      end

      S_BUILD_TEXT: begin
        next_state = S_Z_BUILD;
      end

      S_Z_BUILD: begin
        next_state = S_Z_RUN;
      end

      S_Z_RUN: begin
        if (match_found)
          next_state = S_DONE;
        else if (z_i >= text_len)
          next_state = S_DONE;
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule