module hovercraft_navigator(
  input clk,
  input rst_n,
  input start,
  input [31:0] x_pos,
  input [31:0] y_pos,
  input [31:0] velocity,
  input [31:0] omega,
  output reg [31:0] min_time,
  output reg done
);

  // Q16.16 constants
  localparam [31:0] Q_ONE     = 32'h0001_0000; // 1.0
  localparam [31:0] Q_TWO     = 32'h0002_0000; // 2.0
  localparam [31:0] Q_ZERO    = 32'h0000_0000; // 0.0

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    CALC_ANGLE  = 3'd1,
    CALC_DIST   = 3'd2,
    CALC_TIMES  = 3'd3,
    COMPARE     = 3'd4,
    DONE_STATE  = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] x_reg, y_reg;
  reg [31:0] vx_reg, w_reg;
  reg [31:0] angle;         // atan2 result Q16.16
  reg [31:0] abs_angle;
  reg [63:0] x_sq, y_sq;
  reg [63:0] dist_sq;
  reg [31:0] dist;          // sqrt(x^2 + y^2) Q16.16

  reg [63:0] t1_tmp;
  reg [63:0] t2_tmp;
  reg [31:0] t1;            // rotate-only time Q16.16
  reg [31:0] t2;            // move-only time Q16.16
  reg [31:0] t_seq;         // strategy 1 total time
  reg [31:0] t_mix;         // strategy 2 time (simplified heuristic)

  reg [3:0]  cycle_cnt;

  // Safe reciprocal helpers (avoid div by zero): if denom==0 -> max time
  function automatic [31:0] qdiv(input [63:0] num, input [31:0] den);
    begin
      if (den == 32'd0)
        qdiv = 32'hFFFF_FFFF;
      else
        qdiv = num / den;
    end
  endfunction

  // Saturating absolute value for Q16.16
  function automatic [31:0] qabs(input [31:0] a);
    begin
      if (a[31])
        qabs = (~a) + 1'b1;
      else
        qabs = a;
    end
  endfunction

  // Simple piecewise atan approximation for Q16.16
  // Uses: atan(z) ~= z - z^3/3 for |z|<=1; for |z|>1, atan(z)=pi/2 - atan(1/z)
  // pi/2 in Q16.16: 1.570796 * 65536 ≈ 0x00019220
  localparam [31:0] Q_PI_BY_2 = 32'h0001_9220;

  function automatic [31:0] atan_q16(input signed [31:0] y, input signed [31:0] x);
    reg signed [31:0] z;
    reg [31:0] abs_z;
    reg [63:0] z_sq;
    reg [63:0] z_cu;
    reg signed [31:0] atan_core;
    reg signed [31:0] res;
    reg inv_region;
    reg sign_z;
    begin
      if (x == 0 && y == 0) begin
        atan_q16 = 32'd0;
      end else begin
        // Quadrant handling via atan2
        // First compute atan(|y/x|) with approximation
        if (x == 0) begin
          res = (y[31]) ? -$signed(Q_PI_BY_2) : $signed(Q_PI_BY_2);
        end else begin
          // z = y/x in Q16.16
          z = $signed(y);
          z = (z <<< 16) / $signed(x); // Q16.16 division
          sign_z = z[31];
          abs_z = sign_z ? (~z + 1'b1) : z;
          if (abs_z <= Q_ONE) begin
            inv_region = 1'b0;
            // atan(z) ~= z - z^3/3
            z_sq = $signed(z) * $signed(z);         // Q32.32
            z_cu = z_sq * $signed(z);               // Q48.48
            atan_core = $signed(z) - $signed(z_cu / 3 >>> 32); // back to Q16.16
          end else begin
            inv_region = 1'b1;
            // use 1/z
            if (z == 0) begin
              atan_core = 32'd0;
            end else begin
              // inv_z = 1/z in Q16.16
              // (1.0 Q16.16 / z)
              reg signed [31:0] inv_z;
              inv_z = $signed(Q_ONE) <<< 16;
              inv_z = inv_z / z; // Q16.16
              // atan(inv_z) approx
              z_sq = $signed(inv_z) * $signed(inv_z);
              z_cu = z_sq * $signed(inv_z);
              atan_core = $signed(inv_z) - $signed(z_cu / 3 >>> 32);
            end
          end

          // if |z|>1: atan(z) = pi/2 - atan(1/z) (keeping sign)
          if (inv_region) begin
            if (!sign_z)
              res = $signed(Q_PI_BY_2) - atan_core;
            else
              res = -$signed(Q_PI_BY_2) - atan_core;
          end else begin
            res = atan_core;
          end

          // Adjust for quadrants of x,y
          if (x[31] == 1'b0) begin
            // x > 0: angle = res
          end else begin
            // x < 0
            if (y[31] == 1'b0)
              res = res + $signed(32'h0003_2440); // +pi
            else
              res = res - $signed(32'h0003_2440); // -pi
          end
        end
        atan_q16 = res;
      end
    end
  endfunction

  // Integer sqrt for 64-bit input, Q16.16 output assuming input in Q32.32
  function automatic [31:0] qsqrt_q32_to_q16(input [63:0] val);
    reg [63:0] root;
    reg [63:0] bit;
    reg [63:0] tmp;
    integer i;
    begin
      root = 0;
      bit = 64'h4000_0000_0000_0000;
      // Align
      while (bit > val)
        bit = bit >> 2;
      while (bit != 0) begin
        tmp = root + bit;
        if (val >= tmp) begin
          val  = val - tmp;
          root = (root >> 1) + bit;
        end else begin
          root = root >> 1;
        end
        bit = bit >> 2;
      end
      // root is integer sqrt of val; convert to Q16.16 by <<16
      qsqrt_q32_to_q16 = root[31:0] << 16;
    end
  endfunction

  // State register and cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 4'd0;
      x_reg      <= 32'd0;
      y_reg      <= 32'd0;
      vx_reg     <= 32'd0;
      w_reg      <= 32'd0;
      angle      <= 32'd0;
      abs_angle  <= 32'd0;
      x_sq       <= 64'd0;
      y_sq       <= 64'd0;
      dist_sq    <= 64'd0;
      dist       <= 32'd0;
      t1_tmp     <= 64'd0;
      t2_tmp     <= 64'd0;
      t1         <= 32'd0;
      t2         <= 32'd0;
      t_seq      <= 32'd0;
      t_mix      <= 32'd0;
      min_time   <= 32'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      if (state == IDLE) begin
        done <= 1'b0;
      end

      case (state)
        IDLE: begin
          cycle_cnt <= 4'd0;
          if (start) begin
            x_reg  <= x_pos;
            y_reg  <= y_pos;
            vx_reg <= velocity;
            w_reg  <= omega;
          end
        end

        CALC_ANGLE: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          // Compute angle once when entering this state
          if (cycle_cnt == 4'd0) begin
            angle     <= atan_q16($signed(y_reg), $signed(x_reg));
            abs_angle <= qabs(angle);
          end
        end

        CALC_DIST: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          if (cycle_cnt == 4'd0) begin
            x_sq    <= $signed(x_reg) * $signed(x_reg); // Q32.32
            y_sq    <= $signed(y_reg) * $signed(y_reg); // Q32.32
          end else if (cycle_cnt == 4'd1) begin
            dist_sq <= x_sq + y_sq;
          end else if (cycle_cnt == 4'd2) begin
            dist   <= qsqrt_q32_to_q16(dist_sq); // Q16.16
          end
        end

        CALC_TIMES: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          if (cycle_cnt == 4'd0) begin
            // t1 = abs_angle / omega; implement as (abs_angle <<16)/omega
            t1_tmp <= {abs_angle,16'd0};
          end else if (cycle_cnt == 4'd1) begin
            t1 <= qdiv(t1_tmp, w_reg); // Q16.16
          end else if (cycle_cnt == 4'd2) begin
            // t2 = dist / velocity; (dist <<16)/v
            t2_tmp <= {dist,16'd0};
          end else if (cycle_cnt == 4'd3) begin
            t2    <= qdiv(t2_tmp, vx_reg);
          end else if (cycle_cnt == 4'd4) begin
            t_seq <= t1 + t2;
          end else if (cycle_cnt == 4'd5) begin
            // Simplified strategy 2 (move while rotating): assume effective
            // time is max(t1, t2) as a heuristic lower bound.
            t_mix <= (t1 > t2) ? t1 : t2;
          end
        end

        COMPARE: begin
          // Choose minimum time between strategies
          if (t_seq <= t_mix)
            min_time <= t_seq;
          else
            min_time <= t_mix;
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_ANGLE;
      end

      CALC_ANGLE: begin
        // single-cycle angle calc
        next_state = CALC_DIST;
      end

      CALC_DIST: begin
        // allow 3 cycles for dist
        if (cycle_cnt >= 4'd2)
          next_state = CALC_TIMES;
      end

      CALC_TIMES: begin
        // allow several cycles for t1,t2
        if (cycle_cnt >= 4'd5)
          next_state = COMPARE;
      end

      COMPARE: begin
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule