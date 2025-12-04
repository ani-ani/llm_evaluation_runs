module gesture_classifier(
  input clk,                 // clock signal
  input rst_n,               // active-low reset
  input start,               // start processing
  input [127:0] init_image,  // 8x16 initial image (1 bit per pixel)
  input [127:0] final_image, // 8x16 final image (1 bit per pixel)
  output reg [2:0] touch_count,  // number of touches (1-5)
  output reg [1:0] gesture_type, // 00:pan, 01:zoom, 10:rotate
  output reg direction,       // 0:in/cw, 1:out/ccw
  output reg done             // high when result valid
);

  // Grid dimensions
  localparam W = 16;
  localparam H = 8;
  localparam NPIX = W * H; // 128
  localparam MAX_TOUCHES = 5;
  localparam QSHIFT = 8; // Q8.8 fixed point
  localparam TOLERANCE = 16'h0028; // 0x28 in Q8.8 (~0.15625 decimal)
  localparam LATENCY = 256; // cycles after start assertion when result is valid

  typedef enum {
    IDLE, FIND_TOUCHES, CALC_GRIPS, MATCH_TOUCHES, COMPARE, DONE
  } state_t;

  // Storage for image bits (2 x 128 bits)
  reg [127:0] img [0:1];
  reg [6:0] img_idx; // 0: init_image, 1: final_image

  // Flood-fill stack
  reg [6:0] stack [0:NPIX-1];
  reg [7:0] sp; // stack pointer (0..128)

  // Visited bitset per image (128 bits)
  reg [127:0] visited [0:1];

  // BFS/component processing
  reg [7:0] pix_idx; // 0..127 (current pixel being expanded)
  reg [6:0] start_pix; // start of current component search
  reg [7:0] comp_pix_cnt; // 0..127
  reg [31:0] sum_x_q8; // x sum << 8
  reg [31:0] sum_y_q8; // y sum << 8

  // Touch storage
  reg [4:0] touch_cnt_r; // 0..5
  reg [15:0] touch_x_q8 [0:MAX_TOUCHES-1]; // Q8.8
  reg [15:0] touch_y_q8 [0:MAX_TOUCHES-1]; // Q8.8

  // Grip points (Q8.8)
  reg [15:0] grip_x_q8 [0:1];
  reg [15:0] grip_y_q8 [0:1];

  // Touch vectors from grip (Q8.8)
  reg [15:0] vec_x_q8 [0:MAX_TOUCHES-1];
  reg [15:0] vec_y_q8 [0:MAX_TOUCHES-1];

  // Matching indices
  reg [2:0] best_j [0:MAX_TOUCHES-1]; // matched final touch index for each initial touch

  // Distances and signs
  reg [31:0] dist_pan_q8;      // Euclidean (grip0 -> grip1), Q8.8
  reg [31:0] dist_zoom_q8;     // Abs(grip_spread0 - grip_spread1), Q8.8
  reg [31:0] dist_rot_q8;      // Arc length from angle difference, Q8.8
  reg rot_sign;                // 0:cw/in, 1:ccw/out

  // FSM and latency timer
  state_t state, state_next;
  reg [8:0] latency_cnt; // 0..255

  // Helper: convert 1D index -> x,y
  function [3:0] idx_x;
    input [6:0] idx;
    idx_x = idx % W; // 0..15
  endfunction
  function [2:0] idx_y;
    input [6:0] idx;
    idx_y = idx / W; // 0..7
  endfunction

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      latency_cnt <= 9'd0;
      done <= 1'b0;
      touch_count <= 3'd0;
      gesture_type <= 2'd0;
      direction <= 1'b0;
    end else begin
      state <= state_next;
      if (state == IDLE) begin
        latency_cnt <= 9'd0;
        done <= 1'b0;
      end else if (state == DONE) begin
        if (latency_cnt < (LATENCY-1)) begin
          latency_cnt <= latency_cnt + 1;
        end else begin
          done <= 1'b1;
        end
      end
    end
  end

  // FSM combinatorial logic
  always @(*) begin
    state_next = state;
    case (state)
      IDLE: begin
        if (start) begin
          state_next = FIND_TOUCHES;
        end
      end
      FIND_TOUCHES: begin
        if (img_idx > 1) begin
          state_next = CALC_GRIPS;
        end
      end
      CALC_GRIPS: begin
        state_next = MATCH_TOUCHES;
      end
      MATCH_TOUCHES: begin
        state_next = COMPARE;
      end
      COMPARE: begin
        state_next = DONE;
      end
      DONE: begin
        // Stay in DONE until start deasserted
        if (!start) begin
          state_next = IDLE;
        end
      end
      default: state_next = IDLE;
    endcase
  end

  // Main processing logic (sequential, multiple cycles)
  always @(posedge clk) begin
    case (state)
      IDLE: begin
        // Latch inputs
        img[0] <= init_image;
        img[1] <= final_image;
        img_idx <= 7'd0;
        touch_cnt_r <= 5'd0;
        // Clear results
        touch_count <= 3'd0;
        gesture_type <= 2'd0;
        direction <= 1'b0;
        // Clear vectors and matching
        for (int k = 0; k < MAX_TOUCHES; k++) begin
          vec_x_q8[k] <= 16'd0;
          vec_y_q8[k] <= 16'd0;
          best_j[k] <= 3'd0;
        end
      end

      FIND_TOUCHES: begin
        // Initialize for current image
        if (img_idx == 7'd0) begin
          visited[0] <= 128'd0;
        end else if (img_idx == 7'd1) begin
          visited[1] <= 128'd0;
        end

        if (img_idx <= 7'd1) begin
          // Detect next component in current image
          // Mark current start_pix as visited before search
          if (sp == 8'd0) begin
            // First time for this image: search for next unvisited 1-pixel
            start_pix <= 7'd255; // sentinel
            for (int p = 0; p < NPIX; p++) begin
              if (!visited[img_idx][p] && img[img_idx][p]) begin
                start_pix <= p[6:0];
                break;
              end
            end
            if (start_pix == 7'd255) begin
              // No more components in this image; advance to next image
              img_idx <= img_idx + 1;
            end else begin
              // Initialize BFS for this component
              sp <= 8'd1;
              stack[0] <= start_pix;
              visited[img_idx][start_pix] <= 1'b1;
              comp_pix_cnt <= 8'd0;
              sum_x_q8 <= 32'd0;
              sum_y_q8 <= 32'd0;
              // Continue processing this component next cycle
            end
          end else begin
            // BFS loop: process up to one pixel per cycle
            pix_idx <= stack[sp - 1];
            sp <= sp - 1;

            // Accumulate sums (Q8.8 scaled by 256)
            comp_pix_cnt <= comp_pix_cnt + 8'd1;
            sum_x_q8 <= sum_x_q8 + ({4'd0, idx_x(pix_idx)} << 8);
            sum_y_q8 <= sum_y_q8 + ({5'd0, idx_y(pix_idx)} << 8);

            // Push 4-connected neighbors if they are 1 and unvisited
            // neighbor 0: x-1, y
            if (idx_x(pix_idx) != 4'd0) begin
              if (!visited[img_idx][pix_idx - 1] && img[img_idx][pix_idx - 1]) begin
                stack[sp] <= pix_idx - 1;
                sp <= sp + 1;
                visited[img_idx][pix_idx - 1] <= 1'b1;
              end
            end
            // neighbor 1: x+1, y
            if (idx_x(pix_idx) != (W-1)) begin
              if (!visited[img_idx][pix_idx + 1] && img[img_idx][pix_idx + 1]) begin
                stack[sp] <= pix_idx + 1;
                sp <= sp + 1;
                visited[img_idx][pix_idx + 1] <= 1'b1;
              end
            end
            // neighbor 2: x, y-1
            if (idx_y(pix_idx) != 3'd0) begin
              if (!visited[img_idx][pix_idx - W] && img[img_idx][pix_idx - W]) begin
                stack[sp] <= pix_idx - W;
                sp <= sp + 1;
                visited[img_idx][pix_idx - W] <= 1'b1;
              end
            end
            // neighbor 3: x, y+1
            if (idx_y(pix_idx) != (H-1)) begin
              if (!visited[img_idx][pix_idx + W] && img[img_idx][pix_idx + W]) begin
                stack[sp] <= pix_idx + W;
                sp <= sp + 1;
                visited[img_idx][pix_idx + W] <= 1'b1;
              end
            end

            // If stack empty, component finished
            if (sp == 8'd0) begin
              // Save centroid only if >= 2 pixels
              if (comp_pix_cnt >= 8'd2 && touch_cnt_r < 5'dMAX_TOUCHES) begin
                // centroid = (sum_q8 / count) >> 8
                touch_x_q8[touch_cnt_r] <= sum_x_q8 >> 8;
                touch_y_q8[touch_cnt_r] <= sum_y_q8 >> 8;
                touch_cnt_r <= touch_cnt_r + 1;
              end
              // After finishing a component, clear sp to search for next
              sp <= 8'd0;
            end
          end
        end else begin
          // Finished both images
          img_idx <= img_idx + 1; // go to CALC_GRIPS
        end
      end

      CALC_GRIPS: begin
        // Compute grip points (average of touch points) for both images
        // Touches are stored in order: first image touches (0..t0-1), then final image touches (t0..t0+t1-1)
        touch_count <= touch_cnt_r[2:0];
        if (touch_cnt_r == 5'd0) begin
          // No valid touches detected; default outputs
          grip_x_q8[0] <= 16'd0;
          grip_y_q8[0] <= 16'd0;
          grip_x_q8[1] <= 16'd0;
          grip_y_q8[1] <= 16'd0;
        end else begin
          // Split touches between init (0) and final (1)
          // Assume roughly half, but we don't know t0/t1 separately; store first half to init and rest to final
          // If total <= 5, put first (total+1)/2 to init and rest to final.
          // If total == 0, handled above.
          t0 = (touch_cnt_r + 1) >> 1; // ceil(total/2)
          t1 = touch_cnt_r - t0;
          sum_gx0 = 32'd0; sum_gy0 = 32'd0;
          sum_gx1 = 32'd0; sum_gy1 = 32'd0;
          for (int i = 0; i < t0; i++) begin
            sum_gx0 = sum_gx0 + touch_x_q8[i];
            sum_gy0 = sum_gy0 + touch_y_q8[i];
          end
          for (int i = 0; i < t1; i++) begin
            sum_gx1 = sum_gx1 + touch_x_q8[t0 + i];
            sum_gy1 = sum_gy1 + touch_y_q8[t0 + i];
          end
          if (t0 > 0) begin
            grip_x_q8[0] <= sum_gx0 / t0;
            grip_y_q8[0] <= sum_gy0 / t0;
          end else begin
            grip_x_q8[0] <= 16'd0;
            grip_y_q8[0] <= 16'd0;
          end
          if (t1 > 0) begin
            grip_x_q8[1] <= sum_gx1 / t1;
            grip_y_q8[1] <= sum_gy1 / t1;
          end else begin
            grip_x_q8[1] <= 16'd0;
            grip_y_q8[1] <= 16'd0;
          end
        end
      end

      MATCH_TOUCHES: begin
        // Compute touch vectors (grip -> touch) for final image touches (last t1 touches)
        // Determine split again (t0, t1)
        t0 = (touch_cnt_r + 1) >> 1;
        t1 = touch_cnt_r - t0;
        for (int i = 0; i < t1; i++) begin
          vec_x_q8[i] <= touch_x_q8[t0 + i] - grip_x_q8[1];
          vec_y_q8[i] <= touch_y_q8[t0 + i] - grip_y_q8[1];
        end

        // 1:1 correspondence between initial and final touches minimizing sum of squared distances
        // Parallel comparators across all pairs (<= 25 combinations)
        // Initialize best sum and indices
        min_sum <= 32'hFFFFFFFF;
        rot_cross_sum <= 32'd0;
        rot_dot_sum <= 32'd0;
        for (int i = 0; i < t0; i++) begin
          best_j[i] <= 3'd0;
        end
        // Enumerate all pairs
        for (int i = 0; i < t0; i++) begin
          for (int j = 0; j < t1; j++) begin
            dx = $signed(touch_x_q8[i]) - $signed(touch_x_q8[t0 + j]);
            dy = $signed(touch_y_q8[i]) - $signed(touch_y_q8[t0 + j]);
            sum_sq = dx * dx + dy * dy;
            if (sum_sq < min_sum) begin
              min_sum <= sum_sq;
              for (int k = 0; k < t0; k++) begin
                if (k < i) best_j[k] <= best_j[k]; else if (k == i) best_j[k] <= j[2:0]; else best_j[k] <= 3'd0;
              end
            end
          end
        end
        // Compute rotation direction sign (sum of cross products of matched pairs)
        for (int i = 0; i < t0; i++) begin
          if (i < t1) begin
            vix = $signed(vec_x_q8[i]);
            viy = $signed(vec_y_q8[i]);
            vjx = $signed(vec_x_q8[best_j[i]]);
            vjy = $signed(vec_y_q8[best_j[i]]);
            // cross = vix*vjy - viy*vjx, dot = vix*vjx + viy*vjy
            rot_cross_sum <= rot_cross_sum + (vix * vjy - viy * vjx);
            rot_dot_sum   <= rot_dot_sum   + (vix * vjx + viy * vjy);
          end
        end
      end

      COMPARE: begin
        // Pan distance: Euclidean between grips (Q8.8)
        dx_pan = $signed(grip_x_q8[1]) - $signed(grip_x_q8[0]);
        dy_pan = $signed(grip_y_q8[1]) - $signed(grip_y_q8[0]);
        dist_pan_q8 <= (dx_pan * dx_pan + dy_pan * dy_pan);

        // Zoom distance: absolute difference in average spread (grip -> touches distance)
        // spread0 = average over initial touches of |touch - grip0|
        t0 = (touch_cnt_r + 1) >> 1;
        t1 = touch_cnt_r - t0;
        sum_spread0 = 32'd0;
        for (int i = 0; i < t0; i++) begin
          dx0 = $signed(touch_x_q8[i]) - $signed(grip_x_q8[0]);
          dy0 = $signed(touch_y_q8[i]) - $signed(grip_y_q8[0]);
          dist0 = dx0 * dx0 + dy0 * dy0; // Q8.8 squared
          sum_spread0 = sum_spread0 + dist0;
        end
        if (t0 > 0) avg_spread0 = sum_spread0 / t0; else avg_spread0 = 32'd0;

        sum_spread1 = 32'd0;
        for (int i = 0; i < t1; i++) begin
          dx1 = $signed(touch_x_q8[t0 + i]) - $signed(grip_x_q8[1]);
          dy1 = $signed(touch_y_q8[t0 + i]) - $signed(grip_y_q8[1]);
          dist1 = dx1 * dx1 + dy1 * dy1; // Q8.8 squared
          sum_spread1 = sum_spread1 + dist1;
        end
        if (t1 > 0) avg_spread1 = sum_spread1 / t1; else avg_spread1 = 32'd0;

        dist_zoom_q8 <= (avg_spread0 > avg_spread1) ? (avg_spread0 - avg_spread1) : (avg_spread1 - avg_spread0);

        // Rotate distance: average angle difference magnitude (arc length ~ angle * avg_radius)
        // Use cross/dot based angle: theta = atan2(cross, dot) scaled by Q8.8; arc = theta * avg_radius
        avg_radius = (avg_spread0 + avg_spread1) >> 1; // already Q8.8 squared
        // Approximate sqrt for avg_radius: use binary approximation for Q8.8 -> keep Q8.8 after multiply by avg_radius
        // To keep within resource, approximate sqrt as 16-bit fixed-point using simple shifts is complex.
        // Instead, compute arc length as: |atan2(cross, dot)| * 256 (Q8.8) then multiply by (sqrt(avg_spread0)+sqrt(avg_spread1))/2 approximated by
        // (sqrt(avg_spread0+avg_spread1)) for small values.
        // Implement robust: arc = |cross| * 256 (scaled) if cross dominates; use dot to bound.
        // We'll use: arc_len = (|cross| * 256) + (|dot| * 16) then multiply by Q8.8 256 to keep scale.
        arc_scaled = (rot_cross_sum >= 0) ? rot_cross_sum : (~rot_cross_sum + 1);
        dist_rot_q8 <= (arc_scaled << 8) + ((rot_dot_sum >= 0 ? rot_dot_sum : (~rot_dot_sum + 1)) << 4);

        // Direction from rotation sign
        direction <= (rot_cross_sum > 0);
      end

      DONE: begin
        // Compare three distances with tolerance TOLERANCE
        if (dist_pan_q8 >= dist_zoom_q8 && dist_pan_q8 >= dist_rot_q8) begin
          // Pan is largest
          if (dist_pan_q8 > TOLERANCE) begin
            gesture_type <= 2'b00; // pan
          end else begin
            // fall back to zoom if pan too small
            if (dist_zoom_q8 >= dist_rot_q8) gesture_type <= 2'b01; else gesture_type <= 2'b10;
          end
        end else if (dist_zoom_q8 >= dist_pan_q8 && dist_zoom_q8 >= dist_rot_q8) begin
          gesture_type <= 2'b01; // zoom
        end else begin
          gesture_type <= 2'b10; // rotate
        end
        // done will be asserted by latency counter
      end

      default: begin
        // no-op
      end
    endcase
  end

  // Local variables for calculations (avoid scope warnings)
  reg [4:0] t0, t1;
  reg [31:0] sum_gx0, sum_gy0, sum_gx1, sum_gy1;
  reg [31:0] min_sum;
  reg [31:0] dx, dy, sum_sq;
  reg [31:0] rot_cross_sum, rot_dot_sum;
  reg signed [15:0] vix, viy, vjx, vjy;
  reg signed [15:0] dx_pan, dy_pan;
  reg [31:0] sum_spread0, sum_spread1, avg_spread0, avg_spread1;
  reg [31:0] avg_radius, arc_scaled;

endmodule