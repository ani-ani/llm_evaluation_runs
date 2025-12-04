module dog_walk_distance(
  input              clk,
  input              rst_n,
  input              start,
  input       [3:0]  shadow_segment_count,
  input       [31:0] shadow_x [0:15],
  input       [31:0] shadow_y [0:15],
  input       [3:0]  lydia_segment_count,
  input       [31:0] lydia_x  [0:15],
  input       [31:0] lydia_y  [0:15],
  output reg  [31:0] min_distance,
  output reg         done
);

  // Note: Using 32-bit Q16.16 for coordinates/distances, despite problem text typo on [15:0].

  // FSM States
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_LOAD      = 3'd1,
    S_PREP_SEG  = 3'd2,
    S_ITER      = 3'd3,
    S_UPDATE    = 3'd4,
    S_NEXT      = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // Segment indices
  reg [3:0] si;  // Shadow segment index
  reg [3:0] li;  // Lydia segment index

  // Latched path endpoints for current segments
  reg [31:0] p0x, p0y, p1x, p1y;  // Shadow segment endpoints
  reg [31:0] q0x, q0y, q1x, q1y;  // Lydia segment endpoints

  // Direction vectors
  reg  signed [31:0] ux, uy;      // u = P1 - P0
  reg  signed [31:0] vx, vy;      // v = Q1 - Q0
  reg  signed [31:0] wx0, wy0;    // w0 = P0 - Q0

  // Working registers for projections
  reg  signed [63:0] a;           // u·u
  reg  signed [63:0] b;           // u·v
  reg  signed [63:0] c;           // v·v
  reg  signed [63:0] d;           // u·w0
  reg  signed [63:0] e;           // v·w0
  reg  signed [63:0] D;           // denominator = a*c - b*b

  // Parameters
  localparam signed [31:0] ONE_Q16_16 = 32'h0001_0000;

  // Local wires/regs
  reg  [31:0] seg_min_dist;         // min distance for current segment pair
  reg  [31:0] cur_min_dist;         // running global min
  reg  [63:0] dist2_best;           // best distance^2 for current pair (Q32.32)
  reg  [63:0] dist2_global_min;     // global min distance^2

  // Helper function: 32-bit signed multiply producing 64-bit
  function automatic signed [63:0] smul32(input signed [31:0] x, input signed [31:0] y);
    smul32 = x * y;
  endfunction

  // Helper function: saturating Q16.16 sqrt via integer sqrt on Q32.32
  function automatic [31:0] q16_16_sqrt(input [63:0] x2);
    // x2 is Q32.32 representing squared distance.
    // We compute integer sqrt on x2, result is Q16.16 when we shift appropriately.
    // Let y = sqrt(x2); x2 in Q32.32 => y in Q16.16 if we take integer sqrt and keep 16 frac bits.
    integer i;
    reg [63:0] rem;
    reg [63:0] root;
    reg [63:0] div;
    begin
      rem  = 0;
      root = 0;
      // Non-restoring-like binary sqrt for 64-bit input
      for (i = 0; i < 32; i = i + 1) begin
        rem  = {rem[61:0], x2[63-2*i -: 2]};
        div  = (root << 2) | 2;
        if (rem >= div) begin
          rem  = rem - div;
          root = (root << 1) | 1;
        end else begin
          root = root << 1;
        end
      end
      // root is sqrt(x2) in Q16.16 (since we iterated 32 pairs of bits)
      q16_16_sqrt = root[31:0];
    end
  endfunction

  // Compute squared distance between two Q16.16 points (x0,y0) and (x1,y1)
  function automatic [63:0] dist2_point(
      input signed [31:0] x0,
      input signed [31:0] y0,
      input signed [31:0] x1,
      input signed [31:0] y1);
    reg signed [31:0] dx, dy;
    reg signed [63:0] dx2, dy2;
    begin
      dx  = x0 - x1;
      dy  = y0 - y1;
      dx2 = smul32(dx, dx); // Q32.32
      dy2 = smul32(dy, dy);
      dist2_point = dx2 + dy2;
    end
  endfunction

  // Clamp fraction t in Q16.16 to [0,1]
  function automatic signed [31:0] clamp_0_1(input signed [31:0] t);
    begin
      if (t < 0)
        clamp_0_1 = 0;
      else if (t > ONE_Q16_16)
        clamp_0_1 = ONE_Q16_16;
      else
        clamp_0_1 = t;
    end
  endfunction

  // Compute point on segment P(t) = P0 + t*(P1-P0), with t in Q16.16
  function automatic signed [31:0] seg_coord(input signed [31:0] p0,
                                             input signed [31:0] u,
                                             input signed [31:0] t);
    reg signed [63:0] tmp;
    begin
      // p0 + (u * t) >> 16
      tmp = smul32(u, t);
      seg_coord = p0 + tmp[47:16];
    end
  endfunction

  // Sequential FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= S_IDLE;
      done              <= 1'b0;
      min_distance      <= 32'd0;
      cur_min_dist      <= 32'h7FFF_FFFF;
      dist2_global_min  <= 64'h7FFF_FFFF_FFFF_FFFF;
      si                <= 4'd0;
      li                <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done             <= 1'b0;
          cur_min_dist     <= 32'h7FFF_FFFF;
          dist2_global_min <= 64'h7FFF_FFFF_FFFF_FFFF;
          if (start) begin
            si <= 4'd0;
            li <= 4'd0;
          end
        end

        S_LOAD: begin
          // Load current segment endpoints
          p0x <= shadow_x[si];
          p0y <= shadow_y[si];
          p1x <= shadow_x[si+1];
          p1y <= shadow_y[si+1];
          q0x <= lydia_x[li];
          q0y <= lydia_y[li];
          q1x <= lydia_x[li+1];
          q1y <= lydia_y[li+1];
        end

        S_PREP_SEG: begin
          // Compute direction vectors and w0
          ux  <= p1x - p0x;
          uy  <= p1y - p0y;
          vx  <= q1x - q0x;
          vy  <= q1y - q0y;
          wx0 <= p0x - q0x;
          wy0 <= p0y - q0y;
        end

        S_ITER: begin
          // Compute dot products for projection
          a <= smul32(ux, ux) + smul32(uy, uy); // u·u
          b <= smul32(ux, vx) + smul32(uy, vy); // u·v
          c <= smul32(vx, vx) + smul32(vy, vy); // v·v
          d <= smul32(ux, wx0) + smul32(uy, wy0); // u·w0
          e <= smul32(vx, wx0) + smul32(vy, wy0); // v·w0
          D <= ( (smul32(ux, ux) + smul32(uy, uy)) * (smul32(vx, vx) + smul32(vy, vy)) ) - ( (smul32(ux, vx) + smul32(uy, vy)) * (smul32(ux, vx) + smul32(uy, vy)) );
        end

        S_UPDATE: begin
          // Approximate closest distance between two segments using clipped projections.
          // We implement a simplified and robust approach:
          // 1) Try internal solution if D != 0
          // 2) Always consider endpoints-to-segment distances and endpoint-to-endpoint distances

          reg signed [31:0] sc, tc;
          reg signed [63:0] num_s, num_t;
          reg signed [63:0] dist2;
          reg signed [31:0] px, py, qx, qy;

          dist2_best = 64'h7FFF_FFFF_FFFF_FFFF;

          // Internal solution when segments not parallel (D != 0)
          if (D != 0) begin
            // sc = (b*e - c*d) / D, tc = (a*e - b*d) / D in real; we keep as Q16.16 by scaling numerator
            num_s = (b*e - c*d);
            num_t = (a*e - b*d);
            // Convert to Q16.16: (num << 16)/D
            sc = clamp_0_1( $signed( (num_s <<< 16) / D ) );
            tc = clamp_0_1( $signed( (num_t <<< 16) / D ) );

            px = seg_coord(p0x, ux, sc);
            py = seg_coord(p0y, uy, sc);
            qx = seg_coord(q0x, vx, tc);
            qy = seg_coord(q0y, vy, tc);

            dist2 = dist2_point(px, py, qx, qy);
            if (dist2 < dist2_best)
              dist2_best = dist2;
          end

          // Endpoint P0 to segment Q
          begin
            reg signed [63:0] t_num;
            reg signed [31:0] t_clamped;
            if ( (smul32(vx, vx) + smul32(vy, vy)) != 0 ) begin
              t_num = -e; // v·(p0-q0) = -e
              t_clamped = clamp_0_1( $signed( (t_num <<< 16) / (smul32(vx, vx) + smul32(vy, vy)) ) );
              qx = seg_coord(q0x, vx, t_clamped);
              qy = seg_coord(q0y, vy, t_clamped);
              dist2 = dist2_point(p0x, p0y, qx, qy);
              if (dist2 < dist2_best)
                dist2_best = dist2;
            end
          end

          // Endpoint P1 to segment Q
          begin
            reg signed [31:0] w1x, w1y;
            reg signed [63:0] e1, t_num1;
            reg signed [31:0] t_clamped1;
            w1x = p1x - q0x;
            w1y = p1y - q0y;
            e1  = smul32(vx, w1x) + smul32(vy, w1y);
            if ( (smul32(vx, vx) + smul32(vy, vy)) != 0 ) begin
              t_num1 = e1;
              t_clamped1 = clamp_0_1( $signed( (t_num1 <<< 16) / (smul32(vx, vx) + smul32(vy, vy)) ) );
              qx = seg_coord(q0x, vx, t_clamped1);
              qy = seg_coord(q0y, vy, t_clamped1);
              dist2 = dist2_point(p1x, p1y, qx, qy);
              if (dist2 < dist2_best)
                dist2_best = dist2;
            end
          end

          // Endpoint Q0 to segment P
          begin
            reg signed [63:0] d0, t_num2;
            reg signed [31:0] t_clamped2;
            d0 = smul32(ux, wx0) + smul32(uy, wy0);
            if ( (smul32(ux, ux) + smul32(uy, uy)) != 0 ) begin
              t_num2 = -d0;
              t_clamped2 = clamp_0_1( $signed( (t_num2 <<< 16) / (smul32(ux, ux) + smul32(uy, uy)) ) );
              px = seg_coord(p0x, ux, t_clamped2);
              py = seg_coord(p0y, uy, t_clamped2);
              dist2 = dist2_point(px, py, q0x, q0y);
              if (dist2 < dist2_best)
                dist2_best = dist2;
            end
          end

          // Endpoint Q1 to segment P
          begin
            reg signed [31:0] wq1x, wq1y;
            reg signed [63:0] d1, t_num3;
            reg signed [31:0] t_clamped3;
            wq1x = q1x - p0x;
            wq1y = q1y - p0y;
            d1   = smul32(ux, wq1x) + smul32(uy, wq1y);
            if ( (smul32(ux, ux) + smul32(uy, uy)) != 0 ) begin
              t_num3 = d1;
              t_clamped3 = clamp_0_1( $signed( (t_num3 <<< 16) / (smul32(ux, ux) + smul32(uy, uy)) ) );
              px = seg_coord(p0x, ux, t_clamped3);
              py = seg_coord(p0y, uy, t_clamped3);
              dist2 = dist2_point(px, py, q1x, q1y);
              if (dist2 < dist2_best)
                dist2_best = dist2;
            end
          end

          // Endpoints to endpoints directly
          dist2 = dist2_point(p0x, p0y, q0x, q0y);
          if (dist2 < dist2_best) dist2_best = dist2;

          dist2 = dist2_point(p0x, p0y, q1x, q1y);
          if (dist2 < dist2_best) dist2_best = dist2;

          dist2 = dist2_point(p1x, p1y, q0x, q0y);
          if (dist2 < dist2_best) dist2_best = dist2;

          dist2 = dist2_point(p1x, p1y, q1x, q1y);
          if (dist2 < dist2_best) dist2_best = dist2;

          // Compute Q16.16 distance from best squared distance
          seg_min_dist = q16_16_sqrt(dist2_best);

          // Update global minimum
          if (seg_min_dist < cur_min_dist) begin
            cur_min_dist     <= seg_min_dist;
            dist2_global_min <= dist2_best;
          end
        end

        S_NEXT: begin
          // Advance to next segment pair
          if (li < lydia_segment_count - 1) begin
            li <= li + 1'b1;
          end else begin
            li <= 4'd0;
            if (si < shadow_segment_count - 1)
              si <= si + 1'b1;
          end
        end

        S_DONE: begin
          done         <= 1'b1;
          min_distance <= cur_min_dist;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LOAD;
      end

      S_LOAD: begin
        next_state = S_PREP_SEG;
      end

      S_PREP_SEG: begin
        next_state = S_ITER;
      end

      S_ITER: begin
        next_state = S_UPDATE;
      end

      S_UPDATE: begin
        // Decide if more segment pairs remain
        if ((si == shadow_segment_count - 1) && (li == lydia_segment_count - 1)) begin
          next_state = S_DONE;
        end else begin
          next_state = S_NEXT;
        end
      end

      S_NEXT: begin
        next_state = S_LOAD;
      end

      S_DONE: begin
        // Stay until next start pulse (optional: user can observe done and then pulse start)
        if (start)
          next_state = S_LOAD;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule