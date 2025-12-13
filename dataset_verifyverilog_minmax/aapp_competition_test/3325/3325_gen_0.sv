module water_height_calculator (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] N_vertices,
  input  [15:0] D_depth,
  input  [15:0] L_liters,
  input  signed [11:0] vertices [0:7][0:1],
  output reg [15:0] height,
  output reg done
);

  typedef enum logic [1:0] { IDLE=2'd0, PRECALC=2'd1, BSEARCH=2'd2, DONE=2'd3 } state_t;
  state_t state, next_state;

  // Fixed-point Q16.16 scale
  localparam QSHIFT = 16;
  // Internal signals
  reg [15:0] lo, hi, mid;             // binary search bounds in Q16.16
  reg [3:0] iter;                      // iteration counter (0..15)
  reg [31:0] area_sum;                 // accumulator for polygon area (Q32.32 intermediate)
  reg [15:0] y_min, y_max;             // min/max y (Q16.16)
  reg signed [15:0] y_sorted [0:7];    // y sorted in ascending order (Q16.16)
  reg signed [11:0] xs_sorted [0:7];   // x corresponding to y_sorted (signed 12-bit)
  reg [2:0] i_prev, i_next, j_prev, j_next; // index pointers into sorted arrays
  reg [3:0] vcount;                    // N_vertices (0..8)
  reg clip_first_cycle;                // first cycle of clipping
  reg [31:0] full_area;                // full polygon area (Q16.16)
  reg [15:0] target_h;                 // h s.t. area(h) = L/D (Q16.16)
  reg [15:0] lo_reg, hi_reg;           // copy of lo/hi for updating at end of search
  reg [31:0] min_y_q16, max_y_q16;     // Q16.16 min/max y

  // Helper: clamp 12-bit signed to 16-bit Q16.16
  function [15:0] to_q16_16;
    input signed [11:0] x12;
    begin
      to_q16_16 = {x12[11], x12[11], x12[11], x12[11], x12[11:0]}; // sign-extend to 16-bit, then to Q16.16 (shift 0)
    end
  endfunction

  // State update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state; // default
    case (state)
      IDLE: begin
        if (start) next_state = PRECALC;
      end
      PRECALC: begin
        next_state = BSEARCH;
      end
      BSEARCH: begin
        if (iter == 4'd15) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // FSM outputs and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      height      <= 16'd0;
      done        <= 1'b0;
      lo          <= 16'd0;
      hi          <= 16'd0;
      mid         <= 16'd0;
      iter        <= 4'd0;
      y_min       <= 16'd0;
      y_max       <= 16'd0;
      area_sum    <= 32'd0;
      clip_first_cycle <= 1'b0;
      i_prev      <= 3'd0;
      i_next      <= 3'd0;
      j_prev      <= 3'd0;
      j_next      <= 3'd0;
      vcount      <= 4'd0;
      full_area   <= 32'd0;
      target_h    <= 16'd0;
      lo_reg      <= 16'd0;
      hi_reg      <= 16'd0;
      min_y_q16   <= 32'd0;
      max_y_q16   <= 32'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          height <= 16'd0;
          if (start) begin
            vcount <= (N_vertices > 4'd8) ? 4'd8 : N_vertices; // clamp to 8
          end
        end
        PRECALC: begin
          // Gather ymin/ymax and compute full polygon area using sorted y/x
          // Sort y ascending (simple selection) and keep paired x
          begin
            // Bubble-like selection sort for up to 8 entries
            reg signed [15:0] tmp_y [0:7];
            reg signed [11:0] tmp_x [0:7];
            reg [3:0] n;
            n = vcount;
            for (int k = 0; k < 8; k++) begin
              if (k < n) begin
                tmp_y[k] = to_q16_16(vertices[k][1]);
                tmp_x[k] = vertices[k][0];
              end else begin
                tmp_y[k] = 16'sh8000; // very small sentinel
                tmp_x[k] = 12'sh000;
              end
            end
            // selection sort
            for (int i = 0; i < 8; i++) begin
              integer min_i;
              min_i = i;
              for (int j = i+1; j < 8; j++) begin
                if (tmp_y[j] < tmp_y[min_i]) min_i = j;
              end
              if (min_i != i) begin
                // swap
                integer t;
                t = tmp_y[i]; tmp_y[i] = tmp_y[min_i]; tmp_y[min_i] = t;
                t = tmp_x[i]; tmp_x[i] = tmp_x[min_i]; tmp_x[min_i] = t;
              end
            end
            // Pack into y_sorted, xs_sorted, and compute y_min, y_max
            min_y_q16 = 32'h7fffffff; // large
            max_y_q16 = 32'h80000000; // small
            for (int k = 0; k < 8; k++) begin
              if (k < n) begin
                y_sorted[k]   <= tmp_y[k];
                xs_sorted[k]  <= tmp_x[k];
                // update min/max
                if (tmp_y[k] < $signed(min_y_q16)) min_y_q16 <= tmp_y[k];
                if (tmp_y[k] > $signed(max_y_q16)) max_y_q16 <= tmp_y[k];
              end else begin
                y_sorted[k]   <= 16'sh8000; // sentinel (very low)
                xs_sorted[k]  <= 12'h000;
              end
            end
          end
          // Compute total area of the convex polygon (Q16.16)
          // area = 0.5 * sum over edges (x_i*y_{i+1} - x_{i+1}*y_i), using sorted y with wrap
          area_sum  <= 32'd0;
          begin
            reg signed [31:0] acc;
            reg [2:0] nxt;
            acc = 32'sd0;
            for (int i = 0; i < 8; i++) begin
              if (i < vcount) begin
                nxt = (i + 1) & 3'd7;
                // If next is not part of polygon, treat y as same as i (to avoid garbage), but since i< vcount and nxt may be out-of-range, we handle last edge specially
                if (nxt < vcount) begin
                  acc = acc + ($signed(xs_sorted[i]) * $signed(y_sorted[nxt]));
                  acc = acc - ($signed(xs_sorted[nxt]) * $signed(y_sorted[i]));
                end else begin
                  // If the next index is out of range, connect last valid to first valid
                  if (i == vcount - 1) begin
                    nxt = 3'd0;
                    acc = acc + ($signed(xs_sorted[i]) * $signed(y_sorted[nxt]));
                    acc = acc - ($signed(xs_sorted[nxt]) * $signed(y_sorted[i]));
                  end
                  // else, nothing (shouldn't happen for convex sorted sequence)
                end
              end
            end
            // acc may be negative; area is absolute 0.5 * |acc|
            acc = acc >>> 1; // acc/2
            if (acc < 0) acc = -acc;
            full_area <= acc; // Q16.16
          end
          // Initialize binary search bounds using min/max Y in Q16.16
          y_min     <= min_y_q16[15:0];
          y_max     <= max_y_q16[15:0];
          lo        <= min_y_q16[15:0];
          hi        <= max_y_q16[15:0];
          iter      <= 4'd0;
          // Clipping initialization markers
          clip_first_cycle <= 1'b1;
          // For Sutherland–Hodgman clipping (horizontal line y = h) we will run 1 cycle per iteration.
          // Prepare first pair: prev and next in circular order (wrapping in sorted array length vcount)
          i_prev    <= 3'd0;
          i_next    <= 3'd1 & 3'd7;
          j_prev    <= 3'd0;
          j_next    <= 3'd1 & 3'd7;
          // Prepare target height if L/D is achievable; store in target_h
          begin
            // target_h_raw = L * 2^16 / D  (avoid division by zero)
            reg [47:0] prod;
            reg [15:0] th;
            prod = {L_liters, 16'd0};
            if (D_depth == 16'd0) th = 16'd0; // undefined; set 0 by default
            else th = prod / D_depth; // Q16.16
            target_h <= th;
          end
        end
        BSEARCH: begin
          // One iteration per cycle
          // mid = (lo + hi) >> 1
          mid <= (lo + hi) >> 1;
          // Evaluate area(mid) with Sutherland–Hodgman horizontal clipping
          // Initialize for first cycle of this iteration
          if (clip_first_cycle) begin
            // Start from the sorted vertex list, using first two as prev/next; both for bottom and top pass
            i_prev <= 3'd0;
            i_next <= (3'd1) & 3'd7;
            j_prev <= 3'd0;
            j_next <= (3'd1) & 3'd7;
            clip_first_cycle <= 1'b0;
            // Reset area accumulator for this mid
            area_sum <= 32'd0;
          end else begin
            // Process one segment each cycle using prev/next pointers for both j and i sequences
            // bottom pass: y_prev <= mid ? add y_prev; y_next <= mid ? add (x_next, y_next);
            // top pass:    y_prev >  mid ? add y_prev; y_next >  mid ? add (x_next, y_next);
            // Convention: we add to area_sum only the term (x_curr * y_next - x_next * y_curr) in a cumulative way.
            // Here we add x_prev*y_next and subtract x_next*y_prev when both endpoints are below/above as needed.

            // Indices for bottom and top runs
            // Ensure that i_next/j_next are within [0, vcount-1]; if exceeding, wrap only within valid range.
            reg [2:0] i_np1, j_np1;
            i_np1 = (i_next + 1) & 3'd7;
            j_np1 = (j_next + 1) & 3'd7;

            // ----- bottom half (collect vertices with y <= mid) -----
            if (i_prev < vcount && i_next < vcount) begin
              reg signed [15:0] yp, yn;
              reg signed [11:0] xp, xn;
              yp = y_sorted[i_prev];
              yn = y_sorted[i_next];
              xp = xs_sorted[i_prev];
              xn = xs_sorted[i_next];
              if (yp <= $signed(mid)) begin
                // y_prev is in
                if (yn <= $signed(mid)) begin
                  // both in: add both vertices' cross terms
                  area_sum <= area_sum + ($signed(xp) * $signed(yn)) - ($signed(xn) * $signed(yp));
                end else begin
                  // prev in, next out: add prev and intersection
                  // y of intersection = mid, x = x_prev + (mid - y_prev) * (x_next - x_prev) / (y_next - y_prev)
                  // Slope = (x_next - x_prev) / (y_next - y_prev)
                  // Compute in Q16.16
                  reg signed [15:0] dy, dx_q16;
                  reg signed [31:0] x_inter_q16;
                  dy = yn - yp;
                  dx_q16 = $signed(xn - xp) << 16; // dx in Q16.16
                  if (dy != 16'd0) begin
                    x_inter_q16 = ($signed(xp) << 16) + ((($signed(mid) - yp) * dx_q16) / dy);
                  end else begin
                    x_inter_q16 = ($signed(xp) << 16);
                  end
                  // Add terms: x_prev * y_inter - x_inter * y_prev
                  area_sum <= area_sum + ($signed(xp) * $signed(mid)) - (x_inter_q16 * $signed(yp));
                end
              end else begin
                // y_prev out, y_next in: add intersection then next
                if (yn <= $signed(mid)) begin
                  // prev out, next in: add intersection and next
                  reg signed [15:0] dy, dx_q16;
                  reg signed [31:0] x_inter_q16;
                  dy = yn - yp;
                  dx_q16 = $signed(xn - xp) << 16;
                  if (dy != 16'd0) begin
                    x_inter_q16 = ($signed(xp) << 16) + ((($signed(mid) - yp) * dx_q16) / dy);
                  end else begin
                    x_inter_q16 = ($signed(xp) << 16);
                  end
                  // Add terms: x_inter * y_next - x_next * y_inter
                  area_sum <= area_sum + (x_inter_q16 * $signed(yn)) - ($signed(xn) * $signed(mid));
                end
                // else both out: nothing
              end
            end

            // ----- top half (collect vertices with y > mid) -----
            if (j_prev < vcount && j_next < vcount) begin
              reg signed [15:0] yp, yn;
              reg signed [11:0] xp, xn;
              yp = y_sorted[j_prev];
              yn = y_sorted[j_next];
              xp = xs_sorted[j_prev];
              xn = xs_sorted[j_next];
              if (yp > $signed(mid)) begin
                // y_prev is in
                if (yn > $signed(mid)) begin
                  // both in: add both vertices' cross terms
                  area_sum <= area_sum + ($signed(xp) * $signed(yn)) - ($signed(xn) * $signed(yp));
                end else begin
                  // prev in, next out: add prev and intersection
                  reg signed [15:0] dy, dx_q16;
                  reg signed [31:0] x_inter_q16;
                  dy = yn - yp;
                  dx_q16 = $signed(xn - xp) << 16;
                  if (dy != 16'd0) begin
                    x_inter_q16 = ($signed(xp) << 16) + ((($signed(mid) - yp) * dx_q16) / dy);
                  end else begin
                    x_inter_q16 = ($signed(xp) << 16);
                  end
                  area_sum <= area_sum + ($signed(xp) * $signed(mid)) - (x_inter_q16 * $signed(yp));
                end
              end else begin
                // y_prev out, y_next in: add intersection then next
                if (yn > $signed(mid)) begin
                  reg signed [15:0] dy, dx_q16;
                  reg signed [31:0] x_inter_q16;
                  dy = yn - yp;
                  dx_q16 = $signed(xn - xp) << 16;
                  if (dy != 16'd0) begin
                    x_inter_q16 = ($signed(xp) << 16) + ((($signed(mid) - yp) * dx_q16) / dy);
                  end else begin
                    x_inter_q16 = ($signed(xp) << 16);
                  end
                  area_sum <= area_sum + (x_inter_q16 * $signed(yn)) - ($signed(xn) * $signed(mid));
                end
                // else both out: nothing
              end
            end

            // Advance pointers; wrap within [0..vcount-1]
            i_prev <= i_next;
            i_next <= (i_np1 >= vcount) ? 3'd0 : i_np1;
            j_prev <= j_next;
            j_next <= (j_np1 >= vcount) ? 3'd0 : j_np1;
          end

          // If this is the last segment for this mid (i_prev just wrapped to start and we are back to first pair),
          // finalize the area for this mid and decide the next bounds.
          // Simpler: after processing 8 steps per mid, finalize.
          // To do that, we check if i_next == 0 after update, meaning one full cycle of sorted vertices was done.
          if ((i_next == 3'd0) && !clip_first_cycle) begin
            // area(mid) = 0.5 * |area_sum| (area_sum is Q32.32; halve, then keep as Q16.16)
            reg signed [31:0] a;
            a = area_sum >>> 1; // divide by 2
            if (a < 0) a = -a;
            // Now a is area(mid) in Q16.16
            // Update lo/hi
            if (a < $signed(L_liters)) begin
              lo <= mid;
            end else begin
              hi <= mid;
            end
            // Update iteration counter
            iter <= iter + 4'd1;
            // Mark next cycle as first for the new mid
            clip_first_cycle <= 1'b1;
          end
        end
        DONE: begin
          // Done asserted for exactly 1 cycle
          done <= 1'b1;
          // Return lower bound as the result after 16 iterations
          height <= lo;
        end
        default: ;
      endcase
    end
  end

endmodule
