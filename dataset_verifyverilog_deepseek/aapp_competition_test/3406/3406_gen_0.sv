module castle_danger_detector (
  input clk,
  input rst_n,
  input load,
  input [15:0] x_i,
  input [15:0] y_i,
  input is_castle_i,
  input start,
  output reg [1:0] danger_count,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  LOADING,
  CHECK_CASTLE,
  CHECK_QUAD,
  DONE
} state_t;

state_t current_state, next_state;

reg [15:0] troop_x [0:7];
reg [15:0] troop_y [0:7];
reg [2:0] troop_count;
reg [15:0] castle_x [0:3];
reg [15:0] castle_y [0:3];
reg [1:0] castle_count;
reg [3:0] castle_danger;
reg [1:0] castle_idx;
reg [2:0] quad_i, quad_j, quad_k, quad_l;
reg found_danger;
reg [15:0] ax, ay, bx, by, cx, cy, dx, dy, px, py;

function automatic logic is_collinear(
  input [15:0] x1,y1,x2,y2,x3,y3
);
  logic signed [31:0] dx1, dy1, dx2, dy2, cross;
  dx1 = x2 - x1;
  dy1 = y2 - y1;
  dx2 = x3 - x1;
  dy2 = y3 - y1;
  cross = dx1 * dy2 - dx2 * dy1;
  return (cross == 0);
endfunction

function automatic logic edges_intersect(
  input [15:0] a_x,a_y,b_x,b_y,c_x,c_y,d_x,d_y
);
  logic signed [31:0] abx, aby, acx, acy, adx, ady;
  logic signed [31:0] cdx, cdy, cax, cay, cbx, cby;
  logic signed [31:0] cross1, cross2, cross3, cross4;
  abx = b_x - a_x;
  aby = b_y - a_y;
  acx = c_x - a_x;
  acy = c_y - a_y;
  adx = d_x - a_x;
  ady = d_y - a_y;
  cross1 = abx * acy - aby * acx;
  cross2 = abx * ady - aby * adx;
  if ((cross1 > 0 && cross2 < 0) || (cross1 < 0 && cross2 > 0)) begin
    cdx = d_x - c_x;
    cdy = d_y - c_y;
    cax = a_x - c_x;
    cay = a_y - c_y;
    cbx = b_x - c_x;
    cby = b_y - c_y;
    cross3 = cdx * cay - cdy * cax;
    cross4 = cdx * cby - cdy * cbx;
    if ((cross3 > 0 && cross4 < 0) || (cross3 < 0 && cross4 > 0)) begin
      return 1'b1;
    end
  end
  return 1'b0;
endfunction

function automatic logic is_in_triangle(
  input [15:0] p_x,p_y,a_x,a_y,b_x,b_y,c_x,c_y
);
  logic signed [31:0] v0x, v0y, v1x, v1y, v2x, v2y;
  logic signed [31:0] d00, d01, d02, d11, d12, denom;
  logic signed [31:0] u, v;
  v0x = c_x - a_x;
  v0y = c_y - a_y;
  v1x = b_x - a_x;
  v1y = b_y - a_y;
  v2x = p_x - a_x;
  v2y = p_y - a_y;
  d00 = v0x * v0x + v0y * v0y;
  d01 = v0x * v1x + v0y * v1y;
  d02 = v0x * v2x + v0y * v2y;
  d11 = v1x * v1x + v1y * v1y;
  d12 = v1x * v2x + v1y * v2y;
  denom = d00 * d11 - d01 * d01;
  u = (d11 * d02 - d01 * d12);
  v = (d00 * d12 - d01 * d02);
  if (denom == 0) return 1'b0;
  u = u / denom;
  v = v / denom;
  return (u >= 0) && (v >= 0) && (u + v <= 1);
endfunction

function automatic logic is_in_quadrilateral(
  input [15:0] p_x,p_y,a_x,a_y,b_x,b_y,c_x,c_y,d_x,d_y
);
  return (is_in_triangle(p_x,p_y,a_x,a_y,b_x,b_y,c_x,c_y) ||
          is_in_triangle(p_x,p_y,a_x,a_y,c_x,c_y,d_x,d_y));
