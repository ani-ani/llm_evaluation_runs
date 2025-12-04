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

  typedef enum {IDLE, CALC_ANGLE, CALC_DIST, CALC_TIMES, COMPARE, DONE} state_t;
  state_t state;

  reg [31:0] angle, abs_angle, distance, t_rotate, t_move;
  reg [31:0] raw_x, raw_y;
  reg [63:0] sum_sq;
  reg [31:0] t_strat_a, t_strat_b;

  // Fixed-point Q16.16 absolute value
  function [31:0] fp_abs(input [31:0] val);
    begin
      fp_abs = val[31] ? -val : val;
    end
  endfunction

  // Fixed-point atan2 approximation
  function [31:0] fp_atan2(input [31:0] y, x);
    reg [63:0] ratio;
    begin
      if (x == 0) fp_atan2 = y[31] ? 32'hC90FDAA2 : 32'h3C90FDAA2; // ±pi/2 
      else begin
        ratio = (y << 16) / x;
        if      (ratio < 32'h0000B505) fp_atan2 = ratio;            // Small angle approx
        else if (ratio < 32'h00016A0A) fp_atan2 = 32'h0000C90F;    // ~45°
        else fp_atan2 = 32'h0000FFFF;                              // ~89°
        if (x[31]) fp_atan2 = y[31] ? fp_atan2 - 32'h006487ED : fp_atan2 + 32'h006487ED; // Adjust quadrant
        else if (y[31]) fp_atan2 = 32'hFFFFFFFF - fp_atan2 + 1;    // Negative angle
      end
    end
  endfunction

  // Fixed-point square root
  function [31:0] fp_sqrt(input [63:0] val);
    reg [31:0] res;
    reg [33:0] a;
    reg [33:0] q;
    integer i;
    begin
      a = val >> 32;
      q = 0;
      for (i = 0; i < 17; i = i + 1) begin
        q = {q[31:0], 2'b01};
        if (q <= a) begin
          a = a - q;
          q = q + 1;
        end else begin
          q = q - 1;
        end
        a = {a[31:0], 2'b00};
      end
      res = q[31:0];
      fp_sqrt = {res[15:0], 16'h0000}; // Keep fractional precision
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_time <= 0;
      angle <= 0;
      distance <= 0;
      t_strat_a <= 0;
      t_strat_b <= 0;
    end else begin
      done <= 0;

      case (state)
        IDLE: begin
          if (start) begin
            raw_x <= x_pos;
            raw_y <= y_pos;
            state <= CALC_ANGLE;
          end
        end

        CALC_ANGLE: begin
          angle <= fp_atan2(raw_y, raw_x);
          state <= CALC_DIST;
        end

        CALC_DIST: begin
          sum_sq <= (raw_x * raw_x) + (raw_y * raw_y);
          distance <= fp_sqrt(sum_sq);
          state <= CALC_TIMES;
        end

        CALC_TIMES: begin
          abs_angle <= fp_abs(angle);
          t_rotate <= (abs_angle << 16) / omega;
          t_move <= (distance << 16) / velocity;
          t_strat_a <= t_rotate + t_move;
          t_strat_b <= (t_rotate > t_move) ? t_rotate : t_move;
          state <= COMPARE;
        end

        COMPARE: begin
          min_time <= (t_strat_a < t_strat_b) ? t_strat_a : t_strat_b;
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule