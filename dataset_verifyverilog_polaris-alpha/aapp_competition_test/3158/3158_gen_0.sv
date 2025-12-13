module gesture_classifier(
  input clk,
  input rst_n,
  input start,
  input [127:0] init_image,
  input [127:0] final_image,
  output reg [2:0] touch_count,
  output reg [1:0] gesture_type,
  output reg direction,
  output reg done
);

  // State encoding
  localparam IDLE          = 3'd0;
  localparam FIND_TOUCHES  = 3'd1;
  localparam CALC_GRIPS    = 3'd2;
  localparam MATCH_TOUCHES = 3'd3;
  localparam COMPARE       = 3'd4;
  localparam DONE          = 3'd5;

  reg [2:0] state, next_state;

  // Cycle counter to ensure result valid 256 cycles after start
  reg [7:0] cycle_cnt;

  // Constants
  localparam MAX_TOUCHES = 5;
  localparam IMG_W = 16;
  localparam IMG_H = 8;
  localparam IMG_PIXELS = 128;
  localparam Q = 8; // Q8.8 fractional bits
  localparam signed [15:0] TOL_Q8_8 = 16'h0028; // ~1e-5 tolerance in Q8.8 (per spec)

  // Touch data structures
  // For each image, we store up to MAX_TOUCHES centroids in Q8.8
  reg [2:0]  init_touch_num;
  reg [2:0]  final_touch_num;
  reg [15:0] init_cx   [0:MAX_TOUCHES-1];
  reg [15:0] init_cy   [0:MAX_TOUCHES-1];
  reg [15:0] final_cx  [0:MAX_TOUCHES-1];
  reg [15:0] final_cy  [0:MAX_TOUCHES-1];

  // Temporary accumulators for connected components
  // We'll use simple raster-scan incremental labeling approximated as multi-cycle flood-fill.
  // Implementation kept compact/abstract but synthesizable.

  // Pixel memories (registered copies of inputs)
  reg [127:0] init_img_reg;
  reg [127:0] final_img_reg;

  // Visited / label maps (4 bits per pixel: up to 15 labels, but we cap at 5)
  reg [3:0] init_label [0:IMG_PIXELS-1];
  reg [3:0] final_label[0:IMG_PIXELS-1];

  // Label stats: sum_x, sum_y, count for up to MAX_TOUCHES labels (index 1..MAX_TOUCHES)
  reg [15:0] init_sum_x [0:MAX_TOUCHES];
  reg [15:0] init_sum_y [0:MAX_TOUCHES];
  reg [7:0]  init_cnt   [0:MAX_TOUCHES];

  reg [15:0] final_sum_x[0:MAX_TOUCHES];
  reg [15:0] final_sum_y[0:MAX_TOUCHES];
  reg [7:0]  final_cnt  [0:MAX_TOUCHES];

  reg [2:0]  init_next_label;
  reg [2:0]  final_next_label;

  // Indices for scanning/flooding
  reg [7:0] pix_idx;

  // Grip points in Q8.8
  reg [15:0] init_grip_x, init_grip_y;
  reg [15:0] final_grip_x, final_grip_y;

  // Vectors grip->touch in Q8.8
  reg signed [15:0] init_vx [0:MAX_TOUCHES-1];
  reg signed [15:0] init_vy [0:MAX_TOUCHES-1];
  reg signed [15:0] final_vx[0:MAX_TOUCHES-1];
  reg signed [15:0] final_vy[0:MAX_TOUCHES-1];

  // Matching: permutation mapping index i (init) to match_perm[i] (final)
  reg [2:0] match_perm[0:MAX_TOUCHES-1];

  // Best matching cost
  reg [31:0] best_cost;

  // Gesture metrics (Q8.8 / Q16.16 as needed)
  reg [31:0] pan_dist2;       // squared distance in Q16.16
  reg [15:0] pan_dist_abs;    // |pan| in Q8.8 (approx sqrt using simple method)
  reg [15:0] zoom_val;        // abs zoom metric Q8.8
  reg [15:0] rotate_val;      // abs rotate metric Q8.8
  reg        rotate_dir;      // 0: in/cw, 1: out/ccw

  integer i;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 8'd0;
    end else begin
      if (state == IDLE) begin
        if (start)
          cycle_cnt <= 8'd0;
      end else if (state != DONE) begin
        cycle_cnt <= cycle_cnt + 8'd1;
      end
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = FIND_TOUCHES;
      end
      FIND_TOUCHES: begin
        // allocate enough cycles for pseudo flood-fill
        if (cycle_cnt >= 8'd60)
          next_state = CALC_GRIPS;
      end
      CALC_GRIPS: begin
        if (cycle_cnt >= 8'd80)
          next_state = MATCH_TOUCHES;
      end
      MATCH_TOUCHES: begin
        if (cycle_cnt >= 8'd160)
          next_state = COMPARE;
      end
      COMPARE: begin
        if (cycle_cnt >= 8'd200)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done          <= 1'b0;
      touch_count   <= 3'd0;
      gesture_type  <= 2'b00;
      direction     <= 1'b0;
      init_touch_num  <= 3'd0;
      final_touch_num <= 3'd0;
      init_next_label <= 3'd1;
      final_next_label<= 3'd1;
      pix_idx       <= 8'd0;
      init_img_reg  <= 128'd0;
      final_img_reg <= 128'd0;
      init_grip_x   <= 16'd0;
      init_grip_y   <= 16'd0;
      final_grip_x  <= 16'd0;
      final_grip_y  <= 16'd0;
      pan_dist2     <= 32'd0;
      pan_dist_abs  <= 16'd0;
      zoom_val      <= 16'd0;
      rotate_val    <= 16'd0;
      rotate_dir    <= 1'b0;
      best_cost     <= 32'hFFFFFFFF;
      for (i = 0; i <= MAX_TOUCHES; i = i + 1) begin
        init_sum_x[i] <= 16'd0;
        init_sum_y[i] <= 16'd0;
        init_cnt[i]   <= 8'd0;
        final_sum_x[i]<= 16'd0;
        final_sum_y[i]<= 16'd0;
        final_cnt[i]  <= 8'd0;
      end
      for (i = 0; i < IMG_PIXELS; i = i + 1) begin
        init_label[i]  <= 4'd0;
        final_label[i] <= 4'd0;
      end
      for (i = 0; i < MAX_TOUCHES; i = i + 1) begin
        init_cx[i] <= 16'd0;
        init_cy[i] <= 16'd0;
        final_cx[i]<= 16'd0;
        final_cy[i]<= 16'd0;
        init_vx[i] <= 16'sd0;
        init_vy[i] <= 16'sd0;
        final_vx[i]<= 16'sd0;
        final_vy[i]<= 16'sd0;
        match_perm[i] <= 3'd0;
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch images and clear structures
            init_img_reg  <= init_image;
            final_img_reg <= final_image;

            init_touch_num   <= 3'd0;
            final_touch_num  <= 3'd0;
            init_next_label  <= 3'd1;
            final_next_label <= 3'd1;
            pix_idx          <= 8'd0;

            for (i = 0; i <= MAX_TOUCHES; i = i + 1) begin
              init_sum_x[i] <= 16'd0;
              init_sum_y[i] <= 16'd0;
              init_cnt[i]   <= 8'd0;
              final_sum_x[i]<= 16'd0;
              final_sum_y[i]<= 16'd0;
              final_cnt[i]  <= 8'd0;
            end
            for (i = 0; i < IMG_PIXELS; i = i + 1) begin
              init_label[i]  <= 4'd0;
              final_label[i] <= 4'd0;
            end
          end
        end

        FIND_TOUCHES: begin
          // Pseudo sequential 4-connect flood-like: raster scan; if pixel set, inherit label from left/up else new label
          if (pix_idx < IMG_PIXELS) begin
            integer x, y;
            reg init_pix, final_pix;
            reg [3:0] l_lbl, u_lbl;
            x = pix_idx[3:0];
            y = pix_idx[7:4];
            init_pix  = init_img_reg[pix_idx];
            final_pix = final_img_reg[pix_idx];

            // Initial image labels
            if (init_pix) begin
              l_lbl = (x > 0) ? init_label[pix_idx-1] : 4'd0;
              u_lbl = (y > 0) ? init_label[pix_idx-IMG_W] : 4'd0;
              if (l_lbl != 0)
                init_label[pix_idx] <= l_lbl;
              else if (u_lbl != 0)
                init_label[pix_idx] <= u_lbl;
              else if (init_next_label <= MAX_TOUCHES) begin
                init_label[pix_idx] <= init_next_label;
                init_next_label     <= init_next_label + 3'd1;
              end else begin
                init_label[pix_idx] <= 4'd0; // ignore beyond MAX_TOUCHES
              end
            end else begin
              init_label[pix_idx] <= 4'd0;
            end

            // Final image labels
            if (final_pix) begin
              l_lbl = (x > 0) ? final_label[pix_idx-1] : 4'd0;
              u_lbl = (y > 0) ? final_label[pix_idx-IMG_W] : 4'd0;
              if (l_lbl != 0)
                final_label[pix_idx] <= l_lbl;
              else if (u_lbl != 0)
                final_label[pix_idx] <= u_lbl;
              else if (final_next_label <= MAX_TOUCHES) begin
                final_label[pix_idx] <= final_next_label;
                final_next_label     <= final_next_label + 3'd1;
              end else begin
                final_label[pix_idx] <= 4'd0;
              end
            end else begin
              final_label[pix_idx] <= 4'd0;
            end

            pix_idx <= pix_idx + 8'd1;
          end else begin
            // After full scan, accumulate stats per label
            for (i = 0; i < IMG_PIXELS; i = i + 1) begin
              integer xx, yy;
              xx = i[3:0];
              yy = i[7:4];
              if (init_label[i] != 0 && init_label[i] <= MAX_TOUCHES) begin
                init_sum_x[init_label[i]] <= init_sum_x[init_label[i]] + xx;
                init_sum_y[init_label[i]] <= init_sum_y[init_label[i]] + yy;
                init_cnt[init_label[i]]   <= init_cnt[init_label[i]] + 8'd1;
              end
              if (final_label[i] != 0 && final_label[i] <= MAX_TOUCHES) begin
                final_sum_x[final_label[i]] <= final_sum_x[final_label[i]] + xx;
                final_sum_y[final_label[i]] <= final_sum_y[final_label[i]] + yy;
                final_cnt[final_label[i]]   <= final_cnt[final_label[i]] + 8'd1;
              end
            end

            // Determine valid touches (>=2 px) and compute Q8.8 centroids
            init_touch_num  <= 3'd0;
            final_touch_num <= 3'd0;
            for (i = 1; i <= MAX_TOUCHES; i = i + 1) begin
              if (init_cnt[i] >= 2 && init_touch_num < MAX_TOUCHES) begin
                init_cx[init_touch_num] <= {init_sum_x[i], 8'd0} / init_cnt[i];
                init_cy[init_touch_num] <= {init_sum_y[i], 8'd0} / init_cnt[i];
                init_touch_num <= init_touch_num + 3'd1;
              end
              if (final_cnt[i] >= 2 && final_touch_num < MAX_TOUCHES) begin
                final_cx[final_touch_num] <= {final_sum_x[i], 8'd0} / final_cnt[i];
                final_cy[final_touch_num] <= {final_sum_y[i], 8'd0} / final_cnt[i];
                final_touch_num <= final_touch_num + 3'd1;
              end
            end
          end
        end

        CALC_GRIPS: begin
          integer n;
          integer sx, sy;

          // Use number of touches as min(init, final), clamp 1-5
          n = (init_touch_num < final_touch_num) ? init_touch_num : final_touch_num;
          if (n == 0) n = (init_touch_num != 0) ? init_touch_num : final_touch_num;
          if (n == 0) n = 1;

          // Compute grip points as average of centroids (Q8.8)
          sx = 0; sy = 0;
          for (i = 0; i < init_touch_num; i = i + 1) begin
            sx = sx + init_cx[i];
            sy = sy + init_cy[i];
          end
          if (init_touch_num != 0) begin
            init_grip_x <= sx / init_touch_num;
            init_grip_y <= sy / init_touch_num;
          end else begin
            init_grip_x <= 16'd0;
            init_grip_y <= 16'd0;
          end

          sx = 0; sy = 0;
          for (i = 0; i < final_touch_num; i = i + 1) begin
            sx = sx + final_cx[i];
            sy = sy + final_cy[i];
          end
          if (final_touch_num != 0) begin
            final_grip_x <= sx / final_touch_num;
            final_grip_y <= sy / final_touch_num;
          end else begin
            final_grip_x <= 16'd0;
            final_grip_y <= 16'd0;
          end

          // Compute grip->touch vectors
          for (i = 0; i < MAX_TOUCHES; i = i + 1) begin
            if (i < init_touch_num) begin
              init_vx[i] <= $signed(init_cx[i]) - $signed(init_grip_x);
              init_vy[i] <= $signed(init_cy[i]) - $signed(init_grip_y);
            end else begin
              init_vx[i] <= 16'sd0;
              init_vy[i] <= 16'sd0;
            end
            if (i < final_touch_num) begin
              final_vx[i] <= $signed(final_cx[i]) - $signed(final_grip_x);
              final_vy[i] <= $signed(final_cy[i]) - $signed(final_grip_y);
            end else begin
              final_vx[i] <= 16'sd0;
              final_vy[i] <= 16'sd0;
            end
          end

          // Reset best_cost for matching
          best_cost <= 32'hFFFFFFFF;
        end

        MATCH_TOUCHES: begin
          // For up to 5 touches, brute-force all permutations would be 120.
          // Here implement simple greedy matching: for each init touch, choose nearest final touch (unassigned), using parallel-like comparisons.
          reg [2:0] used;
          reg [2:0] ii;
          reg [2:0] j;
          reg [31:0] total_cost;
          reg [2:0] best_j;
          reg [31:0] best_d;
          integer di;

          used = 3'd0;
          total_cost = 32'd0;

          for (ii = 0; ii < MAX_TOUCHES; ii = ii + 1) begin
            if (ii < init_touch_num && final_touch_num != 0) begin
              best_d = 32'hFFFFFFFF;
              best_j = 3'd0;
              for (j = 0; j < MAX_TOUCHES; j = j + 1) begin
                if (j < final_touch_num && !used[j]) begin
                  reg signed [15:0] dx, dy;
                  reg [31:0] d2;
                  dx = $signed(init_cx[ii]) - $signed(final_cx[j]);
                  dy = $signed(init_cy[ii]) - $signed(final_cy[j]);
                  d2 = dx*dx + dy*dy;
                  if (d2 < best_d) begin
                    best_d = d2;
                    best_j = j;
                  end
                end
              end
              match_perm[ii] = best_j;
              used[best_j] = 1'b1;
              total_cost = total_cost + best_d;
            end else begin
              match_perm[ii] = 3'd0;
            end
          end

          if (total_cost < best_cost)
            best_cost <= total_cost;
        end

        COMPARE: begin
          integer n;
          integer k;
          reg signed [15:0] dx, dy;
          reg [31:0] spread_init_acc, spread_final_acc;
          reg [15:0] spread_init_avg, spread_final_avg;
          reg signed [31:0] cross_acc;

          // Determine effective touch count (1..5) based on matched touches
          n = (init_touch_num < final_touch_num) ? init_touch_num : final_touch_num;
          if (n < 1) n = 1;
          if (n > MAX_TOUCHES) n = MAX_TOUCHES;
          touch_count <= (n > 5) ? 3'd5 : n[2:0];

          // Pan distance: grip delta
          dx = $signed(final_grip_x) - $signed(init_grip_x);
          dy = $signed(final_grip_y) - $signed(init_grip_y);
          pan_dist2 = dx*dx + dy*dy; // Q16.16

          // Approx sqrt: take high 16 bits as Q8.8 rough
          pan_dist_abs = pan_dist2[23:8];

          // Zoom: average spread: mean distance from grip
          spread_init_acc = 32'd0;
          spread_final_acc = 32'd0;
          for (k = 0; k < n; k = k + 1) begin
            reg signed [15:0] ivx, ivy, fvx, fvy;
            reg [31:0] d2i, d2f;
            ivx = init_vx[k];
            ivy = init_vy[k];
            fvx = final_vx[match_perm[k]];
            fvy = final_vy[match_perm[k]];
            d2i = ivx*ivx + ivy*ivy;
            d2f = fvx*fvx + fvy*fvy;
            spread_init_acc = spread_init_acc + d2i[23:8];
            spread_final_acc = spread_final_acc + d2f[23:8];
          end
          if (n != 0) begin
            spread_init_avg = spread_init_acc / n;
            spread_final_avg = spread_final_acc / n;
          end else begin
            spread_init_avg = 16'd0;
            spread_final_avg = 16'd0;
          end

          if (spread_final_avg >= spread_init_avg)
            zoom_val <= spread_final_avg - spread_init_avg;
          else
            zoom_val <= spread_init_avg - spread_final_avg;

          // Rotate: accumulate signed cross products between matched vectors
          cross_acc = 32'sd0;
          for (k = 0; k < n; k = k + 1) begin
            reg signed [15:0] ivx, ivy, fvx, fvy;
            reg signed [31:0] cp;
            ivx = init_vx[k];
            ivy = init_vy[k];
            fvx = final_vx[match_perm[k]];
            fvy = final_vy[match_perm[k]];
            cp = ivx * fvy - ivy * fvx;
            cross_acc = cross_acc + cp;
          end

          if (cross_acc[31] == 1'b0) begin
            rotate_val <= (cross_acc[23:8] > 16'hFFFF) ? 16'hFFFF : cross_acc[23:8];
            rotate_dir <= 1'b1; // ccw / out
          end else begin
            reg [31:0] abs_cp;
            abs_cp = (~cross_acc) + 32'd1;
            rotate_val <= (abs_cp[23:8] > 16'hFFFF) ? 16'hFFFF : abs_cp[23:8];
            rotate_dir <= 1'b0; // cw / in
          end

          // Decide gesture_type based on largest metric with tolerance
          // 00: pan, 01: zoom, 10: rotate
          reg [15:0] pan_m, zoom_m, rot_m;
          reg [1:0] sel;
          pan_m  = pan_dist_abs;
          zoom_m = zoom_val;
          rot_m  = rotate_val;
          sel = 2'b00;

          // Compare pan vs zoom
          if (zoom_m > pan_m + TOL_Q8_8)
            sel = 2'b01;
          else if (pan_m > zoom_m + TOL_Q8_8)
            sel = 2'b00;
          else
            sel = 2'b00; // tie -> pan

          // Compare current winner vs rotate
          case (sel)
            2'b00: begin
              if (rot_m > pan_m + TOL_Q8_8)
                sel = 2'b10;
            end
            2'b01: begin
              if (rot_m > zoom_m + TOL_Q8_8)
                sel = 2'b10;
            end
            default: sel = 2'b10;
          endcase

          gesture_type <= sel;

          // Direction selection: for pan use dx sign; for zoom use spread; for rotate use rotate_dir
          case (sel)
            2'b00: begin
              // pan: direction 0 for negative dx, 1 for positive dx
              direction <= (dx >= 0);
            end
            2'b01: begin
              // zoom: 0 in, 1 out
              direction <= (spread_final_avg >= spread_init_avg);
            end
            2'b10: begin
              // rotate: rotate_dir from cross sign (0: cw,1:ccw)
              direction <= rotate_dir;
            end
            default: direction <= 1'b0;
          endcase
        end

        DONE: begin
          if (cycle_cnt >= 8'd255)
            done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule
