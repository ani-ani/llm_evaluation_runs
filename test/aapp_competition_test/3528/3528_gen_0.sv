module convex_hull_area(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nails,
  input [7:0][15:0] nail_x,
  input [7:0][15:0] nail_y,
  input [5:0][1:0] remove_seq,
  output reg [35:0] area,
  output reg valid,
  output reg done
);

  // internal point storage (max 8 original nails, some may be removed)
  reg [15:0] pts_x[7:0];
  reg [15:0] pts_y[7:0];
  reg       pts_alive[7:0];

  reg [2:0] cur_n;           // current alive count (max 8)
  reg [2:0] step_idx;        // 0..6 (6 removals)

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_LOAD      = 4'd1,
    S_REMOVE    = 4'd2,
    S_HULL_INIT = 4'd3,
    S_HULL_SCAN = 4'd4,
    S_HULL_LOW  = 4'd5,
    S_HULL_UP_INIT = 4'd6,
    S_HULL_UP   = 4'd7,
    S_AREA_INIT = 4'd8,
    S_AREA_ACC  = 4'd9,
    S_OUTPUT    = 4'd10,
    S_DONE      = 4'd11
  } state_t;

  state_t state, next_state;

  // indices and temporaries
  reg [3:0] i_scan;          // generic iterator
  reg [3:0] i_build;         // hull building index
  reg [3:0] i_area;

  // hull-related
  reg [2:0] anchor_idx;      // lowest x (then y) point index

  // sorted indices by angle (fixed original index refs)
  reg [2:0] sorted[7:0];

  // lower and upper hull index stacks (store original point indices)
  reg [2:0] low[7:0];
  reg [3:0] low_len;

  reg [2:0] up[7:0];
  reg [3:0] up_len;

  // final hull (cyclic, no repeated last)
  reg [2:0] hull[7:0];
  reg [3:0] hull_len;

  // direction decode from remove_seq
  wire [1:0] cur_dir = remove_seq[step_idx];

  // helpers for comparisons and math
  function automatic signed [31:0] cross(
    input signed [15:0] x1,
    input signed [15:0] y1,
    input signed [15:0] x2,
    input signed [15:0] y2,
    input signed [15:0] x3,
    input signed [15:0] y3
  );
    // (x2-x1,y2-y1) x (x3-x2,y3-y2)
    signed [16:0] ax;
    signed [16:0] ay;
    signed [16:0] bx;
    signed [16:0] by;
    signed [33:0] c1;
    signed [33:0] c2;
    begin
      ax = x2 - x1;
      ay = y2 - y1;
      bx = x3 - x2;
      by = y3 - y2;
      c1 = ax * by;
      c2 = ay * bx;
      cross = c1 - c2;
    end
  endfunction

  // compare angles (anchor->a) vs (anchor->b) using cross product
  function automatic signed [31:0] cross_anchor(
    input [2:0] anchor,
    input [2:0] a,
    input [2:0] b
  );
    signed [16:0] ax, ay, bx, by;
    signed [33:0] c1, c2;
    begin
      ax = $signed(pts_x[a]) - $signed(pts_x[anchor]);
      ay = $signed(pts_y[a]) - $signed(pts_y[anchor]);
      bx = $signed(pts_x[b]) - $signed(pts_x[anchor]);
      by = $signed(pts_y[b]) - $signed(pts_y[anchor]);
      c1 = ax * by;
      c2 = ay * bx;
      cross_anchor = c1 - c2;
    end
  endfunction

  // state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset all
      valid     <= 1'b0;
      done      <= 1'b0;
      area      <= 36'd0;
      step_idx  <= 3'd0;
      cur_n     <= 3'd0;
      i_scan    <= 4'd0;
      i_build   <= 4'd0;
      i_area    <= 4'd0;
      anchor_idx <= 3'd0;
      low_len   <= 4'd0;
      up_len    <= 4'd0;
      hull_len  <= 4'd0;
    end else begin
      valid <= 1'b0; // default

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // load input nails
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
              pts_x[k]     <= nail_x[k];
              pts_y[k]     <= nail_y[k];
              pts_alive[k] <= (k < num_nails);
            end
            cur_n    <= num_nails;
            step_idx <= 3'd0;
          end
        end

        S_LOAD: begin
          // not used separately (we fold into transition)
        end

        // Remove one extreme point based on cur_dir
        S_REMOVE: begin
          if (cur_n > 0) begin
            integer j;
            reg [15:0] best_x;
            reg [15:0] best_y;
            reg [2:0]  best_idx;
            reg        init;

            init     = 1'b0;
            best_x   = 16'd0;
            best_y   = 16'd0;
            best_idx = 3'd0;

            for (j = 0; j < 8; j = j + 1) begin
              if (pts_alive[j]) begin
                if (!init) begin
                  init     = 1'b1;
                  best_x   = pts_x[j];
                  best_y   = pts_y[j];
                  best_idx = j[2:0];
                end else begin
                  case (cur_dir)
                    2'b00: begin
                      // Leftmost: min x, then min y
                      if (pts_x[j] < best_x || (pts_x[j] == best_x && pts_y[j] < best_y)) begin
                        best_x   <= pts_x[j];
                        best_y   <= pts_y[j];
                        best_idx <= j[2:0];
                      end
                    end
                    2'b01: begin
                      // Rightmost: max x, then min y
                      if (pts_x[j] > best_x || (pts_x[j] == best_x && pts_y[j] < best_y)) begin
                        best_x   <= pts_x[j];
                        best_y   <= pts_y[j];
                        best_idx <= j[2:0];
                      end
                    end
                    2'b10: begin
                      // Up: max y, then min x
                      if (pts_y[j] > best_y || (pts_y[j] == best_y && pts_x[j] < best_x)) begin
                        best_x   <= pts_x[j];
                        best_y   <= pts_y[j];
                        best_idx <= j[2:0];
                      end
                    end
                    2'b11: begin
                      // Down: min y, then min x
                      if (pts_y[j] < best_y || (pts_y[j] == best_y && pts_x[j] < best_x)) begin
                        best_x   <= pts_x[j];
                        best_y   <= pts_y[j];
                        best_idx <= j[2:0];
                      end
                    end
                  endcase
                end
              end
            end

            // mark chosen as removed
            pts_alive[best_idx] <= 1'b0;
            cur_n <= cur_n - 3'd1;
          end
        end

        // Initialize convex hull: find anchor and initial sorted order indices
        S_HULL_INIT: begin
          integer j;
          reg [15:0] a_x;
          reg [15:0] a_y;
          reg [2:0]  a_idx;
          reg        init;

          // find anchor: minimum x, then minimum y among alive
          init  = 1'b0;
          a_x   = 16'd0;
          a_y   = 16'd0;
          a_idx = 3'd0;
          for (j = 0; j < 8; j = j + 1) begin
            if (pts_alive[j]) begin
              if (!init) begin
                init  = 1'b1;
                a_x   = pts_x[j];
                a_y   = pts_y[j];
                a_idx = j[2:0];
              end else if (pts_x[j] < a_x || (pts_x[j] == a_x && pts_y[j] < a_y)) begin
                a_x   <= pts_x[j];
                a_y   <= pts_y[j];
                a_idx <= j[2:0];
              end
            end
          end

          anchor_idx <= a_idx;

          // build initial sorted list: anchor first, others in any order (will refine in S_HULL_SCAN)
          integer idx;
          idx = 0;
          for (j = 0; j < 8; j = j + 1) begin
            if (pts_alive[j]) begin
              sorted[idx] <= j[2:0];
              idx = idx + 1;
            end
          end

          // hull lengths reset
          low_len <= 4'd0;
          up_len  <= 4'd0;

          // iterator for bubble-like angle sorting
          i_scan  <= 4'd0;
          i_build <= 4'd0;
        end

        // Perform a simple multi-cycle bubble-sort by polar angle around anchor
        S_HULL_SCAN: begin
          // one pass step per cycle over sorted
          integer n_alive;
          integer j;
          n_alive = 0;
          for (j = 0; j < 8; j = j + 1) begin
            if (pts_alive[sorted[j]]) n_alive = n_alive + 1;
          end

          if (n_alive <= 2) begin
            // trivial hull
            hull[0]   <= sorted[0];
            if (n_alive == 2)
              hull[1] <= sorted[1];
            hull_len <= n_alive[3:0];
          end else begin
            if (i_scan < n_alive-1) begin
              reg [2:0] a_idx0, a_idx1;
              reg signed [31:0] c;
              a_idx0 = sorted[i_scan];
              a_idx1 = sorted[i_scan+1];
              c = cross_anchor(anchor_idx, a_idx0, a_idx1);
              // if angle(a0) > angle(a1), swap (sort by increasing angle)
              if (c < 0) begin
                sorted[i_scan]   <= a_idx1;
                sorted[i_scan+1] <= a_idx0;
              end
              i_scan <= i_scan + 1;
            end else begin
              i_scan <= 0;
            end
          end
        end

        // Build lower hull using sorted[]
        S_HULL_LOW: begin
          integer n_alive;
          integer j;
          n_alive = 0;
          for (j = 0; j < 8; j = j + 1) begin
            if (pts_alive[sorted[j]]) n_alive = n_alive + 1;
          end

          if (n_alive <= 2) begin
            // trivial, already set in S_HULL_SCAN exit path
          end else begin
            if (i_build < n_alive) begin
              reg [2:0] p;
              p = sorted[i_build];

              if (low_len < 2) begin
                low[low_len] <= p;
                low_len      <= low_len + 1;
              end else begin
                reg signed [31:0] c;
                reg [2:0] p1, p2;
                p1 = low[low_len-2];
                p2 = low[low_len-1];
                c = cross(pts_x[p1], pts_y[p1],
                          pts_x[p2], pts_y[p2],
                          pts_x[p],  pts_y[p]);
                if (c <= 0) begin
                  // pop last
                  low_len <= low_len - 1;
                end else begin
                  low[low_len] <= p;
                  low_len      <= low_len + 1;
                  i_build      <= i_build + 1;
                end
              end
            end
          end
        end

        // initialize upper hull pass
        S_HULL_UP_INIT: begin
          i_build <= 0;
          up_len  <= 0;
        end

        // Build upper hull from reversed sorted[]
        S_HULL_UP: begin
          integer n_alive;
          integer j;
          n_alive = 0;
          for (j = 0; j < 8; j = j + 1) begin
            if (pts_alive[sorted[j]]) n_alive = n_alive + 1;
          end

          if (n_alive > 2) begin
            if (i_build < n_alive) begin
              reg [2:0] p;
              p = sorted[n_alive-1 - i_build];

              if (up_len < 2) begin
                up[up_len] <= p;
                up_len     <= up_len + 1;
              end else begin
                reg signed [31:0] c;
                reg [2:0] p1, p2;
                p1 = up[up_len-2];
                p2 = up[up_len-1];
                c = cross(pts_x[p1], pts_y[p1],
                          pts_x[p2], pts_y[p2],
                          pts_x[p],  pts_y[p]);
                if (c <= 0) begin
                  up_len <= up_len - 1;
                end else begin
                  up[up_len] <= p;
                  up_len     <= up_len + 1;
                  i_build    <= i_build + 1;
                end
              end
            end else begin
              // combine low and up (exclude duplicate endpoints)
              integer idx, h;
              h = 0;
              // copy lower
              for (idx = 0; idx < low_len; idx = idx + 1) begin
                hull[h] <= low[idx];
                h = h + 1;
              end
              // copy upper excluding first and last (they are same as ends of low)
              for (idx = 1; idx < up_len-1; idx = idx + 1) begin
                hull[h] <= up[idx];
                h = h + 1;
              end
              hull_len <= h[3:0];
            end
          end else begin
            // trivial
          end
        end

        // Initialize area computation (shoelace, scaled by 10)
        S_AREA_INIT: begin
          i_area <= 0;
          area   <= 36'd0;
        end

        // Accumulate shoelace sum
        S_AREA_ACC: begin
          if (hull_len == 0) begin
            area <= 36'd0;
          end else if (hull_len == 1) begin
            area <= 36'd0;
          end else if (hull_len == 2) begin
            area <= 36'd0;
          end else begin
            // one term per cycle
            reg [2:0] idx0, idx1;
            reg signed [31:0] term;
            idx0 = hull[i_area];
            if (i_area == hull_len-1)
              idx1 = hull[0];
            else
              idx1 = hull[i_area+1];

            term = $signed(pts_x[idx0]) * $signed(pts_y[idx1]) -
                   $signed(pts_y[idx0]) * $signed(pts_x[idx1]);

            area <= area + {{4{term[31]}}, term};

            if (i_area < hull_len-1)
              i_area <= i_area + 1;
          end
        end

        // Output computed area (abs(sum)/2 * 10)
        S_OUTPUT: begin
          reg signed [35:0] s;
          reg [35:0] abs_s;
          s = area;
          if (s[35]) abs_s = -s; else abs_s = s;
          // area = abs_s * 10 / 2 = abs_s * 5
          area  <= abs_s * 5;
          valid <= 1'b1;

          if (step_idx == 3'd5)
            done <= 1'b1;

          if (step_idx < 3'd5)
            step_idx <= step_idx + 1;
        end

        S_DONE: begin
          // hold done high; wait for next start to reset
        end

        default: begin
        end
      endcase
    end
  end

  // next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_REMOVE; // after load in seq logic
      end

      S_REMOVE: begin
        next_state = S_HULL_INIT;
      end

      S_HULL_INIT: begin
        next_state = S_HULL_SCAN;
      end

      S_HULL_SCAN: begin
        // after enough passes, move to build
        next_state = S_HULL_LOW;
      end

      S_HULL_LOW: begin
        next_state = S_HULL_UP_INIT;
      end

      S_HULL_UP_INIT: begin
        next_state = S_HULL_UP;
      end

      S_HULL_UP: begin
        next_state = S_AREA_INIT;
      end

      S_AREA_INIT: begin
        next_state = S_AREA_ACC;
      end

      S_AREA_ACC: begin
        next_state = S_OUTPUT;
      end

      S_OUTPUT: begin
        if (step_idx == 3'd5)
          next_state = S_DONE;
        else
          next_state = S_REMOVE;
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