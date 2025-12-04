module dog_walk_distance(
  input clk,
  input rst_n,
  input start,
  input [3:0] shadow_segment_count,
  input [15:0] shadow_x [0:15],
  input [15:0] shadow_y [0:15],
  input [3:0] lydia_segment_count,
  input [15:0] lydia_x [0:15],
  input [15:0] lydia_y [0:15],
  output reg [15:0] min_distance,
  output reg done
);

  // Q16.16 helpers
  localparam FRAC = 16;

  // State machine
  typedef enum logic [2:0] {
    IDLE   = 3'b000,
    LOAD   = 3'b001,
    OUTER  = 3'b010,
    INNER  = 3'b011,
    COMPUTE= 3'b100,
    FINISH = 3'b101
  } state_t;

  state_t state, next_state;

  // Loop indices and buffers
  reg [7:0] i, j;        // current segment indices for shadow and lydia
  reg [7:0] i_max, j_max; // inclusive iteration caps (number of segments)
  reg [7:0] i_next, j_next;
  reg [15:0] p0x, p0y;    // current shadow segment start point
  reg [15:0] p1x, p1y;    // current shadow segment end point
  reg [15:0] r0x, r0y;    // current lydia segment start point
  reg [15:0] r1x, r1y;    // current lydia segment end point
  reg [15:0] p_sc, p_ec;  // clamped projection parameters s_c, t_c (Q16.16)
  reg start_d;
  reg running;

  // Registered minimum distance
  reg [15:0] best;
  reg done_next;

  // --------------------------
  // Distance computation helpers (Q16.16)
  // --------------------------
  // Compute s_c = clamp( num_s / den, 0, 1 ), where num_s = b*(b - a) + d*(c - a)
  function [15:0] clamp01_div;
    input signed [31:0] num; // already scaled by FRAC (Q16.16)
    input signed [31:0] den; // Q16.16, signed; may be negative
    reg signed [31:0] den_abs;
    reg signed [31:0] s_raw;
    reg signed [31:0] s_clamped;
  begin
    den_abs = den[31] ? (~den + 1) : den;
    if (den == 0) begin
      // Avoid division by zero; default to 0
      s_raw = 0;
    end else begin
      // s_raw = num / den (Q16.16 / Q16.16 -> Q16.16)
      s_raw = num / den;
    end
    // Clamp to [0, 1] in Q16.16
    if (s_raw < 0) s_clamped = 0;
    else if (s_raw > (1 <<< FRAC)) s_clamped = (1 <<< FRAC);
    else s_clamped = s_raw;
    clamp01_div = s_clamped[15:0];
  end
  endfunction

  // Compute squared distance d^2 between two line segments using closest-point-on-segment method.
  // All values are Q16.16; return value is Q16.16.
  function [15:0] segment_distance_sq;
    input [15:0] p0x, p0y; // segment P start
    input [15:0] p1x, p1y; // segment P end
    input [15:0] r0x, r0y; // segment R start
    input [15:0] r1x, r1y; // segment R end

    // Differences in Q16.16
    signed [31:0] ux, uy; // P: p1 - p0
    signed [31:0] vx, vy; // R: r1 - r0
    signed [31:0] wx, wy; // w0 = p0 - r0
    signed [31:0] a, b, c, d; // dot products in Q16.16
    signed [31:0] den;         // 2*(u·u) etc in Q16.16
    signed [31:0] num_s, num_t; // numerators in Q16.16
    signed [31:0] sx, sy;     // s*(u) in Q16.16
    signed [31:0] tx, ty;     // t*(v) in Q16.16
    signed [31:0] dx, dy;     // d = (w0 + s*u - t*v) in Q16.16
    signed [63:0] acc;        // accumulate d^2 in Q32.32, then scale to Q16.16
    reg [15:0] s_q16, t_q16;  // s_c, t_c in Q16.16
    reg [31:0] d2_q16;        // result in Q16.16
  begin
    ux = $signed({1'b0, p1x}) - $signed({1'b0, p0x});
    uy = $signed({1'b0, p1y}) - $signed({1'b0, p0y});
    vx = $signed({1'b0, r1x}) - $signed({1'b0, r0x});
    vy = $signed({1'b0, r1y}) - $signed({1'b0, r0y});
    wx = $signed({1'b0, p0x}) - $signed({1'b0, r0x});
    wy = $signed({1'b0, p0y}) - $signed({1'b0, r0y});

    a = (ux * ux + uy * uy) >>> 0; // Q16.16 * Q16.16 -> Q32.32; >>>0 keeps high as Q16.16
    b = (ux * vx + uy * vy) >>> 0; // u·v
    c = (vx * vx + vy * vy) >>> 0; // v·v
    d = (ux * wx + uy * wy) >>> 0; // u·w0

    den = 2 * (a * c - b * b); // 2*(a*c - b*b) in Q16.16
    num_s = b * d - a * (vx * wx + vy * wy); // b*d - a*(v·w0)
    num_t = a * (ux * wx + uy * wy) - b * d; // a*(u·w0) - b*d

    s_q16 = clamp01_div(num_s, den);
    t_q16 = clamp01_div(num_t, den);

    // Compute closest point difference: d = (p0 - r0) + s*u - t*v
    sx = $signed(s_q16) * ux;
    sy = $signed(s_q16) * uy;
    tx = $signed(t_q16) * vx;
    ty = $signed(t_q16) * vy;

    dx = wx + sx - tx;
    dy = wy + sy - ty;

    acc = ($signed(dx) * $signed(dx) + $signed(dy) * $signed(dy)) >>> 0; // Q32.32
    // Convert to Q16.16 by shifting right 16 fractional bits
    d2_q16 = acc[47:16];
    if (d2_q16[31] !== 1'b0 && d2_q16 !== 32'h7FFFFFFF) begin
      // Positive value is valid
    end
    segment_distance_sq = d2_q16[15:0];
  end
  endfunction

  // --------------------------
  // State update
  // --------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      running <= 1'b0;
      min_distance <= 16'h0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= done_next;
      if (state == IDLE) begin
        running <= 1'b0;
      end else if (state == FINISH) begin
        running <= 1'b0;
      end
    end
  end

  // Edge detection for start
  always @(posedge clk) begin
    start_d <= start;
  end

  // Compute next state and update buffers
  always @(*) begin
    // Defaults
    next_state = state;
    done_next = 1'b0;

    // Load defaults to avoid latches
    i_next = i;
    j_next = j;
    p_sc = 16'h0; p_ec = 16'h0;
    best = min_distance;

    if (!rst_n) begin
      next_state = IDLE;
      done_next = 1'b0;
    end else begin
      case (state)
        IDLE: begin
          // Wait for start rising edge
          if (start && !start_d) begin
            // Initialize
            best = 16'hFFFF; // large positive in Q16.16
            i_next = 8'h0;
            j_next = 8'h0;
            running <= 1'b1;
            next_state = LOAD;
          end else begin
            next_state = IDLE;
            done_next = 1'b0;
          end
        end

        LOAD: begin
          // Bounds inclusive: number of segments
          i_max = {4'h0, shadow_segment_count}; // 0..15
          j_max = {4'h0, lydia_segment_count}; // 0..15
          // Prime the first outer segment endpoints
          p0x = shadow_x[0];
          p0y = shadow_y[0];
          p1x = shadow_x[1];
          p1y = shadow_y[1];
          next_state = OUTER;
        end

        OUTER: begin
          if (i > i_max) begin
            next_state = FINISH;
          end else begin
            // Load current Shadow segment (i)
            p0x = shadow_x[i];
            p0y = shadow_y[i];
            p1x = shadow_x[i + 1];
            p1y = shadow_y[i + 1];
            // Reset inner loop for this i
            j_next = 8'h0;
            next_state = INNER;
          end
        end

        INNER: begin
          if (j > j_max) begin
            // Advance outer index
            i_next = i + 1;
            next_state = OUTER;
          end else begin
            // Load current Lydia segment (j)
            r0x = lydia_x[j];
            r0y = lydia_y[j];
            r1x = lydia_x[j + 1];
            r1y = lydia_y[j + 1];
            next_state = COMPUTE;
          end
        end

        COMPUTE: begin
          // Compute distance for (i,j)
          begin
            [15:0] d2 = segment_distance_sq(p0x, p0y, p1x, p1y, r0x, r0y, r1x, r1y);
            if (d2 < best) best = d2;
          end
          // Increment inner loop
          j_next = j + 1;
          next_state = INNER;
        end

        FINISH: begin
          min_distance = best;
          done_next = 1'b1;
          next_state = IDLE;
        end

        default: next_state = IDLE;
      endcase
    end
  end

  // Update pointers and segment endpoints on clock edge
  always @(posedge clk) begin
    if (!rst_n) begin
      i <= 8'h0;
      j <= 8'h0;
    end else begin
      i <= i_next;
      j <= j_next;
      p_sc <= p_sc; // kept for compatibility
      p_ec <= p_ec;
      min_distance <= min_distance; // updated in FINISH
    end
  end

endmodule
