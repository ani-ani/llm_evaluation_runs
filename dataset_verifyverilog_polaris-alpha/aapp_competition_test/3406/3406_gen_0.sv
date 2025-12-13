module castle_danger_detector(
  input              clk,
  input              rst_n,
  input              load,
  input      [15:0]  x_i,
  input      [15:0]  y_i,
  input              is_castle_i,
  input              start,
  output reg [1:0]   danger_count,
  output reg         done
);

  // Parameters
  localparam MAX_TROOPS   = 8;
  localparam MAX_CASTLES  = 4;

  // Storage for troops and castles
  reg [15:0] troop_x [0:MAX_TROOPS-1];
  reg [15:0] troop_y [0:MAX_TROOPS-1];
  reg [15:0] castle_x[0:MAX_CASTLES-1];
  reg [15:0] castle_y[0:MAX_CASTLES-1];

  reg [3:0] troop_cnt;
  reg [2:0] castle_cnt;

  // FSM States
  typedef enum logic [2:0] {
    ST_IDLE         = 3'd0,
    ST_LOADING      = 3'd1,
    ST_PREPARE      = 3'd2,
    ST_CHECK_CASTLE = 3'd3,
    ST_CHECK_QUAD   = 3'd4,
    ST_DONE         = 3'd5
  } state_t;

  state_t state, next_state;

  // Combination indices for selecting 4 troops
  reg [2:0] i0, i1, i2, i3;

  // Indices for castles
  reg [1:0] cur_castle_idx;

  // Flags
  reg [MAX_CASTLES-1:0] castle_danger;
  reg                   any_valid_quad_for_castle;

  // Latched current castle coordinates
  reg [15:0] cx, cy;

  // Convenience wires for current quad troop coordinates
  reg [15:0] ax, ay, bx, by, ex, ey, dx, dy; // A,B,C,D points

  // Internal signals for geometric checks
  reg  non_degenerate;
  reg  no_self_intersect;
  reg  point_inside;

  // ----------------------------
  // Loading logic
  // ----------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      troop_cnt  <= 4'd0;
      castle_cnt <= 3'd0;
    end else begin
      if (state == ST_IDLE || state == ST_LOADING) begin
        if (load) begin
          if (is_castle_i) begin
            if (castle_cnt < MAX_CASTLES) begin
              castle_x[castle_cnt] <= x_i;
              castle_y[castle_cnt] <= y_i;
              castle_cnt <= castle_cnt + 3'd1;
            end
          end else begin
            if (troop_cnt < MAX_TROOPS) begin
              troop_x[troop_cnt] <= x_i;
              troop_y[troop_cnt] <= y_i;
              troop_cnt <= troop_cnt + 4'd1;
            end
          end
        end
      end
    end
  end

  // ----------------------------
  // FSM sequential
  // ----------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // ----------------------------
  // FSM combinational next state
  // ----------------------------

  always @* begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (load) begin
          next_state = ST_LOADING;
        end else if (start) begin
          next_state = ST_PREPARE;
        end
      end

      ST_LOADING: begin
        if (start) begin
          next_state = ST_PREPARE;
        end
      end

      ST_PREPARE: begin
        // Prepare to iterate castles and combinations
        next_state = (castle_cnt != 0 && troop_cnt >= 4) ? ST_CHECK_CASTLE : ST_DONE;
      end

      ST_CHECK_CASTLE: begin
        // Decide if we move directly to DONE (no castles) or start checking quads
        if (cur_castle_idx >= castle_cnt) begin
          next_state = ST_DONE;
        end else begin
          next_state = ST_CHECK_QUAD;
        end
      end

      ST_CHECK_QUAD: begin
        // Stay in CHECK_QUAD while scanning combinations
        // Move to CHECK_CASTLE when either a valid quad found or all combos exhausted
        if (any_valid_quad_for_castle) begin
          // Found; go to next castle
          if (cur_castle_idx + 1 >= castle_cnt)
            next_state = ST_DONE;
          else
            next_state = ST_CHECK_CASTLE;
        end else begin
          // If we reached end of combinations (encoded by i0,i1,i2,i3 logic), transition in seq block
          // Here, combinationally default stay; seq logic will update flags and cause change next cycle
          next_state = ST_CHECK_QUAD;
        end
      end

      ST_DONE: begin
        if (!start && !load) begin
          next_state = ST_IDLE;
        end
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // ----------------------------
  // Combination generator and control
  // ----------------------------

  // Generate next combination of 4 distinct troop indices (i0 < i1 < i2 < i3)
  // Simple lexicographic incrementer
  task automatic next_combination;
    begin
      if (i0 == troop_cnt-4 && i1 == troop_cnt-3 && i2 == troop_cnt-2 && i3 == troop_cnt-1) begin
        // Reached last combination; keep at max (will be interpreted as done externally)
      end else begin
        if (i3 + 1 < troop_cnt) begin
          i3 = i3 + 1;
        end else if (i2 + 2 < troop_cnt) begin
          i2 = i2 + 1;
          i3 = i2 + 1;
        end else if (i1 + 3 < troop_cnt) begin
          i1 = i1 + 1;
          i2 = i1 + 1;
          i3 = i2 + 1;
        end else if (i0 + 4 <= troop_cnt) begin
          i0 = i0 + 1;
          i1 = i0 + 1;
          i2 = i1 + 1;
          i3 = i2 + 1;
        end
      end
    end
  endtask

  function automatic bit is_last_combination;
    begin
      is_last_combination = (i0 == troop_cnt-4) && (i1 == troop_cnt-3) && (i2 == troop_cnt-2) && (i3 == troop_cnt-1);
    end
  endfunction

  // ----------------------------
  // Geometry helper functions
  // ----------------------------

  // Cross product (P1P2 x P1P3) using signed arithmetic
  function automatic signed [33:0] cross2d(
    input signed [15:0] x1, input signed [15:0] y1,
    input signed [15:0] x2, input signed [15:0] y2,
    input signed [15:0] x3, input signed [15:0] y3
  );
    signed [16:0] dx1, dy1, dx2, dy2;
    signed [33:0] t1, t2;
    begin
      dx1 = x2 - x1;
      dy1 = y2 - y1;
      dx2 = x3 - x1;
      dy2 = y3 - y1;
      t1  = dx1 * dy2;
      t2  = dy1 * dx2;
      cross2d = t1 - t2;
    end
  endfunction

  // Orientation sign
  function automatic signed [1:0] orient_sign(
    input signed [15:0] x1, input signed [15:0] y1,
    input signed [15:0] x2, input signed [15:0] y2,
    input signed [15:0] x3, input signed [15:0] y3
  );
    signed [33:0] c;
    begin
      c = cross2d(x1,y1,x2,y2,x3,y3);
      if (c > 0) orient_sign = 2'sd1;
      else if (c < 0) orient_sign = -2'sd1;
      else orient_sign = 2'sd0;
    end
  endfunction

  // Check if point P lies on segment AB (inclusive)
  function automatic bit on_segment(
    input signed [15:0] ax, input signed [15:0] ay,
    input signed [15:0] bx, input signed [15:0] by,
    input signed [15:0] px, input signed [15:0] py
  );
    signed [33:0] c;
    begin
      c = cross2d(ax,ay,bx,by,px,py);
      if (c != 0)
        on_segment = 1'b0;
      else begin
        if ( (px >= (ax < bx ? ax : bx)) && (px <= (ax > bx ? ax : bx)) &&
             (py >= (ay < by ? ay : by)) && (py <= (ay > by ? ay : by)) )
          on_segment = 1'b1;
        else
          on_segment = 1'b0;
      end
    end
  endfunction

  // Segment intersection (proper or touching)
  function automatic bit segments_intersect(
    input signed [15:0] ax, input signed [15:0] ay,
    input signed [15:0] bx, input signed [15:0] by,
    input signed [15:0] cx, input signed [15:0] cy,
    input signed [15:0] dx, input signed [15:0] dy
  );
    signed [1:0] o1,o2,o3,o4;
    begin
      o1 = orient_sign(ax,ay,bx,by,cx,cy);
      o2 = orient_sign(ax,ay,bx,by,dx,dy);
      o3 = orient_sign(cx,cy,dx,dy,ax,ay);
      o4 = orient_sign(cx,cy,dx,dy,bx,by);

      if (o1 != o2 && o3 != o4)
        segments_intersect = 1'b1;
      else if (o1 == 0 && on_segment(ax,ay,bx,by,cx,cy))
        segments_intersect = 1'b1;
      else if (o2 == 0 && on_segment(ax,ay,bx,by,dx,dy))
        segments_intersect = 1'b1;
      else if (o3 == 0 && on_segment(cx,cy,dx,dy,ax,ay))
        segments_intersect = 1'b1;
      else if (o4 == 0 && on_segment(cx,cy,dx,dy,bx,by))
        segments_intersect = 1'b1;
      else
        segments_intersect = 1'b0;
    end
  endfunction

  // Check non-degenerate quadrilateral: no 3 collinear on same edge sequence and no self-intersection
  function automatic bit quad_non_degenerate(
    input signed [15:0] ax, input signed [15:0] ay,
    input signed [15:0] bx, input signed [15:0] by,
    input signed [15:0] cx, input signed [15:0] cy,
    input signed [15:0] dx, input signed [15:0] dy
  );
    bit col_abc, col_bcd, col_cda, col_dab;
    bit self_int;
    begin
      col_abc = (cross2d(ax,ay,bx,by,cx,cy) == 0);
      col_bcd = (cross2d(bx,by,cx,cy,dx,dy) == 0);
      col_cda = (cross2d(cx,cy,dx,dy,ax,ay) == 0);
      col_dab = (cross2d(dx,dy,ax,ay,bx,by) == 0);

      self_int = segments_intersect(ax,ay,cx,cy,bx,by,dx,dy);

      quad_non_degenerate = !(col_abc || col_bcd || col_cda || col_dab || self_int);
    end
  endfunction

  // Point in quadrilateral (convex or concave) using orientation method
  function automatic bit point_in_quad(
    input signed [15:0] px, input signed [15:0] py,
    input signed [15:0] ax, input signed [15:0] ay,
    input signed [15:0] bx, input signed [15:0] by,
    input signed [15:0] cx, input signed [15:0] cy,
    input signed [15:0] dx, input signed [15:0] dy
  );
    // Check inside polygon ABCD in order A-B-C-D using winding/half-plane
    signed [33:0] c1,c2,c3,c4;
    bit has_pos, has_neg;
    begin
      c1 = cross2d(ax,ay,bx,by,px,py);
      c2 = cross2d(bx,by,cx,cy,px,py);
      c3 = cross2d(cx,cy,dx,dy,px,py);
      c4 = cross2d(dx,dy,ax,ay,px,py);

      has_pos = (c1 > 0) || (c2 > 0) || (c3 > 0) || (c4 > 0);
      has_neg = (c1 < 0) || (c2 < 0) || (c3 < 0) || (c4 < 0);

      if (!(has_pos && has_neg)) begin
        // All on one side or on edges => inside or on border
        point_in_quad = 1'b1;
      end else begin
        point_in_quad = 1'b0;
      end
    end
  endfunction

  // ----------------------------
  // Sequential control and outputs
  // ----------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_castle_idx             <= 2'd0;
      castle_danger              <= {MAX_CASTLES{1'b0}};
      danger_count               <= 2'd0;
      done                       <= 1'b0;
      i0                         <= 3'd0;
      i1                         <= 3'd1;
      i2                         <= 3'd2;
      i3                         <= 3'd3;
      any_valid_quad_for_castle  <= 1'b0;
      cx                         <= 16'd0;
      cy                         <= 16'd0;
    end else begin
      case (state)
        ST_IDLE: begin
          done                      <= 1'b0;
          danger_count              <= 2'd0;
          castle_danger             <= {MAX_CASTLES{1'b0}};
          cur_castle_idx            <= 2'd0;
          any_valid_quad_for_castle <= 1'b0;
          // indices left don't care until PREPARE
        end

        ST_LOADING: begin
          done <= 1'b0;
        end

        ST_PREPARE: begin
          done                      <= 1'b0;
          cur_castle_idx            <= 2'd0;
          castle_danger             <= {MAX_CASTLES{1'b0}};
          danger_count              <= 2'd0;
          any_valid_quad_for_castle <= 1'b0;
          // Initialize first combination if possible
          if (troop_cnt >= 4 && castle_cnt != 0) begin
            i0 <= 3'd0;
            i1 <= 3'd1;
            i2 <= 3'd2;
            i3 <= 3'd3;
          end
        end

        ST_CHECK_CASTLE: begin
          done <= 1'b0;
          any_valid_quad_for_castle <= 1'b0;

          if (cur_castle_idx < castle_cnt) begin
            cx <= castle_x[cur_castle_idx];
            cy <= castle_y[cur_castle_idx];
            // Reset combination for this castle
            if (troop_cnt >= 4) begin
              i0 <= 3'd0;
              i1 <= 3'd1;
              i2 <= 3'd2;
              i3 <= 3'd3;
            end
          end
        end

        ST_CHECK_QUAD: begin
          done <= 1'b0;

          // Load current quad points
          ax <= troop_x[i0];
          ay <= troop_y[i0];
          bx <= troop_x[i1];
          by <= troop_y[i1];
          ex <= troop_x[i2];
          ey <= troop_y[i2];
          dx <= troop_x[i3];
          dy <= troop_y[i3];

          // Evaluate geometry combinationally (using functions)
          non_degenerate   <= quad_non_degenerate(ax,ay,bx,by,ex,ey,dx,dy);
          point_inside     <= point_in_quad(cx,cy,ax,ay,bx,by,ex,ey,dx,dy);
          no_self_intersect<= 1'b1; // included in quad_non_degenerate

          // If this quad is valid and contains castle, mark and move on
          if (!any_valid_quad_for_castle && quad_non_degenerate(ax,ay,bx,by,ex,ey,dx,dy) && point_in_quad(cx,cy,ax,ay,bx,by,ex,ey,dx,dy)) begin
            any_valid_quad_for_castle <= 1'b1;
            castle_danger[cur_castle_idx] <= 1'b1;
            danger_count <= danger_count + 2'd1;
            // Advance to next castle
            if (cur_castle_idx + 1 < castle_cnt) begin
              cur_castle_idx <= cur_castle_idx + 1;
              // Next castle will reset comb in ST_CHECK_CASTLE
            end
          end else begin
            // No hit yet: go to next combination
            if (!is_last_combination()) begin
              next_combination();
            end else begin
              // All combinations tried, no valid quad: move to next castle
              if (cur_castle_idx + 1 < castle_cnt) begin
                cur_castle_idx <= cur_castle_idx + 1;
                any_valid_quad_for_castle <= 1'b0;
                // Next state logic will go to ST_CHECK_CASTLE
              end
            end
          end
        end

        ST_DONE: begin
          done <= 1'b1;
          // Hold counts and flags until restart
        end

        default: ;
      endcase
    end
  end

endmodule