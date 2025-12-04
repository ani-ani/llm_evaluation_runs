module robotic_arm_controller(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [15:0] L_0,
  input [15:0] L_1,
  input [15:0] L_2,
  input [15:0] L_3,
  input [15:0] L_4,
  input [15:0] L_5,
  input [15:0] L_6,
  input [15:0] L_7,
  input [31:0] target_x,
  input [31:0] target_y,
  output reg [31:0] x_0, y_0,
  output reg [31:0] x_1, y_1,
  output reg [31:0] x_2, y_2,
  output reg [31:0] x_3, y_3,
  output reg [31:0] x_4, y_4,
  output reg [31:0] x_5, y_5,
  output reg [31:0] x_6, y_6,
  output reg [31:0] x_7, y_7,
  output reg done
);

  // Internal registers
  reg [2:0] seg_idx;              // current segment index (0-7)
  reg [31:0] cur_x, cur_y;        // current segment base position (Q16.16)
  reg [31:0] dx, dy;              // vector to target
  reg [63:0] dx2, dy2;            // squared components
  reg [63:0] dist2;               // squared distance
  reg [31:0] dist;                // approximated distance (Q16.16)
  reg [31:0] inv_dist;            // approx reciprocal magnitude (Q0.32-like scaled)
  reg [31:0] ux, uy;              // unit vector (Q16.16)
  reg [31:0] len_q16_16;          // segment length converted to Q16.16
  reg [63:0] step_x_full;         // multiplication result
  reg [63:0] step_y_full;
  reg [31:0] step_x;              // step in x (Q16.16)
  reg [31:0] step_y;              // step in y (Q16.16)
  reg running;                    // active computation flag

  // Parameters
  localparam [31:0] EPS_001 = 32'd655; // 0.01 in Q16.16

  // Function: absolute value (32-bit signed)
  function automatic [31:0] abs32;
    input [31:0] v;
    begin
      if (v[31]) abs32 = ~v + 1'b1;
      else       abs32 = v;
    end
  endfunction

  // Approximate distance using max(|dx|,|dy|) + 0.5*min(|dx|,|dy|)
  function automatic [31:0] approx_dist;
    input [31:0] dx_in;
    input [31:0] dy_in;
    reg [31:0] ax, ay, max_v, min_v;
    begin
      ax = abs32(dx_in);
      ay = abs32(dy_in);
      if (ax >= ay) begin
        max_v = ax;
        min_v = ay;
      end else begin
        max_v = ay;
        min_v = ax;
      end
      approx_dist = max_v + (min_v >> 1); // Q16.16 result
    end
  endfunction

  // Approximate reciprocal: inv_dist ≈ (1.0 / d) in Q0.32 domain scaled for use with Q16.16
  // We target ux = dx * inv_dist >> 16 to keep Q16.16. Use simple piecewise for efficiency.
  function automatic [31:0] approx_inv_dist;
    input [31:0] d; // Q16.16
    reg [31:0] d_clamped;
    begin
      // Avoid division by zero; clamp to EPS_001
      if (d < EPS_001)
        d_clamped = EPS_001;
      else
        d_clamped = d;

      // Compute approximate inv using a single-iteration linear approximation around 1.0
      // inv_d_q32 ≈ (1<<32)/d_clamped; implemented via simple unsigned division
      approx_inv_dist = (32'hFFFF_FFFF / d_clamped); // Q0.32-like
    end
  endfunction

  // Get length for current segment index (Q16.0 -> extend to 32-bit)
  function automatic [31:0] get_len_q16_16;
    input [2:0] idx;
    reg [15:0] L_sel;
    begin
      case (idx)
        3'd0: L_sel = L_0;
        3'd1: L_sel = L_1;
        3'd2: L_sel = L_2;
        3'd3: L_sel = L_3;
        3'd4: L_sel = L_4;
        3'd5: L_sel = L_5;
        3'd6: L_sel = L_6;
        3'd7: L_sel = L_7;
        default: L_sel = 16'd0;
      endcase
      // convert Q16.0 (integer) to Q16.16 by shifting left 16
      get_len_q16_16 = {L_sel,16'd0};
    end
  endfunction

  // Sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      x_0 <= 32'd0; y_0 <= 32'd0;
      x_1 <= 32'd0; y_1 <= 32'd0;
      x_2 <= 32'd0; y_2 <= 32'd0;
      x_3 <= 32'd0; y_3 <= 32'd0;
      x_4 <= 32'd0; y_4 <= 32'd0;
      x_5 <= 32'd0; y_5 <= 32'd0;
      x_6 <= 32'd0; y_6 <= 32'd0;
      x_7 <= 32'd0; y_7 <= 32'd0;
      done <= 1'b0;
      running <= 1'b0;
      seg_idx <= 3'd0;
      cur_x <= 32'd0;
      cur_y <= 32'd0;
    end else begin
      if (!start) begin
        // Idle / clear when start is low
        x_0 <= 32'd0; y_0 <= 32'd0;
        x_1 <= 32'd0; y_1 <= 32'd0;
        x_2 <= 32'd0; y_2 <= 32'd0;
        x_3 <= 32'd0; y_3 <= 32'd0;
        x_4 <= 32'd0; y_4 <= 32'd0;
        x_5 <= 32'd0; y_5 <= 32'd0;
        x_6 <= 32'd0; y_6 <= 32'd0;
        x_7 <= 32'd0; y_7 <= 32'd0;
        done <= 1'b0;
        running <= 1'b0;
        seg_idx <= 3'd0;
        cur_x <= 32'd0;
        cur_y <= 32'd0;
      end else begin
        if (!running) begin
          // Start new computation on start=1 (first active cycle)
          running <= 1'b1;
          done <= 1'b0;
          seg_idx <= 3'd0;
          cur_x <= 32'd0; // base at origin
          cur_y <= 32'd0;
          x_0 <= 32'd0; y_0 <= 32'd0;
          x_1 <= 32'd0; y_1 <= 32'd0;
          x_2 <= 32'd0; y_2 <= 32'd0;
          x_3 <= 32'd0; y_3 <= 32'd0;
          x_4 <= 32'd0; y_4 <= 32'd0;
          x_5 <= 32'd0; y_5 <= 32'd0;
          x_6 <= 32'd0; y_6 <= 32'd0;
          x_7 <= 32'd0; y_7 <= 32'd0;
        end else if (!done) begin
          // Perform one segment computation per cycle
          if (seg_idx < N) begin
            // Vector towards target
            dx = target_x - cur_x;
            dy = target_y - cur_y;

            // Approximate distance
            dist = approx_dist(dx, dy);

            if (dist < EPS_001) begin
              // Close enough: point directly to target using full vector as step
              // Normalize by clamping step length to segment length if needed
              len_q16_16 = get_len_q16_16(seg_idx);

              // If |dx,dy| very small, just use dx,dy as is (won't exceed length meaningfully)
              // But to respect segment length, scale if dist > len
              if (dist > len_q16_16 && dist != 32'd0) begin
                // scale = len / dist; step = (dx * scale, dy * scale)
                inv_dist = (32'hFFFF_FFFF / dist); // Q0.32 approx 1/dist
                step_x_full = $signed(dx) * $signed(inv_dist); // Q16.16 * Q0.32 = Q16.48
                step_y_full = $signed(dy) * $signed(inv_dist);
                // step = (len * (dx/dist))
                step_x_full = ($signed(len_q16_16) * $signed(step_x_full[47:16]));
                step_y_full = ($signed(len_q16_16) * $signed(step_y_full[47:16]));
                step_x = step_x_full[47:16];
                step_y = step_y_full[47:16];
              end else begin
                // Use direct vector (already very small)
                step_x = dx;
                step_y = dy;
              end
            end else begin
              // General case: compute unit vector and scale by segment length
              len_q16_16 = get_len_q16_16(seg_idx);

              // inv_dist in Q0.32-like; ux = dx * inv_dist >> 16 to get Q16.16
              inv_dist = approx_inv_dist(dist);

              step_x_full = $signed(dx) * $signed(inv_dist);  // Q16.16 * Q0.32 = Q16.48
              step_y_full = $signed(dy) * $signed(inv_dist);

              ux = step_x_full[47:16]; // Q16.16
              uy = step_y_full[47:16]; // Q16.16

              step_x_full = $signed(len_q16_16) * $signed(ux); // Q16.16 * Q16.16 = Q32.32
              step_y_full = $signed(len_q16_16) * $signed(uy);

              step_x = step_x_full[47:16];
              step_y = step_y_full[47:16];
            end

            // New tip position
            cur_x <= $signed(cur_x) + $signed(step_x);
            cur_y <= $signed(cur_y) + $signed(step_y);

            // Store in corresponding outputs
            case (seg_idx)
              3'd0: begin x_0 <= $signed(cur_x) + $signed(step_x); y_0 <= $signed(cur_y) + $signed(step_y); end
              3'd1: begin x_1 <= $signed(cur_x) + $signed(step_x); y_1 <= $signed(cur_y) + $signed(step_y); end
              3'd2: begin x_2 <= $signed(cur_x) + $signed(step_x); y_2 <= $signed(cur_y) + $signed(step_y); end
              3'd3: begin x_3 <= $signed(cur_x) + $signed(step_x); y_3 <= $signed(cur_y) + $signed(step_y); end
              3'd4: begin x_4 <= $signed(cur_x) + $signed(step_x); y_4 <= $signed(cur_y) + $signed(step_y); end
              3'd5: begin x_5 <= $signed(cur_x) + $signed(step_x); y_5 <= $signed(cur_y) + $signed(step_y); end
              3'd6: begin x_6 <= $signed(cur_x) + $signed(step_x); y_6 <= $signed(cur_y) + $signed(step_y); end
              3'd7: begin x_7 <= $signed(cur_x) + $signed(step_x); y_7 <= $signed(cur_y) + $signed(step_y); end
              default: ;
            endcase

            // Advance to next segment
            seg_idx <= seg_idx + 3'd1;

            // If this was the last segment per N, raise done next
            if (seg_idx + 3'd1 >= N) begin
              done <= 1'b1;
            end
          end else begin
            // Already computed all segments
            done <= 1'b1;
          end
        end
      end
    end
  end

endmodule