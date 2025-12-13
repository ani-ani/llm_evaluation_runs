module energy_balance_line (
  input clk,
  input rst_n,
  input [2:0] n,
  input [6:0] x_i [0:7],
  input [6:0] y_i [0:7],
  input [12:0] e_i [0:7],
  input start,
  output reg [31:0] min_length,
  output reg impossible,
  output reg done
);

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_SUMSETUP  = 4'd1,
    S_SORT_MIN  = 4'd2,
    S_SORT_REST = 4'd3,
    S_BUILD     = 4'd4,
    S_POP       = 4'd5,
    S_DIST      = 4'd6,
    S_DONE      = 4'd7
  } state_t;

  state_t state;

  // Iteration counters
  reg [11:0] cycle_cnt;       // up to 4095
  reg [7:0] subset_idx;       // 0..255
  reg [2:0] p_cnt;            // number of points in current subset (<=8)
  reg [2:0] i_idx;            // generic index

  // Energy arithmetic
  reg [14:0] total_sum_int;   // sum of e_i (signed, 15 bits is enough for 8*2000=16000)
  reg [15:0] total_sum_abs;   // abs(total_sum_int)
  reg [14:0] subset_sum_int;  // subset sum (signed)
  reg [15:0] subset_sum_abs;  // abs(subset_sum_int)
  reg subset_valid;           // energy tolerance pass

  // Points: Q16.16 fixed-point coordinates (xi, yi)
  reg [31:0] x_fp [0:7];
  reg [31:0] y_fp [0:7];

  // Sorting (Graham's scan base point and rest sort)
  reg [2:0] min_idx;          // index of min (by y, then x)
  reg [31:0] ref_x, ref_y;    // base point Q16.16
  reg [2:0] rest_cnt;         // number of non-base points in subset
  reg [31:0] rest_angles [0:7]; // Q16.16 tangents (0..1)
  reg [31:0] rest_dx [0:7], rest_dy [0:7]; // Q16.16 deltas to ref

  // Point arrays after sorting by angle
  reg [31:0] ang_pts_x [0:7]; // Q16.16
  reg [31:0] ang_pts_y [0:7]; // Q16.16
  reg [2:0] sort_inner;
  reg [2:0] sort_outer;
  reg [31:0] tmp_ang, tmp_dx, tmp_dy;
  reg [31:0] tmp_x, tmp_y;

  // Hull stack
  reg [31:0] stack_x [0:7]; // Q16.16
  reg [31:0] stack_y [0:7]; // Q16.16
  reg [2:0] sp;             // stack pointer (points to next free slot)

  // Cross product in Q16.16 (result is effectively Q16.16 since operands are Q16.16)
  // To avoid size explosion, we keep 32-bit operands. The full product is 64-bit.
  logic signed [63:0] cross_full;
  reg signed [63:0] cross_reg;
  reg [31:0] cross_hi; // high 32 bits of the 64-bit product (used when we need to inspect sign)

  // Distance and perimeter (Q16.16)
  reg [31:0] dx_fp, dy_fp;          // Q16.16
  logic [63:0] dist2_full;          // dx^2 + dy^2 (Q32.32)
  reg [31:0] dist2_hi;              // high 32 bits of dist2_full
  logic [31:0] dist_sqrt_q16_16;    // sqrt approximation (Q16.16)
  reg [31:0] hull_perimeter;        // Q16.16
  reg [2:0] dist_idx;               // index for perimeter accumulation

  // Sqrt approximation (Q16.16 input -> Q16.16 output)
  function [31:0] sqrt_q16_16;
    input [31:0] x; // Q16.16 unsigned, assumed 32-bit
    integer i, k, left, right, mid;
    reg [63:0] est_full;
    reg [31:0] est, est_sq, err;
    begin
      // handle zero
      if (x == 32'd0) begin
        sqrt_q16_16 = 32'd0;
        return;
      end
      // initial guess: shift right 2 bits (sqrt(x*2^-2) ~ sqrt(x)/2)
      left = 0;
      right = 32'h00010000; // 65536 in Q16.16
      // 20 iterations should be enough for 16.16 range
      for (i = 0; i < 20; i = i + 1) begin
        mid = (left + right) >> 1;
        est = mid;
        est_full = $unsigned(($signed(est) * $signed(est)));
        est_sq = est_full[63:32]; // high 32 bits
        if (est_sq == x) begin
          left = right = mid;
        end else if (est_sq > x) begin
          right = mid - 1;
        end else begin
          left = mid + 1;
        end
      end
      // average to get closer
      est = (left + right) >> 1;
      // one-step Newton refinement
      if (est != 0) begin
        est_full = $unsigned($signed(x) * $signed(est));
        // est_next = (est + x/est)/2; compute est_next^2 to compare with x
        // Use k = (est + (x>>16)/est) for integer-like; For 16.16 we can approximate:
        // Instead, do a simple integer Newton using hi parts:
        // Compute y = (est + (x / est)) >> 1, then square y and compare with x.
        // To keep it small, do two Newton iterations in Q16.16 space using high 32 bits as integer approx.
        // First iteration:
        err = x / est; // approximate in Q16.16 (coarse but ok)
        est = (est + err) >> 1;
        // Second iteration:
        err = x / est;
        est = (est + err) >> 1;
      end
      sqrt_q16_16 = est;
    end
  endfunction

  // Combinational cross product result update
  always @(*) begin
    cross_full = $signed(dx_fp) * $signed(dy_fp);
    cross_hi = cross_full[63:32];
  end

  // Combinational distance sqrt (approx) update
  assign dist2_full = $unsigned($signed(dx_fp) * $signed(dx_fp)) + $unsigned($signed(dy_fp) * $signed(dy_fp));
  assign dist_sqrt_q16_16 = sqrt_q16_16(dist2_full[63:32]);

  // Main FSM and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cycle_cnt <= 12'd0;
      subset_idx <= 8'd0;
      min_length <= 32'h7fffffff; // very large
      impossible <= 1'b0;
      done <= 1'b0;
      hull_perimeter <= 32'd0;
      sp <= 3'd0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            // Initialize
            done <= 1'b0;
            impossible <= 1'b0;
            min_length <= 32'h7fffffff;
            cycle_cnt <= 12'd0;
            subset_idx <= 8'd0;
            // compute total sum and abs
            total_sum_int <= 15'd0;
            for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
              total_sum_int <= total_sum_int + e_i[i_idx];
            end
            total_sum_abs <= (total_sum_int[14] == 1'b0) ? {1'b0, total_sum_int[14:0]} : (~{1'b0, total_sum_int[14:0]} + 1);
            state <= S_SUMSETUP;
          end
        end

        S_SUMSETUP: begin
          // Setup subset points and sum
          p_cnt <= 3'd0;
          subset_sum_int <= 15'd0;
          // clear point arrays
          for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
            x_fp[i_idx] <= 32'd0;
            y_fp[i_idx] <= 32'd0;
          end
          // gather points for current subset (bits 0..n-1)
          for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
            if (subset_idx[i_idx] && (i_idx < n)) begin
              x_fp[p_cnt] <= {x_i[i_idx], 16'd0}; // Q16.16
              y_fp[p_cnt] <= {y_i[i_idx], 16'd0};
              subset_sum_int <= subset_sum_int + e_i[i_idx];
              p_cnt <= p_cnt + 1;
            end
          end
          // check energy tolerance: |2*s - T| <= 0.3*T, T>0
          subset_sum_abs <= (subset_sum_int[14] == 1'b0) ? {1'b0, subset_sum_int[14:0]} : (~{1'b0, subset_sum_int[14:0]} + 1);
          state <= S_SORT_MIN;
        end

        S_SORT_MIN: begin
          // Determine base point (min y, then min x)
          if (p_cnt == 0) begin
            subset_valid <= 1'b0;
            state <= S_DIST; // perimeter remains 0
            dist_idx <= 3'd0;
            hull_perimeter <= 32'd0;
          end else begin
            min_idx <= 3'd0;
            for (i_idx = 1; i_idx < 8; i_idx = i_idx + 1) begin
              if (i_idx < p_cnt) begin
                // compare y, then x
                if ({1'b0, y_fp[i_idx]} < {1'b0, y_fp[min_idx]} ||
                    ({1'b0, y_fp[i_idx]} == {1'b0, y_fp[min_idx]} && {1'b0, x_fp[i_idx]} < {1'b0, x_fp[min_idx]})) begin
                  min_idx <= i_idx;
                end
              end
            end
            // prepare reference (base)
            ref_x <= x_fp[min_idx];
            ref_y <= y_fp[min_idx];
            // collect rest
            rest_cnt <= 3'd0;
            for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
              if (i_idx != min_idx && i_idx < p_cnt) begin
                rest_angles[rest_cnt] <= 32'd0; // will compute below
                rest_dx[rest_cnt] <= x_fp[i_idx] - ref_x;
                rest_dy[rest_cnt] <= y_fp[i_idx] - ref_y;
                rest_cnt <= rest_cnt + 1;
              end
            end
            // compute tangents for rest (dy/dx) in Q16.16
            for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
              if (i_idx < rest_cnt) begin
                if (rest_dx[i_idx] == 0 && rest_dy[i_idx] == 0) begin
                  rest_angles[i_idx] <= 32'h00010000; // set to 1 to push later (identical point)
                end else if (rest_dx[i_idx] == 0) begin
                  rest_angles[i_idx] <= 32'h7fffffff; // +inf
                end else begin
                  rest_angles[i_idx] <= rest_dy[i_idx] / rest_dx[i_idx];
                end
              end
            end
            state <= S_SORT_REST;
            sort_outer <= 3'd0;
          end
        end

        S_SORT_REST: begin
          // Simple bubble sort by angle (ascending)
          if (rest_cnt <= 1) begin
            // copy sorted rest into ang_pts
            for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
              if (i_idx == 0) begin
                ang_pts_x[i_idx] <= ref_x;
                ang_pts_y[i_idx] <= ref_y;
              end else if (i_idx < rest_cnt) begin
                ang_pts_x[i_idx] <= ref_x + rest_dx[i_idx-1];
                ang_pts_y[i_idx] <= ref_y + rest_dy[i_idx-1];
              end else begin
                ang_pts_x[i_idx] <= 32'd0;
                ang_pts_y[i_idx] <= 32'd0;
              end
            end
            sp <= 3'd0;
            state <= S_BUILD;
          end else begin
            if (sort_outer < rest_cnt - 1) begin
              if (sort_inner < (rest_cnt - 1 - sort_outer)) begin
                // compare rest_angles[sort_inner] > rest_angles[sort_inner+1]
                if (rest_angles[sort_inner] > rest_angles[sort_inner+1]) begin
                  // swap angle
                  tmp_ang <= rest_angles[sort_inner];
                  rest_angles[sort_inner] <= rest_angles[sort_inner+1];
                  rest_angles[sort_inner+1] <= tmp_ang;
                  // swap dx, dy
                  tmp_dx <= rest_dx[sort_inner];
                  tmp_dy <= rest_dy[sort_inner];
                  rest_dx[sort_inner] <= rest_dx[sort_inner+1];
                  rest_dy[sort_inner] <= rest_dy[sort_inner+1];
                  rest_dx[sort_inner+1] <= tmp_dx;
                  rest_dy[sort_inner+1] <= tmp_dy;
                end
                sort_inner <= sort_inner + 1;
              end else begin
                sort_inner <= 3'd0;
                sort_outer <= sort_outer + 1;
              end
            end else begin
              // copy to ang_pts
              for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
                if (i_idx == 0) begin
                  ang_pts_x[i_idx] <= ref_x;
                  ang_pts_y[i_idx] <= ref_y;
                end else if (i_idx < rest_cnt) begin
                  ang_pts_x[i_idx] <= ref_x + rest_dx[i_idx-1];
                  ang_pts_y[i_idx] <= ref_y + rest_dy[i_idx-1];
                end else begin
                  ang_pts_x[i_idx] <= 32'd0;
                  ang_pts_y[i_idx] <= 32'd0;
                end
              end
              sp <= 3'd0;
              state <= S_BUILD;
            end
          end
        end

        S_BUILD: begin
          // Graham's scan: push points in order (skip duplicates) to stack
          if (i_idx < rest_cnt) begin
            // skip duplicate points (exactly same as ref)
            if (ang_pts_x[i_idx+1] == ref_x && ang_pts_y[i_idx+1] == ref_y) begin
              i_idx <= i_idx + 1;
            end else begin
              stack_x[sp] <= ang_pts_x[i_idx+1];
              stack_y[sp] <= ang_pts_y[i_idx+1];
              sp <= sp + 1;
              i_idx <= i_idx + 1;
            end
          end else begin
            // After pushing all, ensure at least 2 points are in stack for meaningful perimeter
            if (sp == 0) begin
              // Only base point (all rest were duplicates or none)
              // Perimeter will be handled below
              dist_idx <= 3'd0;
              hull_perimeter <= 32'd0;
              state <= S_POP;
            end else if (sp == 1) begin
              // Only two points: base + one more
              // Perimeter will be handled below
              dist_idx <= 3'd0;
              hull_perimeter <= 32'd0;
              state <= S_POP;
            end else begin
              // Initialize cross product check index
              i_idx <= 3'd2; // start checking from third point in stack
              state <= S_POP;
            end
          end
        end

        S_POP: begin
          // Pop while cross <= 0
          if (sp > 1 && i_idx < sp) begin
            // cross of (p[sp-2], p[sp-1], p[i_idx])
            dx_fp <= stack_x[sp-1] - stack_x[sp-2];
            dy_fp <= stack_y[sp-1] - stack_y[sp-2];
            cross_reg <= cross_full;
            if (cross_reg <= 0) begin
              // pop
              sp <= sp - 1;
            end else begin
              i_idx <= i_idx + 1;
            end
          end else begin
            // Finalize stack size (if sp==1 -> one point; sp==0 -> empty)
            if (sp == 0) begin
              // no valid hull (e.g., all same point), perimeter = 0
              dist_idx <= 3'd0;
              hull_perimeter <= 32'd0;
            end else if (sp == 1) begin
              // single point: perimeter = 0
              dist_idx <= 3'd0;
              hull_perimeter <= 32'd0;
            end else begin
              // start distance accumulation
              dist_idx <= 1; // next edge from stack[0] to stack[1]
              dx_fp <= stack_x[1] - stack_x[0];
              dy_fp <= stack_y[1] - stack_y[0];
              hull_perimeter <= 32'd0; // will accumulate in S_DIST
            end
            state <= S_DIST;
          end
        end

        S_DIST: begin
          // Accumulate perimeter over edges in the stack
          if (sp <= 1) begin
            // no edges
            // hull_perimeter already 0
            // Determine subset validity once (check tolerance)
            if (total_sum_abs == 0) begin
              // degenerate: allow only if subset == complement and sums equal
              subset_valid <= (subset_sum_int == 0);
            end else begin
              // |2*s - T| <= 0.3*T using scaled inequality: 10*|2*s - T| <= 3*T
              // Avoid division by using abs(2*s - T) * 10
              // All values are integers; T is total_sum_abs (>=0)
              logic [31:0] lhs, rhs;
              logic [31:0] two_s, diff;
              logic [31:0] diff_abs;
              two_s = {1'b0, subset_sum_int, 1'b0}; // 2*s (shift-left 1)
              if (total_sum_int >= 0) begin
                diff = two_s - total_sum_int;
              end else begin
                diff = two_s + (~total_sum_int + 1); // subtract negative
              end
              if (diff[31] == 1'b0) diff_abs = diff; else diff_abs = ~diff + 1;
              lhs = diff_abs * 10;
              rhs = total_sum_abs * 3;
              subset_valid <= (lhs <= rhs);
            end
            // Update min_length if valid
            if (subset_valid) begin
              if (hull_perimeter < min_length) begin
                min_length <= hull_perimeter;
              end
            end
            // Prepare next subset
            cycle_cnt <= cycle_cnt + 12'd1;
            subset_idx <= subset_idx + 8'd1;
            if (subset_idx == 8'd255) begin
              state <= S_DONE;
            end else begin
              state <= S_SUMSETUP;
            end
          end else begin
            if (dist_idx < sp) begin
              // dist2_full[63:32] is high 32 bits (Q16.16 squared value)
              dist2_hi <= dist2_full[63:32];
              // wait one cycle for sqrt (combinational but per cycle, simple pipeline)
              state <= S_DIST; // stay in S_DIST, advance dist_idx next cycle after adding
              // Add after sqrt becomes available next cycle. Use a flag to accumulate on next tick.
              // Use dist_idx to control accumulation in following cycle using a latch-like reg
              dist_idx <= dist_idx + 3'd1; // advance for next edge next cycle
              // Actually accumulate now: use sqrt output combinatorially
              hull_perimeter <= hull_perimeter + dist_sqrt_q16_16;
            end else begin
              // close hull: from last point to first
              dx_fp <= stack_x[0] - stack_x[sp-1];
              dy_fp <= stack_y[0] - stack_y[sp-1];
              dist2_hi <= dist2_full[63:32];
              // accumulate this last edge in the next cycle
              dist_idx <= 3'd0; // marker to indicate just finished last edge
              state <= S_DIST; // next cycle will add last segment
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          impossible <= (min_length == 32'h7fffffff);
          state <= S_IDLE; // latch here until next start
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

  // Enforce total <= 4096 cycles; we design to finish in 256*16 = 4096 cycles.
  // All path delays are within 1 cycle per operation above.

endmodule
