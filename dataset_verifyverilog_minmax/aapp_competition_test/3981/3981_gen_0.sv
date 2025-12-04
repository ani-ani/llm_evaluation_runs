module rocket_safety_checker(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [15:0] engine1_x [0:7],
  input [15:0] engine1_y [0:7],
  input [15:0] engine2_x [0:7],
  input [15:0] engine2_y [0:7],
  output reg result,
  output reg done
);

  // Function to compute cross product of three points (ax, ay), (bx, by), (cx, cy)
  function signed [63:0] cross_product(
    input [15:0] ax, ay, bx, by, cx, cy
  );
    longint signed dx1, dy1, dx2, dy2;
    dx1 = $signed(bx) - $signed(ax);
    dy1 = $signed(by) - $signed(ay);
    dx2 = $signed(cx) - $signed(ax);
    dy2 = $signed(cy) - $signed(ay);
    cross_product = dx1*dy2 - dy1*dx2;
  endfunction

  // Function to compute squared distance between two points
  function signed [63:0] dist_sq(
    input [15:0] x1, y1, x2, y2
  );
    longint signed dx, dy;
    dx = $signed(x1) - $signed(x2);
    dy = $signed(y1) - $signed(y2);
    dist_sq = dx*dx + dy*dy;
  endfunction

  // Function to compute dot product of two vectors
  function signed [63:0] dot_product(
    input signed [15:0] dx1, dy1, dx2, dy2
  );
    dot_product = dx1*dx2 + dy1*dy2;
  endfunction

  // State definitions
  localparam IDLE = 4'd0;
  localparam COPY = 4'd1;
  localparam HULL1_PIVOT = 4'd2;
  localparam HULL1_SORT = 4'd3;
  localparam HULL1_BUILD = 4'd4;
  localparam HULL2_PIVOT = 4'd5;
  localparam HULL2_SORT = 4'd6;
  localparam HULL2_BUILD = 4'd7;
  localparam COMPARE = 4'd8;
  localparam DONE = 4'd9;

  // Internal registers
  reg [3:0] state;
  reg busy;
  reg [3:0] e1_n_reg, e2_n_reg;
  reg [15:0] e1_x_reg [0:7];
  reg [15:0] e1_y_reg [0:7];
  reg [15:0] e2_x_reg [0:7];
  reg [15:0] e2_y_reg [0:7];

  reg [15:0] sorted1_x [0:6];
  reg [15:0] sorted1_y [0:6];
  reg [3:0] sorted1_cnt;
  reg [15:0] sorted2_x [0:6];
  reg [15:0] sorted2_y [0:6];
  reg [3:0] sorted2_cnt;

  reg [15:0] pivot1_x, pivot1_y;
  reg [3:0] pivot1_idx;
  reg [15:0] pivot2_x, pivot2_y;
  reg [3:0] pivot2_idx;

  reg [15:0] hull1_x [0:7];
  reg [15:0] hull1_y [0:7];
  reg [3:0] hull1_size;
  reg [15:0] hull2_x [0:7];
  reg [15:0] hull2_y [0:7];
  reg [3:0] hull2_size;

  reg [3:0] sort_pass1;
  reg sort_swapped1;
  reg [3:0] sort_pass2;
  reg sort_swapped2;

  reg [63:0] feature_dist1 [0:7];
  reg [63:0] feature_dot1 [0:7];
  reg [63:0] feature_dist2 [0:7];
  reg [63:0] feature_dot2 [0:7];

  reg [3:0] compare_shift;
  reg match;
  reg [3:0] i, j;
  reg [15:0] temp_x, temp_y;
  reg signed [63:0] cross_val;
  reg signed [63:0] d1, d2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      busy <= 1'b0;
      done <= 1'b0;
      result <= 1'b0;
      e1_n_reg <= 4'd0;
      e2_n_reg <= 4'd0;
      for (int k = 0; k < 8; k++) begin
        e1_x_reg[k] <= 16'd0;
        e1_y_reg[k] <= 16'd0;
        e2_x_reg[k] <= 16'd0;
        e2_y_reg[k] <= 16'd0;
      end
      sorted1_cnt <= 4'd0;
      sorted2_cnt <= 4'd0;
      sort_pass1 <= 4'd0;
      sort_swapped1 <= 1'b0;
      sort_pass2 <= 4'd0;
      sort_swapped2 <= 1'b0;
      pivot1_x <= 16'd0;
      pivot1_y <= 16'd0;
      pivot1_idx <= 4'd0;
      pivot2_x <= 16'd0;
      pivot2_y <= 16'd0;
      pivot2_idx <= 4'd0;
      hull1_size <= 4'd0;
      hull2_size <= 4'd0;
      for (int k = 0; k < 8; k++) begin
        feature_dist1[k] <= 64'd0;
        feature_dot1[k] <= 64'd0;
        feature_dist2[k] <= 64'd0;
        feature_dot2[k] <= 64'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= 1'b0;
          if (start && !busy) begin
            busy <= 1'b1;
            state <= COPY;
          end
        end

        COPY: begin
          e1_n_reg <= n;
          e2_n_reg <= m;
          for (int k = 0; k < 8; k++) begin
            e1_x_reg[k] <= engine1_x[k];
            e1_y_reg[k] <= engine1_y[k];
            e2_x_reg[k] <= engine2_x[k];
            e2_y_reg[k] <= engine2_y[k];
          end
          sorted1_cnt <= 4'd0;
          sorted2_cnt <= 4'd0;
          sort_pass1 <= 4'd0;
          sort_swapped1 <= 1'b0;
          sort_pass2 <= 4'd0;
          sort_swapped2 <= 1'b0;
          state <= HULL1_PIVOT;
        end

        HULL1_PIVOT: begin
          // Find pivot (lowest y, then lowest x)
          int best_idx;
          best_idx = 0;
          for (int k = 1; k < e1_n_reg; k++) begin
            if (e1_y_reg[k] < e1_y_reg[best_idx] ||
                (e1_y_reg[k] == e1_y_reg[best_idx] && e1_x_reg[k] < e1_x_reg[best_idx])) begin
              best_idx = k;
            end
          end
          pivot1_idx <= best_idx;
          pivot1_x <= e1_x_reg[best_idx];
          pivot1_y <= e1_y_reg[best_idx];
          // Copy other points to sorted1
          sorted1_cnt <= e1_n_reg - 1;
          int idx;
          idx = 0;
          for (int k = 0; k < e1_n_reg; k++) begin
            if (k != best_idx) begin
              sorted1_x[idx] <= e1_x_reg[k];
              sorted1_y[idx] <= e1_y_reg[k];
              idx = idx + 1;
            end
          end
          state <= HULL1_SORT;
        end

        HULL1_SORT: begin
          int cnt = sorted1_cnt;
          if (sort_pass1 == 0) begin
            sort_swapped1 <= 1'b0;
          end
          // Perform one bubble sort pass
          for (int k = 0; k < cnt-1-sort_pass1; k++) begin
            longint signed cross_val_local;
            cross_val_local = cross_product(pivot1_x, pivot1_y,
                                            sorted1_x[k], sorted1_y[k],
                                            sorted1_x[k+1], sorted1_y[k+1]);
            // If cross < 0 => out of order, swap
            if (cross_val_local < 0 ||
                (cross_val_local == 0 &&
                 dist_sq(pivot1_x, pivot1_y, sorted1_x[k], sorted1_y[k]) >
                 dist_sq(pivot1_x, pivot1_y, sorted1_x[k+1], sorted1_y[k+1]))) begin
              temp_x <= sorted1_x[k];
              temp_y <= sorted1_y[k];
              sorted1_x[k] <= sorted1_x[k+1];
              sorted1_y[k] <= sorted1_y[k+1];
              sorted1_x[k+1] <= temp_x;
              sorted1_y[k+1] <= temp_y;
              sort_swapped1 <= 1'b1;
            end
          end
          sort_pass1 <= sort_pass1 + 1;
          if (sort_pass1 == cnt-1 || !sort_swapped1) begin
            state <= HULL1_BUILD;
          end
        end

        HULL1_BUILD: begin
          // Build convex hull using Graham scan
          int hull_sz;
          hull_sz = 1; // start with pivot
          hull1_x[0] <= pivot1_x;
          hull1_y[0] <= pivot1_y;
          for (int k = 0; k < sorted1_cnt; k++) begin
            // push point
            hull1_x[hull_sz] <= sorted1_x[k];
            hull1_y[hull_sz] <= sorted1_y[k];
            hull_sz = hull_sz + 1;
            // pop while not left turn
            for (int p = 0; p < 7; p++) begin
              if (hull_sz >= 3) begin
                longint signed cross_val_local;
                cross_val_local = cross_product(
                  hull1_x[hull_sz-3], hull1_y[hull_sz-3],
                  hull1_x[hull_sz-2], hull1_y[hull_sz-2],
                  hull1_x[hull_sz-1], hull1_y[hull_sz-1]
                );
                if (cross_val_local <= 0) begin
                  // pop middle point
                  hull1_x[hull_sz-2] <= hull1_x[hull_sz-1];
                  hull1_y[hull_sz-2] <= hull1_y[hull_sz-1];
                  hull_sz = hull_sz - 1;
                end else begin
                  // break out of pop loop
                  p = 7;
                end
              end
            end
          end
          hull1_size <= hull_sz;
          state <= HULL2_PIVOT;
        end

        HULL2_PIVOT: begin
          // Find pivot for engine2
          int best_idx;
          best_idx = 0;
          for (int k = 1; k < e2_n_reg; k++) begin
            if (e2_y_reg[k] < e2_y_reg[best_idx] ||
                (e2_y_reg[k] == e2_y_reg[best_idx] && e2_x_reg[k] < e2_x_reg[best_idx])) begin
              best_idx = k;
            end
          end
          pivot2_idx <= best_idx;
          pivot2_x <= e2_x_reg[best_idx];
          pivot2_y <= e2_y_reg[best_idx];
          // Copy other points to sorted2
          sorted2_cnt <= e2_n_reg - 1;
          int idx;
          idx = 0;
          for (int k = 0; k < e2_n_reg; k++) begin
            if (k != best_idx) begin
              sorted2_x[idx] <= e2_x_reg[k];
              sorted2_y[idx] <= e2_y_reg[k];
              idx = idx + 1;
            end
          end
          state <= HULL2_SORT;
        end

        HULL2_SORT: begin
          int cnt = sorted2_cnt;
          if (sort_pass2 == 0) begin
            sort_swapped2 <= 1'b0;
          end
          // Perform one bubble sort pass
          for (int k = 0; k < cnt-1-sort_pass2; k++) begin
            longint signed cross_val_local;
            cross_val_local = cross_product(pivot2_x, pivot2_y,
                                            sorted2_x[k], sorted2_y[k],
                                            sorted2_x[k+1], sorted2_y[k+1]);
            if (cross_val_local < 0 ||
                (cross_val_local == 0 &&
                 dist_sq(pivot2_x, pivot2_y, sorted2_x[k], sorted2_y[k]) >
                 dist_sq(pivot2_x, pivot2_y, sorted2_x[k+1], sorted2_y[k+1]))) begin
              temp_x <= sorted2_x[k];
              temp_y <= sorted2_y[k];
              sorted2_x[k] <= sorted2_x[k+1];
              sorted2_y[k] <= sorted2_y[k+1];
              sorted2_x[k+1] <= temp_x;
              sorted2_y[k+1] <= temp_y;
              sort_swapped2 <= 1'b1;
            end
          end
          sort_pass2 <= sort_pass2 + 1;
          if (sort_pass2 == cnt-1 || !sort_swapped2) begin
            state <= HULL2_BUILD;
          end
        end

        HULL2_BUILD: begin
          // Build convex hull for engine2
          int hull_sz;
          hull_sz = 1; // start with pivot
          hull2_x[0] <= pivot2_x;
          hull2_y[0] <= pivot2_y;
          for (int k = 0; k < sorted2_cnt; k++) begin
            // push point
            hull2_x[hull_sz] <= sorted2_x[k];
            hull2_y[hull_sz] <= sorted2_y[k];
            hull_sz = hull_sz + 1;
            // pop while not left turn
            for (int p = 0; p < 7; p++) begin
              if (hull_sz >= 3) begin
                longint signed cross_val_local;
                cross_val_local = cross_product(
                  hull2_x[hull_sz-3], hull2_y[hull_sz-3],
                  hull2_x[hull_sz-2], hull2_y[hull_sz-2],
                  hull2_x[hull_sz-1], hull2_y[hull_sz-1]
                );
                if (cross_val_local <= 0) begin
                  // pop middle point
                  hull2_x[hull_sz-2] <= hull2_x[hull_sz-1];
                  hull2_y[hull_sz-2] <= hull2_y[hull_sz-1];
                  hull_sz = hull_sz - 1;
                end else begin
                  p = 7;
                end
              end
            end
          end
          hull2_size <= hull_sz;
          state <= COMPARE;
        end

        COMPARE: begin
          if (hull1_size != hull2_size) begin
            result <= 1'b0;
          end else if (hull1_size == 1) begin
            // Single point hulls always match
            result <= 1'b1;
          end else if (hull1_size == 2) begin
            longint signed d1, d2;
            d1 = dist_sq(hull1_x[0], hull1_y[0], hull1_x[1], hull1_y[1]);
            d2 = dist_sq(hull2_x[0], hull2_y[0], hull2_x[1], hull2_y[1]);
            result <= (d1 == d2);
          end else begin
            // hull1_size >= 3
            // Compute feature vectors for engine1
            for (int k = 0; k < hull1_size; k++) begin
              int nx1 = (k+1) % hull1_size;
              int nx2 = (k+2) % hull1_size;
              longint signed dx_val, dy_val, dxn_val, dyn_val;
              dx_val = $signed(hull1_x[nx1]) - $signed(hull1_x[k]);
              dy_val = $signed(hull1_y[nx1]) - $signed(hull1_y[k]);
              feature_dist1[k] <= dx_val*dx_val + dy_val*dy_val;
              dxn_val = $signed(hull1_x[nx2]) - $signed(hull1_x[nx1]);
              dyn_val = $signed(hull1_y[nx2]) - $signed(hull1_y[nx1]);
              feature_dot1[k] <= dx_val*dxn_val + dy_val*dyn_val;
            end
            // Compute feature vectors for engine2
            for (int k = 0; k < hull2_size; k++) begin
              int nx1 = (k+1) % hull2_size;
              int nx2 = (k+2) % hull2_size;
              longint signed dx_val, dy_val, dxn_val, dyn_val;
              dx_val = $signed(hull2_x[nx1]) - $signed(hull2_x[k]);
              dy_val = $signed(hull2_y[nx1]) - $signed(hull2_y[k]);
              feature_dist2[k] <= dx_val*dx_val + dy_val*dy_val;
              dxn_val = $signed(hull2_x[nx2]) - $signed(hull2_x[nx1]);
              dyn_val = $signed(hull2_y[nx2]) - $signed(hull2_y[nx1]);
              feature_dot2[k] <= dx_val*dxn_val + dy_val*dyn_val;
            end
            // Rotation check
            match = 1'b0;
            for (int shift = 0; shift < hull1_size; shift++) begin
              match = 1'b1;
              for (int k = 0; k < hull1_size; k++) begin
                int idx = (k + shift) % hull1_size;
                if (feature_dist1[idx] != feature_dist2[k] || feature_dot1[idx] != feature_dot2[k]) begin
                  match = 1'b0;
                  break;
                end
              end
              if (match) break;
            end
            result <= match;
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            busy <= 1'b0;
            state <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule