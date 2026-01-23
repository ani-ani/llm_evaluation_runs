module phaser_optimal #(
  parameter N = 8,
  parameter MAX_CORNERS = 4*N,
  parameter MAX_RAYS = N*(4*N-1)/2
)(
  input clk,
  input rst_n,
  input start,
  input [3:0] room_count,
  input [N-1:0][31:0] room_x1,
  input [N-1:0][31:0] room_y1,
  input [N-1:0][31:0] room_x2,
  input [N-1:0][31:0] room_y2,
  input [31:0] beam_length,
  output reg [3:0] max_rooms,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    EXTRACT_CORNERS,
    GENERATE_RAYS,
    INTERSECT_CHECK,
    UPDATE_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Corner storage (4 corners per room)
  reg [31:0] corners_x [0:MAX_CORNERS-1];
  reg [31:0] corners_y [0:MAX_CORNERS-1];

  // Ray generation counters
  reg [7:0] p1_idx;
  reg [7:0] p2_idx;
  reg [3:0] room_idx;

  // Current ray parameters
  reg [31:0] ray_x0, ray_y0;
  reg [31:0] ray_x1, ray_y1;
  reg [3:0] hit_count;

  // Fixed-point arithmetic helpers
  function [31:0] fp_mul(input [31:0] a, input [31:0] b);
    reg [31:0] result;
    result = (a * b) >>> 16;
    return result;
  endfunction

  function [31:0] fp_div(input [31:0] a, input [31:0] b);
    reg [31:0] result;
    if (b == 0) begin
      result = 0;
    end else begin
      result = (a << 16) / b;
    end
    return result;
  endfunction

  // Compute normalized direction vector and scale by beam_length
  function void compute_ray_end(
    input [31:0] x0, input [31:0] y0,
    input [31:0] x1, input [31:0] y1,
    input [31:0] length,
    output [31:0] x_end, output [31:0] y_end
  );
    reg [31:0] dx, dy, dist, scale;
    dx = x1 - x0;
    dy = y1 - y0;
    dist = fp_mul(dx, dx) + fp_mul(dy, dy);
    if (dist == 0) begin
      x_end = x0 + length;
      y_end = y0;
    end else begin
      scale = fp_div(length, dist);
      x_end = x0 + fp_mul(dx, scale);
      y_end = y0 + fp_mul(dy, scale);
    end
  endfunction

  // Check if segment (x0,y0)-(x1,y1) intersects rectangle (rx1,ry1)-(rx2,ry2)
  function logic check_intersection(
    input [31:0] x0, input [31:0] y0,
    input [31:0] x1, input [31:0] y1,
    input [31:0] rx1, input [31:0] ry1,
    input [31:0] rx2, input [31:0] ry2
  );
    reg [31:0] t0, t1, t2, t3, t4, t5, t6, t7;
    reg [31:0] denom, num1, num2, num3, num4;
    reg logic inside1, inside2;

    // Check if endpoints are inside rectangle
    inside1 = (x0 >= rx1 && x0 <= rx2 && y0 >= ry1 && y0 <= ry2);
    inside2 = (x1 >= rx1 && x1 <= rx2 && y1 >= ry1 && y1 <= ry2);
    if (inside1 || inside2) return 1;

    // Check if segment crosses rectangle edges
    denom = (x0 - x1) * (ry1 - ry2) - (y0 - y1) * (rx1 - rx2);
    if (denom == 0) return 0;

    num1 = (x0 - rx1) * (ry1 - ry2) - (y0 - ry1) * (rx1 - rx2);
    num2 = (x0 - rx2) * (ry1 - ry2) - (y0 - ry1) * (rx1 - rx2);
    num3 = (x0 - rx1) * (ry1 - ry2) - (y0 - ry2) * (rx1 - rx2);
    num4 = (x0 - rx2) * (ry1 - ry2) - (y0 - ry2) * (rx1 - rx2);

    t0 = fp_div(num1, denom);
    t1 = fp_div(num2, denom);
    t2 = fp_div(num3, denom);
    t3 = fp_div(num4, denom);

    if ((t0 >= 0 && t0 <= 1) || (t1 >= 0 && t1 <= 1) ||
        (t2 >= 0 && t2 <= 1) || (t3 >= 0 && t3 <= 1)) return 1;

    return 0;
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      max_rooms <= 0;
      p1_idx <= 0;
      p2_idx <= 0;
      room_idx <= 0;
      hit_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = EXTRACT_CORNERS;
      end

      EXTRACT_CORNERS: begin
        next_state = GENERATE_RAYS;
      end

      GENERATE_RAYS: begin
        if (p1_idx == MAX_CORNERS-1 && p2_idx == MAX_CORNERS-1) begin
          next_state = DONE;
        end else if (p2_idx == MAX_CORNERS-1) begin
          p1_idx = p1_idx + 1;
          p2_idx = p1_idx + 1;
        end else begin
          p2_idx = p2_idx + 1;
        end
      end

      INTERSECT_CHECK: begin
        if (room_idx == room_count-1) begin
          next_state = UPDATE_MAX;
        end else begin
          room_idx = room_idx + 1;
        end
      end

      UPDATE_MAX: begin
        next_state = GENERATE_RAYS;
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Corner extraction logic
  always @(posedge clk) begin
    if (current_state == EXTRACT_CORNERS) begin
      for (int i = 0; i < N; i = i + 1) begin
        corners_x[4*i]   <= room_x1[i];
        corners_y[4*i]   <= room_y1[i];
        corners_x[4*i+1] <= room_x1[i];
        corners_y[4*i+1] <= room_y2[i];
        corners_x[4*i+2] <= room_x2[i];
        corners_y[4*i+2] <= room_y1[i];
        corners_x[4*i+3] <= room_x2[i];
        corners_y[4*i+3] <= room_y2[i];
      end
    end
  end

  // Ray generation and intersection checking
  always @(posedge clk) begin
    if (current_state == GENERATE_RAYS) begin
      ray_x0 <= corners_x[p1_idx];
      ray_y0 <= corners_y[p1_idx];
      ray_x1 <= corners_x[p2_idx];
      ray_y1 <= corners_y[p2_idx];
      compute_ray_end(ray_x0, ray_y0, ray_x1, ray_y1, beam_length, ray_x1, ray_y1);
      hit_count <= 0;
      room_idx <= 0;
      next_state = INTERSECT_CHECK;
    end
  end

  always @(posedge clk) begin
    if (current_state == INTERSECT_CHECK) begin
      if (check_intersection(ray_x0, ray_y0, ray_x1, ray_y1,
                            room_x1[room_idx], room_y1[room_idx],
                            room_x2[room_idx], room_y2[room_idx])) begin
        hit_count <= hit_count + 1;
      end
    end
  end

  always @(posedge clk) begin
    if (current_state == UPDATE_MAX) begin
      if (hit_count > max_rooms) begin
        max_rooms <= hit_count;
      end
    end
  end

  always @(posedge clk) begin
    if (current_state == DONE) begin
      done <= 1;
    end else if (current_state != IDLE) begin
      done <= 0;
    end
  end

endmodule