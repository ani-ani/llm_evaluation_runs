module rescue_time_calculator(
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

  // State encoding
  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam LOOP = 2'd2;
  localparam DONE = 2'd3;

  reg [1:0] state, next_state;

  // Iteration counter (16 iterations)
  reg [4:0] iter_cnt;

  // Fixed-point bounds (Q16.16)
  reg [31:0] low_bound;   // Q16.16
  reg [31:0] high_bound;  // Q16.16
  reg [31:0] mid_t;       // Q16.16

  // Latched inputs (to keep stable during search)
  reg signed [15:0] sx, sy, dx, dy;
  reg [15:0] v_max_r, t_wind_r;
  reg signed [15:0] vx_r, vy_r, wx_r, wy_r;

  // Precomputed integer deltas
  reg signed [16:0] dx_diff_int, dy_diff_int; // (dest - start), small extension

  // Intermediate signals
  reg [31:0] t_wind_q;           // Q16.16
  reg signed [31:0] tx;          // Q16.16
  reg signed [31:0] ty;          // Q16.16
  reg signed [63:0] vx_tx;       // product
  reg signed [63:0] vy_tx;
  reg signed [63:0] wx_ty;
  reg signed [63:0] wy_ty;
  reg signed [31:0] wind_x;      // Q16.16
  reg signed [31:0] wind_y;      // Q16.16
  reg signed [47:0] dx_target_q; // Q16.16
  reg signed [47:0] dy_target_q; // Q16.16
  reg signed [31:0] net_x;       // Q16.16
  reg signed [31:0] net_y;       // Q16.16
  reg [63:0] net_x_sq;           // Q32.32
  reg [63:0] net_y_sq;           // Q32.32
  reg [63:0] dist_sq;            // Q32.32

  reg [31:0] v_max_q;            // Q16.16
  reg [63:0] v_max_sq_q;         // Q32.32 (but actually integer * 2^32)
  reg [63:0] t_sq;               // Q32.32
  reg [127:0] rhs_full;          // high precision intermediate
  reg [63:0] rhs_scaled;         // Q32.32

  reg cond; // condition result

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Main sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      min_time <= 32'd0;
      iter_cnt <= 5'd0;
      low_bound <= 32'd0;
      high_bound <= 32'd0;
      mid_t <= 32'd0;
      sx <= 16'sd0;
      sy <= 16'sd0;
      dx <= 16'sd0;
      dy <= 16'sd0;
      v_max_r <= 16'd0;
      t_wind_r <= 16'd0;
      vx_r <= 16'sd0;
      vy_r <= 16'sd0;
      wx_r <= 16'sd0;
      wy_r <= 16'sd0;
      dx_diff_int <= 17'sd0;
      dy_diff_int <= 17'sd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs
            sx <= x1;
            sy <= y1;
            dx <= x2;
            dy <= y2;
            v_max_r <= v_max;
            t_wind_r <= t_wind;
            vx_r <= vx;
            vy_r <= vy;
            wx_r <= wx;
            wy_r <= wy;
            // Compute deltas (integer)
            dx_diff_int <= $signed(x2) - $signed(x1);
            dy_diff_int <= $signed(y2) - $signed(y1);
            // Initialize bounds
            low_bound <= 32'd0;                    // 0.0
            high_bound <= 32'h000F_FFFF;           // some upper bound (~15.9999)
            iter_cnt <= 5'd0;
          end
        end

        INIT: begin
          // Nothing heavy; just prepare for loop if needed
        end

        LOOP: begin
          // 1) Compute mid time
          mid_t <= (low_bound + high_bound) >> 1; // Q16.16

          // 2) Compute tx, ty
          t_wind_q <= {t_wind_r,16'd0}; // Q16.16

          if ($signed(mid_t) <= $signed(t_wind_q)) begin
            tx <= mid_t;
            ty <= 32'sd0;
          end else begin
            tx <= t_wind_q;
            ty <= $signed(mid_t) - $signed(t_wind_q);
          end

          // 3) Wind effect: multiply (Q0 * Q16.16) -> Q16.16 via (a * t) >> 16
          vx_tx <= $signed(vx_r) * $signed(tx); // Q0 * Q16.16 = Q16.16 in 48b, but stored 64b
          vy_tx <= $signed(vy_r) * $signed(tx);
          wx_ty <= $signed(wx_r) * $signed(ty);
          wy_ty <= $signed(wy_r) * $signed(ty);

          wind_x <= $signed(vx_tx[63:16]) + $signed(wx_ty[63:16]); // shift >>16
          wind_y <= $signed(vy_tx[63:16]) + $signed(wy_ty[63:16]);

          // 4) net_x, net_y in Q16.16
          dx_target_q <= $signed(dx_diff_int) <<< 16; // Q16.16
          dy_target_q <= $signed(dy_diff_int) <<< 16;

          net_x <= $signed(dx_target_q[31:0]) - wind_x;
          net_y <= $signed(dy_target_q[31:0]) - wind_y;

          // 5) Distance squared: (net_x^2 + net_y^2), Q16.16^2 = Q32.32
          net_x_sq <= $signed(net_x) * $signed(net_x);
          net_y_sq <= $signed(net_y) * $signed(net_y);
          dist_sq <= net_x_sq + net_y_sq;

          // 6) RHS = (v_max^2 * t^2)
          // v_max_q = v_max (Q0) -> Q16.16
          v_max_q <= {v_max_r,16'd0};
          v_max_sq_q <= $unsigned(v_max_q) * $unsigned(v_max_q); // Q32.32

          t_sq <= $unsigned(mid_t) * $unsigned(mid_t); // Q32.32

          // Multiply: Q32.32 * Q32.32 -> Q64.64, then >>32 -> Q32.32
          rhs_full <= $unsigned(v_max_sq_q) * $unsigned(t_sq);
          rhs_scaled <= rhs_full[95:32];

          // 7) Compare and update bounds
          cond <= (dist_sq <= rhs_scaled);

          if (cond)
            high_bound <= mid_t; // feasible time
          else
            low_bound <= mid_t;  // infeasible, increase lower bound

          // 8) Increment iteration counter
          iter_cnt <= iter_cnt + 1'b1;
        end

        DONE: begin
          done <= 1'b1;
          min_time <= high_bound; // Q16.16 result
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
          next_state = LOOP;
      end
      INIT: begin
        next_state = LOOP;
      end
      LOOP: begin
        if (iter_cnt == 5'd16)
          next_state = DONE;
        else
          next_state = LOOP;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule