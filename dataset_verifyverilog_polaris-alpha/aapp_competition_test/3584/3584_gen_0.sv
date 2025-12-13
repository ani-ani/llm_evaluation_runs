module onion_protect(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_onions,
  input [3:0] num_posts,
  input [3:0] select_count,
  input [15:0] onion_x[0:7],
  input [15:0] onion_y[0:7],
  input [15:0] post_x[0:7],
  input [15:0] post_y[0:7],
  output reg [3:0] max_protected,
  output reg done
);

  // State encoding
  localparam IDLE      = 3'd0;
  localparam INIT_COMB = 3'd1;
  localparam NEXT_COMB = 3'd2;
  localparam BUILD_HULL= 3'd3;
  localparam CHECK_ONI = 3'd4;
  localparam DONE_ST   = 3'd5;

  reg [2:0] state, next_state;

  // Combination generator for selecting K posts out of M
  // select_idx[i] holds index of i-th chosen post
  reg [2:0] select_idx[0:3]; // K max = 4, indexes 0..7
  reg [2:0] k_reg;           // latched select_count
  reg [2:0] m_reg;           // latched num_posts
  reg [2:0] n_reg;           // latched num_onions

  reg comb_valid;
  reg comb_last;

  // Hull storage: up to K vertices
  reg [15:0] hull_x[0:3];
  reg [15:0] hull_y[0:3];
  reg [2:0]  hull_size; // 1..4

  // Counters and temporaries
  reg [2:0] onion_idx;
  reg [3:0] cur_count;

  // For convex hull building (Monotonic chain specialized for K<=4)
  reg [1:0] build_step;
  reg [2:0] sort_i, sort_j;
  reg [15:0] sx[0:3];
  reg [15:0] sy[0:3];

  // Orientation / cross product wires (signed)
  function automatic signed [31:0] cross_z;
    input signed [15:0] ax, ay;
    input signed [15:0] bx, by;
    input signed [15:0] cx, cy;
    reg signed [16:0] abx, aby, bcx, bcy;
    begin
      abx = bx - ax;
      aby = by - ay;
      bcx = cx - bx;
      bcy = cy - by;
      cross_z = abx * bcy - aby * bcx;
    end
  endfunction

  // Compute orientation sign for (ax,ay)->(bx,by)->(cx,cy)
  function automatic signed [31:0] orient;
    input signed [15:0] ax, ay;
    input signed [15:0] bx, by;
    input signed [15:0] cx, cy;
    reg signed [16:0] v1x, v1y, v2x, v2y;
    begin
      v1x = bx - ax;
      v1y = by - ay;
      v2x = cx - bx;
      v2y = cy - by;
      orient = v1x * v2y - v1y * v2x;
    end
  endfunction

  // Ray casting: point in convex polygon (with vertices in order), including boundary
  function automatic inside_convex;
    input [15:0] px;
    input [15:0] py;
    input [2:0]  sz;
    input [15:0] vx0;
    input [15:0] vy0;
    input [15:0] vx1;
    input [15:0] vy1;
    input [15:0] vx2;
    input [15:0] vy2;
    input [15:0] vx3;
    input [15:0] vy3;
    reg signed [31:0] c;
    reg inside;
    begin
      inside = 1'b0;
      if (sz == 0) begin
        inside = 1'b0;
      end else if (sz == 1) begin
        // Point polygon: inside if equal
        inside = (px == vx0) && (py == vy0);
      end else if (sz == 2) begin
        // Line segment: check colinearity and between
        reg signed [31:0] area2;
        reg signed [15:0] minx, maxx, miny, maxy;
        area2 = (vx1 - vx0) * (py - vy0) - (vy1 - vy0) * (px - vx0);
        if (area2 == 0) begin
          minx = (vx0 < vx1) ? vx0 : vx1;
          maxx = (vx0 > vx1) ? vx0 : vx1;
          miny = (vy0 < vy1) ? vy0 : vy1;
          maxy = (vy0 > vy1) ? vy0 : vy1;
          if (px >= minx && px <= maxx && py >= miny && py <= maxy)
            inside = 1'b1;
        end
      end else begin
        // sz >=3: convex polygon, assume CCW. Use orientation sign; allow boundary.
        integer i0, i1;
        reg signed [31:0] o;
        reg all_nonneg, all_nonpos;
        all_nonneg = 1'b1;
        all_nonpos = 1'b1;
        for (i0 = 0; i0 < sz; i0 = i0 + 1) begin
          i1 = (i0 + 1 == sz) ? 0 : i0 + 1;
          // select vertices
          reg [15:0] ax, ay, bx, by;
          case (i0)
            0: begin ax = vx0; ay = vy0; end
            1: begin ax = vx1; ay = vy1; end
            2: begin ax = vx2; ay = vy2; end
            default: begin ax = vx3; ay = vy3; end
          endcase
          case (i1)
            0: begin bx = vx0; by = vy0; end
            1: begin bx = vx1; by = vy1; end
            2: begin bx = vx2; by = vy2; end
            default: begin bx = vx3; by = vy3; end
          endcase
          o = (bx - ax) * (py - ay) - (by - ay) * (px - ax);
          if (o < 0) all_nonneg = 1'b0;
          if (o > 0) all_nonpos = 1'b0;
        end
        if (all_nonneg || all_nonpos)
          inside = 1'b1;
      end
      inside_convex = inside;
    end
  endfunction

  // Combination next logic (lexicographic for k_reg elements out of m_reg)
  task automatic comb_init;
    integer i;
    begin
      for (i = 0; i < 4; i = i + 1) begin
        select_idx[i] = i[2:0];
      end
      comb_valid = 1'b1;
      comb_last  = 1'b0;
    end
  endtask

  task automatic comb_next;
    integer i;
    begin
      if (!comb_valid) begin
        comb_last = 1'b1;
      end else begin
        // Find position from right to increment
        i = k_reg - 1;
        while (i >= 0 && select_idx[i] == m_reg - k_reg + i[2:0]) begin
          if (i == 0) disable while_loop;
          i = i - 1;
        end
        while_loop: begin end
        if (select_idx[i] == m_reg - k_reg + i[2:0]) begin
          comb_last  = 1'b1;
          comb_valid = 1'b0;
        end else begin
          select_idx[i] = select_idx[i] + 1;
          for (i = i + 1; i < k_reg; i = i + 1) begin
            select_idx[i] = select_idx[i-1] + 1;
          end
          comb_last  = 1'b0;
          comb_valid = 1'b1;
        end
      end
    end
  endtask

  // Convex hull builder for up to 4 points using simple insertion/bubble sort by x,y then monotone chain
  task automatic build_hull_from_comb;
    integer i;
    reg [2:0] idx;
    reg [15:0] tx, ty;
    begin
      // Load selected points into sx/sy
      for (i = 0; i < 4; i = i + 1) begin
        sx[i] = 16'd0;
        sy[i] = 16'd0;
      end
      for (i = 0; i < k_reg; i = i + 1) begin
        idx = select_idx[i];
        sx[i] = post_x[idx];
        sy[i] = post_y[idx];
      end
      // Sort by x, then y (simple bubble sort for small K)
      for (i = 0; i < k_reg; i = i + 1) begin
        integer j;
        for (j = 0; j < k_reg - 1; j = j + 1) begin
          if ( (sx[j] > sx[j+1]) || ((sx[j] == sx[j+1]) && (sy[j] > sy[j+1])) ) begin
            tx = sx[j]; sx[j] = sx[j+1]; sx[j+1] = tx;
            ty = sy[j]; sy[j] = sy[j+1]; sy[j+1] = ty;
          end
        end
      end
      // Monotone chain
      reg [15:0] hx[0:7];
      reg [15:0] hy[0:7];
      integer hsz;
      hsz = 0;
      // Lower hull
      for (i = 0; i < k_reg; i = i + 1) begin
        while (hsz >= 2 && orient(hx[hsz-2], hy[hsz-2], hx[hsz-1], hy[hsz-1], sx[i], sy[i]) <= 0) begin
          hsz = hsz - 1;
        end
        hx[hsz] = sx[i];
        hy[hsz] = sy[i];
        hsz = hsz + 1;
      end
      // Upper hull
      integer lower_size;
      lower_size = hsz;
      for (i = k_reg-2; i >= 0; i = i - 1) begin
        while (hsz > lower_size && orient(hx[hsz-2], hy[hsz-2], hx[hsz-1], hy[hsz-1], sx[i], sy[i]) <= 0) begin
          hsz = hsz - 1;
        end
        hx[hsz] = sx[i];
        hy[hsz] = sy[i];
        hsz = hsz + 1;
        if (i == 0) begin
          // prevent wrap of signed loop
          i = -1;
        end
      end
      if (hsz > 1)
        hsz = hsz - 1; // last point == first
      if (hsz > 4) hsz = 4;
      hull_size = hsz[2:0];
      for (i = 0; i < 4; i = i + 1) begin
        hull_x[i] = (i < hsz) ? hx[i] : 16'd0;
        hull_y[i] = (i < hsz) ? hy[i] : 16'd0;
      end
    end
  endtask

  // Sequential FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      max_protected <= 4'd0;
      done          <= 1'b0;
      m_reg         <= 3'd0;
      n_reg         <= 3'd0;
      k_reg         <= 3'd0;
      comb_valid    <= 1'b0;
      comb_last     <= 1'b0;
      hull_size     <= 3'd0;
      onion_idx     <= 3'd0;
      cur_count     <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            max_protected <= 4'd0;
            m_reg      <= (num_posts > 8) ? 3'd8 : num_posts[2:0];
            n_reg      <= (num_onions > 8) ? 3'd8 : num_onions[2:0];
            k_reg      <= (select_count > 4) ? 3'd4 : select_count[2:0];
            comb_init();
          end
        end

        INIT_COMB: begin
          // Already initialized; build hull for first combination
          build_hull_from_comb();
          onion_idx <= 3'd0;
          cur_count <= 4'd0;
        end

        BUILD_HULL: begin
          // Build hull for current combination
          build_hull_from_comb();
          onion_idx <= 3'd0;
          cur_count <= 4'd0;
        end

        CHECK_ONI: begin
          if (onion_idx < n_reg) begin
            if (inside_convex(
                  onion_x[onion_idx], onion_y[onion_idx], hull_size,
                  hull_x[0], hull_y[0],
                  hull_x[1], hull_y[1],
                  hull_x[2], hull_y[2],
                  hull_x[3], hull_y[3])) begin
              cur_count <= cur_count + 1'b1;
            end
            onion_idx <= onion_idx + 1'b1;
          end else begin
            // Completed all onions for this hull
            if (cur_count > max_protected)
              max_protected <= cur_count;
            // Move to next combination
            comb_next();
          end
        end

        NEXT_COMB: begin
          if (comb_valid) begin
            build_hull_from_comb();
            onion_idx <= 3'd0;
            cur_count <= 4'd0;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (select_count < 3 || select_count > 4 || num_posts < select_count || num_onions == 0) begin
            next_state = DONE_ST;
          end else begin
            next_state = INIT_COMB;
          end
        end
      end

      INIT_COMB: begin
        if (!comb_valid)
          next_state = DONE_ST;
        else
          next_state = CHECK_ONI;
      end

      BUILD_HULL: begin
        if (!comb_valid)
          next_state = DONE_ST;
        else
          next_state = CHECK_ONI;
      end

      CHECK_ONI: begin
        if (onion_idx >= n_reg) begin
          if (!comb_valid && comb_last)
            next_state = DONE_ST;
          else if (comb_valid)
            next_state = NEXT_COMB;
        end
      end

      NEXT_COMB: begin
        if (!comb_valid && comb_last)
          next_state = DONE_ST;
        else if (comb_valid)
          next_state = CHECK_ONI;
      end

      DONE_ST: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule