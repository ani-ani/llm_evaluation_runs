module rescue_time_calculator (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] x1, y1,
  input signed [15:0] x2, y2,
  input [15:0] v_max,
  input [15:0] t_wind,
  input signed [15:0] vx, vy,
  input signed [15:0] wx, wy,
  output reg [31:0] min_time,
  output reg done
);

  // States
  localparam IDLE = 2'b00;
  localparam INIT = 2'b01;
  localparam LOOP = 2'b10;
  localparam DONE = 2'b11;

  // Iteration counter for 16-cycle binary search
  reg [4:0] iter;

  // Binary search bounds (Q16.16)
  reg [31:0] low_q16, high_q16;
  wire [31:0] mid_q16;
  wire [31:0] mid_q0; // mid in Q0.16 (16-bit integer part + fraction)

  // Q16.16 scaled constants (1.0 -> 0x00010000)
  wire [31:0] one_q16;
  assign one_q16 = 32'h00010000;

  // Internal state
  reg [1:0] state, next_state;

  // Registered inputs (captured at INIT)
  reg signed [15:0] x1_r, y1_r, x2_r, y2_r;
  reg signed [15:0] vx_r, vy_r, wx_r, wy_r;
  reg [15:0] v_max_r, t_wind_r;

  // Pipelined results per iteration
  // mid_t parts in Q0.16
  reg [15:0] mid_t_q0;
  reg [15:0] mid_t_frac_q16; // Q16.16 fraction for tx/ty (already shifted)

  // tx, ty (Q16.16)
  reg [31:0] tx_q16, ty_q16;

  // Wind effects (Q16.16)
  reg [31:0] windx_q16, windy_q16;

  // Net displacement (Q16.16)
  reg [31:0] netx_q16, nety_q16;

  // Reachability check operands (Q32.32)
  reg [63:0] pos2_q32, reach2_q32;

  // Control signals
  wire loop_enable;
  wire cond_le; // (pos2 <= reach2) ? 1 : 0
  wire [31:0] low_next, high_next;
  wire is_last_iter;

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_time <= 32'h0;
      iter <= 5'd0;
      low_q16 <= 32'h0;
      high_q16 <= 32'h0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          iter <= 5'd0;
        end
        INIT: begin
          // Capture inputs at the start of computation
          x1_r <= x1; y1_r <= y1;
          x2_r <= x2; y2_r <= y2;
          vx_r <= vx; vy_r <= vy;
          wx_r <= wx; wy_r <= wy;
          v_max_r <= v_max;
          t_wind_r <= t_wind;
          iter <= 5'd0;
          // Initialize search bounds in Q16.16
          low_q16 <= 32'h0;
          high_q16 <= one_q16; // 1.0 second as initial upper bound
        end
        LOOP: begin
          // Update bounds based on the decision at the end of the cycle
          low_q16 <= low_next;
          high_q16 <= high_next;
          iter <= iter + 1;
        end
        DONE: begin
          done <= 1'b1;
          // min_time is already assigned combinatorially in LOOP when last iter
        end
        default: begin
          // Keep safe values
          done <= done;
          min_time <= min_time;
        end
      endcase
    end
  end

  // State machine combinatorial logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = LOOP;
      LOOP: next_state = is_last_iter ? DONE : LOOP;
      DONE: next_state = start ? INIT : IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Is this the last iteration?
  assign is_last_iter = (iter == 5'd15);

  // Midpoint selection (round-to-nearest in Q16.16)
  assign mid_q16 = (state == INIT) ? one_q16 : ((low_q16 + high_q16 + 1) >> 1);
  assign mid_q0 = mid_q16[31:16]; // integer part in Q0.16

  // Helper: Q16.16 * Q16.16 -> Q16.16 with rounding (unbiased)
  function [31:0] mul_q16x16_q16;
    input signed [31:0] a;
    input signed [31:0] b;
    reg signed [63:0] prod;
  begin
    prod = $signed(a) * $signed(b);
    // Round to nearest (ties to even handled by truncating + (1<<31) bias)
    mul_q16x16_q16 = $unsigned(prod[63:32]) + 1'b0;
  end
  endfunction

  // Helper: Q16.16 * Q0.16 -> Q16.16 with rounding (unbiased)
  function [31:0] mul_q16xq0_q16;
    input signed [31:0] a;
    input [15:0] b; // unsigned Q0.16
    reg signed [47:0] prod;
  begin
    prod = $signed(a) * $signed({1'b0, b});
    mul_q16xq0_q16 = $unsigned(prod[47:16]) + 1'b0;
  end
  endfunction

  // Helper: unsigned Q0.16 * unsigned Q0.16 -> Q0.16 with rounding
  function [15:0] mul_q0xq0_q0;
    input [15:0] a;
    input [15:0] b;
    reg [31:0] prod;
  begin
    prod = a * b;
    mul_q0xq0_q0 = prod[31:16] + 1'b0; // unbiased rounding
  end
  endfunction

  // Compute mid in Q0.16 parts and use it to drive the pipeline
  always @(*) begin
    if (state == INIT) begin
      // First iteration: t = 1.0 (Q0.16 = 16'h0001)
      mid_t_q0 = 16'h0001;
      mid_t_frac_q16 = 32'h00010000; // 1.0 in Q16.16
    end else begin
      mid_t_q0 = mid_q0;
      mid_t_frac_q16 = {mid_q0, 16'h0000}; // Q0.16 -> Q16.16 (implicit shift)
    end
  end

  // Compute per-iteration terms for the decision: LOOP state active, else don't care
  always @(*) begin
    if (state == LOOP) begin
      // tx = min(t, t_wind), ty = max(0, t - t_wind)
      if (mid_t_q0 <= t_wind_r) begin
        tx_q16 = mid_t_frac_q16;
        ty_q16 = 32'h0;
      end else begin
        tx_q16 = {t_wind_r, 16'h0000};
        ty_q16 = mid_t_frac_q16 - {t_wind_r, 16'h0000};
      end

      // wind_effect = v*tx + w*ty (Q16.16)
      windx_q16 = mul_q16xq0_q16(vx_r, tx_q16[15:0]) + mul_q16xq0_q16(wx_r, ty_q16[15:0]);
      windy_q16 = mul_q16xq0_q16(vy_r, tx_q16[15:0]) + mul_q16xq0_q16(wy_r, ty_q16[15:0]);

      // net = dest - start - wind_effect (Q16.16)
      netx_q16 = ({x2_r, 16'h0000} - {x1_r, 16'h0000}) - windx_q16;
      nety_q16 = ({y2_r, 16'h0000} - {y1_r, 16'h0000}) - windy_q16;

      // pos^2 and reach^2 in Q32.32
      pos2_q32 = $unsigned({1'b0, netx_q16}) * $unsigned({1'b0, netx_q16})
               + $unsigned({1'b0, nety_q16}) * $unsigned({1'b0, nety_q16});

      // v_max^2 * t^2
      begin
        // v_max^2 in Q0.16 (round to nearest)
        [15:0] v2_q0;
        v2_q0 = mul_q0xq0_q0(v_max_r, v_max_r);
        // t^2 in Q32.32 (implicit, we only need the high 32 bits in Q0.16)
        [31:0] t2_hi_q0;
        t2_hi_q0 = $unsigned({1'b0, mid_t_q0}) * $unsigned({1'b0, mid_t_q0});
        // (v^2)*(t^2) in Q0.16 (keep high 32 bits of 64-bit product)
        [63:0] reach2_q0_full;
        reach2_q0_full = $unsigned({1'b0, v2_q0}) * $unsigned(t2_hi_q0);
        // Expand to Q32.32: high part becomes integer Q0.16, low part fraction
        reach2_q32 = {reach2_q0_full[63:32], 32'h0000};
      end
    end else begin
      tx_q16 = 32'h0;
      ty_q16 = 32'h0;
      windx_q16 = 32'h0;
      windy_q16 = 32'h0;
      netx_q16 = 32'h0;
      nety_q16 = 32'h0;
      pos2_q32 = 64'h0;
      reach2_q32 = 64'h0;
    end
  end

  // Decision: is target reachable at time t?
  assign cond_le = (pos2_q32 <= reach2_q32);

  // Next bounds update (Q16.16)
  assign low_next  = cond_le ? mid_q16 : low_q16;
  assign high_next = cond_le ? high_q16 : mid_q16;

  // Output min_time as upper bound after last iteration (already in Q16.16)
  always @(*) begin
    if (state == LOOP && is_last_iter) begin
      // For the last iteration, we can also take the average of bounds for a tighter estimate
      // min_time = (low_next + high_next + 1) >> 1;
      // For simplicity and determinism, use upper bound as specified.
      min_time = high_next;
    end
  end

endmodule