endfunction

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    danger_count <= 0;
    troop_count <= 0;
    castle_count <= 0;
    castle_danger <= 0;
    castle_idx <= 0;
    quad_i <= 0;
    quad_j <= 1;
    quad_k <= 2;
    quad_l <= 3;
    found_danger <= 0;
  end else begin
    case (current_state)
      IDLE: begin
        done <= 0;
        if (load) current_state <= LOADING;
        else if (start) begin
          current_state <= CHECK_CASTLE;
          castle_idx <= 0;
          castle_danger <= 0;
          quad_i <= 0;
          quad_j <= 1;
          quad_k <= 2;
          quad_l <= 3;
        end
      end

      LOADING: begin
        if (load) begin
          if (is_castle_i && (castle_count < 4)) begin
            castle_x[castle_count] <= x_i;
            castle_y[castle_count] <= y_i;
            castle_count <= castle_count + 1;
          end else if (!is_castle_i && (troop_count < 8)) begin
            troop_x[troop_count] <= x_i;
            troop_y[troop_count] <= y_i;
            troop_count <= troop_count + 1;
          end
        end else begin
          current_state <= IDLE;
        end
      end

      CHECK_CASTLE: begin
        if (castle_idx < castle_count) begin
          px <= castle_x[castle_idx];
          py <= castle_y[castle_idx];
          ax <= troop_x[quad_i];
          ay <= troop_y[quad_i];
          bx <= troop_x[quad_j];
          by <= troop_y[quad_j];
          cx <= troop_x[quad_k];
          cy <= troop_y[quad_k];
          dx <= troop_x[quad_l];
          dy <= troop_y[quad_l];
          current_state <= CHECK_QUAD;
          found_danger <= 0;
        end else begin
          current_state <= DONE;
        end
      end

      CHECK_QUAD: begin
        if (troop_count >= 4) begin
          if (quad_i < quad_j && quad_j < quad_k && quad_k < quad_l) begin
            if (!is_collinear(ax,ay,bx,by,cx,cy) &&
                !is_collinear(ax,ay,bx,by,dx,dy) &&
                !is_collinear(ax,ay,cx,cy,dx,dy) &&
                !is_collinear(bx,by,cx,cy,dx,dy) &&
                !edges_intersect(ax,ay,cx,cy,bx,by,dx,dy)) begin
              if (is_in_quadrilateral(px,py,ax,ay,bx,by,cx,cy,dx,dy)) begin
                found_danger <= 1;
                castle_danger[castle_idx] <= 1;
              end
            end
          end
          if (found_danger || (quad_l == troop_count-1 && quad_k == troop_count-2 && quad_j == troop_count-3 && quad_i == troop_count-4)) begin
            castle_idx <= castle_idx + 1;
            quad_i <= 0;
            quad_j <= 1;
            quad_k <= 2;
            quad_l <= 3;
            current_state <= CHECK_CASTLE;
          end
          else if (quad_l < troop_count-1) quad_l <= quad_l + 1;
          else if (quad_k < troop_count-2) begin
            quad_k <= quad_k + 1;
            quad_l <= quad_k + 2;
          end
          else if (quad_j < troop_count-3) begin
            quad_j <= quad_j + 1;
            quad_k <= quad_j + 1;
            quad_l <= quad_j + 2;
          end
          else if (quad_i < troop_count-4) begin
            quad_i <= quad_i + 1;
            quad_j <= quad_i + 1;
            quad_k <= quad_i + 2;
            quad_l <= quad_i + 3;
          end
        end else begin
          castle_idx <= castle_idx + 1;
          current_state <= CHECK_CASTLE;
        end
      end

      DONE: begin
        danger_count <= castle_danger[0] + castle_danger[1] + castle_danger[2] + castle_danger[3];
        done <= 1;
        current_state <= IDLE;
      end
    endcase
  end
end

endmodule