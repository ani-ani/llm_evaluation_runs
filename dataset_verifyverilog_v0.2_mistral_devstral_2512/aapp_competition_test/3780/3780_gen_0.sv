module rescue_planner (
  input clk,
  input rst_n,
  input start,
  input signed [31:0] dx,
  input signed [31:0] dy,
  input signed [31:0] v_max,
  input signed [31:0] t_wind,
  input signed [31:0] vx,
  input signed [31:0] vy,
  input signed [31:0] wx,
  input signed [31:0] wy,
  output reg done,
  output reg [31:0] result
);

  // Constants
  localparam IDLE = 3'b000;
  localparam SETUP = 3'b001;
  localparam CALC_WIND = 3'b010;
  localparam CHECK_DIST = 3'b011;
  localparam UPDATE = 3'b100;
  localparam ITERATE = 3'b101;
  localparam DONE = 3'b110;

  localparam MAX_TIME = 32'h1E848000; // 200000.0 in Q16.16
  localparam ITERATIONS = 5'd32;

  // State machine
  reg [2:0] state = IDLE;

  // Binary search variables
  reg [31:0] low = 0;
  reg [31:0] high = MAX_TIME;
  reg [31:0] mid;
  reg [4:0] iter_count = 0;

  // Wind displacement
  reg [31:0] wx_displ, wy_displ;

  // Distance check variables
  reg [31:0] dx_rel, dy_rel;
  reg [63:0] dx_sq, dy_sq, dist_sq;
  reg [63:0] v_max_sq, t_sq, reach_sq;

  // Scaling factor (divide by 16)
  localparam SCALE = 4;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      iter_count <= 0;
      low <= 0;
      high <= MAX_TIME;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
            done <= 0;
          end
        end

        SETUP: begin
          low <= 0;
          high <= MAX_TIME;
          iter_count <= ITERATIONS;
          state <= CALC_WIND;
        end

        CALC_WIND: begin
          mid <= (low + high) >>> 1;
          
          // Calculate wind displacement
          if (mid < t_wind) begin
            wx_displ <= (vx * mid) >>> SCALE;
            wy_displ <= (vy * mid) >>> SCALE;
          end else begin
            wx_displ <= (vx * t_wind + wx * (mid - t_wind)) >>> SCALE;
            wy_displ <= (vy * t_wind + wy * (mid - t_wind)) >>> SCALE;
          end
          
          state <= CHECK_DIST;
        end

        CHECK_DIST: begin
          // Calculate relative position
          dx_rel <= dx - wx_displ;
          dy_rel <= dy - wy_displ;
          
          // Calculate squared distance
          dx_sq <= $signed(dx_rel) * $signed(dx_rel);
          dy_sq <= $signed(dy_rel) * $signed(dy_rel);
          dist_sq <= dx_sq + dy_sq;
          
          // Calculate squared reachability
          v_max_sq <= $signed(v_max) * $signed(v_max);
          t_sq <= $signed(mid) * $signed(mid);
          reach_sq <= v_max_sq * t_sq;
          
          state <= UPDATE;
        end

        UPDATE: begin
          if (dist_sq <= reach_sq) begin
            high <= mid;
          end else begin
            low <= mid;
          end
          
          state <= ITERATE;
        end

        ITERATE: begin
          iter_count <= iter_count - 1;
          
          if (iter_count > 0) begin
            state <= CALC_WIND;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          result <= mid;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule