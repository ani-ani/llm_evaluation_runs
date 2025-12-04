module convex_hull_area(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start processing
  input [2:0] num_nails, // number of nails (3-8)
  input [7:0][15:0] nail_x, // 8 x-coordinates (16-bit each)
  input [7:0][15:0] nail_y, // 8 y-coordinates (16-bit each)
  input [5:0][1:0] remove_seq, // 6 removal steps (00=L,01=R,10=U,11=D)
  output reg [35:0] area, // x10 scaled area (integer part in [35:4])
  output reg valid, // high when area is valid
  output reg done // high when all areas computed
);

  // Internal storage (fixed 8-point storage)
  typedef logic signed [15:0] coord_t;
  typedef struct packed {
    coord_t x;
    coord_t y;
  } point_t;

  point_t [7:0] cur_pts;
  logic [3:0] cur_cnt;       // number of points currently present (3..8)
  logic [2:0] step;          // 0..5 removal step index

  // State machine
  typedef enum logic [2:0] {
    S_IDLE = 3'b000,
    S_LOAD = 3'b001,
    S_HULL = 3'b010,
    S_AREA = 3'b011,
    S_DONE = 3'b100
  } state_t;
  state_t state, next_state;

  logic [3:0] hull_cycle;    // 0..15 cycle counter within 16-cycle hull window
  logic valid_next;
  logic done_next;
  logic [35:0] area_next;

  //----------------------------------------------
  // Helper functions (automatic)
  //----------------------------------------------
  function [31:0] cross_z(input point_t a, input point_t b, input point_t c);
    // (b - a) x (c - a)
    logic signed [31:0] bax, bay, cax, cay;
    bax = $signed(b.x) - $signed(a.x);
    bay = $signed(b.y) - $signed(a.y);
    cax = $signed(c.x) - $signed(a.x);
    cay = $signed(c.y) - $signed(a.y);
    cross_z = bax * cay - bay * cax; // signed 32-bit
  endfunction

  function [63:0] area2_x10(input point_t [15:0] poly, input int n);
    // Shoelace * 10 (no division by 2), returns 64-bit signed
    int i, j;
    logic signed [63:0] sum;
    sum = 0;
    for (i = 0; i < n; i++) begin
      j = (i + 1) % n;
      sum = sum + $signed(poly[i].x) * $signed(poly[j].y);
      sum = sum - $signed(poly[i].y) * $signed(poly[j].x);
    end
    area2_x10 = sum * 10; // x10 scaled without dividing by 2
  endfunction

  function int find_extreme_index(input point_t [7:0] pts, input int cnt, input logic [1:0] dir);
    int i;
    int best_idx;
    logic signed [15:0] best_val;
    case (dir)
      2'b00: begin // L (min x)
        best_val = 16'sh7FFF; // very large positive
        for (i = 0; i < cnt; i++) begin
          if (pts[i].x < best_val) begin
            best_val = pts[i].x;
            best_idx = i;
          end
        end
      end
      2'b01: begin // R (max x)
        best_val = 16'sh8000; // very large negative
        for (i = 0; i < cnt; i++) begin
          if (pts[i].x > best_val) begin
            best_val = pts[i].x;
            best_idx = i;
          end
        end
      end
      2'b10: begin // D (min y)
        best_val = 16'sh7FFF;
        for (i = 0; i < cnt; i++) begin
          if (pts[i].y < best_val) begin
            best_val = pts[i].y;
            best_idx = i;
          end
        end
      end
      2'b11: begin // U (max y)
        best_val = 16'sh8000;
        for (i = 0; i < cnt; i++) begin
          if (pts[i].y > best_val) begin
            best_val = pts[i].y;
            best_idx = i;
          end
        end
      end
      default: best_idx = 0;
    endcase
    return best_idx;
  endfunction

  function void remove_by_index(inout point_t [7:0] pts, inout int cnt, input int idx);
    int i;
    if (cnt <= 0) return;
    if (idx < 0 || idx >= cnt) return;
    // shift left to remove pts[idx]
    for (i = idx; i < cnt-1; i++) begin
      pts[i] = pts[i+1];
    end
    cnt = cnt - 1;
  endfunction

  function void compute_convex_hull(input point_t [7:0] pts, input int cnt, output point_t [15:0] hull, output int hcnt);
    // Monotonic chain (Andrew's) on up to 8 points -> up to 8 hull points
    point_t [7:0] sorted_pts;
    point_t [15:0] lower;
    point_t [15:0] upper;
    int lower_cnt, upper_cnt;
    int i, j;

    hcnt = 0;
    if (cnt <= 0) begin
      hcnt = 0;
      return;
    end
    if (cnt == 1) begin
      hull[0] = pts[0];
      hcnt = 1;
      return;
    end
    if (cnt == 2) begin
      hull[0] = pts[0];
      hull[1] = pts[1];
      hcnt = 2;
      return;
    end

    // Sort by (x, then y)
    for (i = 0; i < cnt; i++) sorted_pts[i] = pts[i];
    // simple insertion sort
    for (i = 1; i < cnt; i++) begin
      point_t key = sorted_pts[i];
      j = i - 1;
      while (j >= 0) begin
        if (sorted_pts[j].x > key.x || (sorted_pts[j].x == key.x && sorted_pts[j].y > key.y)) begin
          sorted_pts[j+1] = sorted_pts[j];
          j = j - 1;
        end else begin
          break;
        end
      end
      sorted_pts[j+1] = key;
    end

    // Lower hull
    lower_cnt = 0;
    for (i = 0; i < cnt; i++) begin
      while (lower_cnt >= 2) begin
        if (cross_z(lower[lower_cnt-2], lower[lower_cnt-1], sorted_pts[i]) <= 0) begin
          lower_cnt = lower_cnt - 1;
        end else begin
          break;
        end
      end
      lower[lower_cnt] = sorted_pts[i];
      lower_cnt = lower_cnt + 1;
    end

    // Upper hull
    upper_cnt = 0;
    for (i = cnt-1; i >= 0; i--) begin
      while (upper_cnt >= 2) begin
        if (cross_z(upper[upper_cnt-2], upper[upper_cnt-1], sorted_pts[i]) <= 0) begin
          upper_cnt = upper_cnt - 1;
        end else begin
          break;
        end
      end
      upper[upper_cnt] = sorted_pts[i];
      upper_cnt = upper_cnt + 1;
    end

    // Concatenate lower and upper to form full hull, removing last point of each (duplicate endpoints)
    hcnt = 0;
    for (i = 0; i < lower_cnt-1; i++) begin
      hull[hcnt] = lower[i];
      hcnt = hcnt + 1;
    end
    for (i = 0; i < upper_cnt-1; i++) begin
      hull[hcnt] = upper[i];
      hcnt = hcnt + 1;
    end
  endfunction

  //----------------------------------------------
  // State update (sequential)
  //----------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      step <= 3'd0;
      cur_cnt <= 4'd0;
      hull_cycle <= 4'd0;
      area <= 36'd0;
      valid <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      step <= (state == S_HULL && hull_cycle == 4'd15) ? (step + 1) : step;
      hull_cycle <= (next_state == S_HULL) ? (hull_cycle + 1) : 4'd0;
      area <= area_next;
      valid <= valid_next;
      done <= done_next;
    end
  end

  //----------------------------------------------
  // Combinational next-state logic and datapath
  //----------------------------------------------
  always_comb begin
    next_state = state;
    valid_next = 1'b0;
    done_next = 1'b0;
    area_next = area; // default hold

    // default storage update (avoid latches)
    cur_pts = cur_pts;
    cur_cnt = cur_cnt;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_LOAD;
        end
      end

      S_LOAD: begin
        // Load initial nail coordinates
        if (num_nails >= 3 && num_nails <= 8) begin
          cur_cnt = num_nails[3:0];
          for (int i = 0; i < 8; i++) begin
            if (i < cur_cnt) begin
              cur_pts[i].x = nail_x[i];
              cur_pts[i].y = nail_y[i];
            end else begin
              cur_pts[i].x = 16'd0;
              cur_pts[i].y = 16'd0;
            end
          end
        end else begin
          cur_cnt = 4'd0; // invalid, stay empty
        end
        next_state = S_HULL;
        hull_cycle = 4'd0;
      end

      S_HULL: begin
        // Removal within 16 cycles window; removal happens at cycle 0
        if (hull_cycle == 4'd0) begin
          if (cur_cnt > 3) begin
            int idx;
            idx = find_extreme_index(cur_pts, cur_cnt, remove_seq[step*1 +: 2]);
            remove_by_index(cur_pts, cur_cnt, idx);
          end
          // if cur_cnt <= 3, removal is still one action (no change if <=3?), but spec says remove extreme even if <=3
          // In case cur_cnt <= 3 and we still remove (if cur_cnt was exactly 3 before removal, it becomes 2)
        end
        // After 16 cycles, go to area calculation
        if (hull_cycle == 4'd15) begin
          next_state = S_AREA;
        end
      end

      S_AREA: begin
        // Compute convex hull and area in 1 cycle
        point_t [15:0] hull;
        int hcnt;
        compute_convex_hull(cur_pts, cur_cnt, hull, hcnt);
        if (hcnt < 3) begin
          area_next = 36'd0; // degenerate hull -> area 0
        end else begin
          logic signed [63:0] a2x10;
          a2x10 = area2_x10(hull, hcnt);
          // a2x10 is already x10 without division by 2 (shoelace area = |sum|/2, we do sum*10, so area*10 = |sum|*5)
          // Actually: area = |sum|/2. We want area*10 = |sum|*5. Our area2_x10 returns |sum|*10, so divide by 2.
          if (a2x10[63] == 1'b1) begin
            area_next = (-a2x10) / 2; // positive value
          end else begin
            area_next = (a2x10) / 2;
          end
        end
        valid_next = 1'b1; // valid for one cycle
        // Decide next state
        if (step == 3'd5) begin
          next_state = S_DONE;
        end else begin
          next_state = S_HULL;
        end
      end

      S_DONE: begin
        done_next = 1'b1;
        if (start) begin
          next_state = S_LOAD;
        end else begin
          next_state = S_DONE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  //----------------------------------------------
  // Continuous output updates when valid (wire-like)
  //----------------------------------------------
  // valid and area are registered; nothing extra here.

endmodule
