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

  typedef enum {IDLE, INIT, LOOP, DONE} state_t;
  state_t state;

  reg [3:0] iter;
  reg [31:0] low, high;
  wire [31:0] mid;
  wire signed [31:0] tx, ty;
  wire signed [31:0] wind_effect_x, wind_effect_y;
  wire signed [31:0] net_x, net_y;
  wire [63:0] net_x_sq, net_y_sq, sum_sq;
  wire condition;

  localparam [31:0] MAX_TIME = 32'hFFFF0000;

  assign mid = (low + high) >> 1;
  assign tx = (mid < {t_wind, 16'b0}) ? mid : {t_wind, 16'b0};
  assign ty = (mid > {t_wind, 16'b0}) ? (mid - {t_wind, 16'b0}) : 0;

  wire signed [63:0] vx_tx_product = $signed({{16{vx[15]}}, vx}) * $signed(tx);
  wire signed [63:0] wx_ty_product = $signed({{16{wx[15]}}, wx}) * $signed(ty);
  wire signed [63:0] vy_tx_product = $signed({{16{vy[15]}}, vy}) * $signed(tx);
  wire signed [63:0] wy_ty_product = $signed({{16{wy[15]}}, wy}) * $signed(ty);

  assign wind_effect_x = vx_tx_product[47:16] + wx_ty_product[47:16];
  assign wind_effect_y = vy_tx_product[47:16] + wy_ty_product[47:16];

  wire signed [31:0] x_diff_16 = (x2 - x1) << 16;
  wire signed [31:0] y_diff_16 = (y2 - y1) << 16;
  assign net_x = x_diff_16 - wind_effect_x;
  assign net_y = y_diff_16 - wind_effect_y;

  assign net_x_sq = $signed(net_x) * $signed(net_x);
  assign net_y_sq = $signed(net_y) * $signed(net_y);
  assign sum_sq = net_x_sq + net_y_sq;

  wire [31:0] v_max_16 = {v_max, 16'b0};
  wire [63:0] v_max_sq = v_max_16 * v_max_16;
  wire [63:0] mid_sq = mid * mid;
  wire [127:0] right_side_tmp = v_max_sq * mid_sq;
  wire [63:0] right_side_value = right_side_tmp[127:64];
  wire [63:0] sum_sq_int = {32'b0, sum_sq[63:32]};
  assign condition = (sum_sq_int <= right_side_value);

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      min_time <= 0;
      low <= 0;
      high <= 0;
      iter <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) state <= INIT;
        end
        INIT: begin
          low <= 0;
          high <= MAX_TIME;
          iter <= 0;
          state <= LOOP;
        end
        LOOP: begin
          if (condition) high <= mid;
          else low <= mid;
          iter <= iter + 4'd1;
          if (iter == 4'd15) state <= DONE;
        end
        DONE: begin
          min_time <= high;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule