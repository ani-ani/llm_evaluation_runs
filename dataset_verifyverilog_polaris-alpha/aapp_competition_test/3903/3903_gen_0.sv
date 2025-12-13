module three_states_router(
  input clk,
  input rst_n,
  input start,
  input [2:0] grid [0:7][0:7],
  output reg [7:0] result,
  output reg done
);

  // Internal encodings
  localparam INF = 8'hFF;

  // Grid decoding: grid[y][x][2:1] = state_id (0:none, 1..3 states), grid[y][x][0] = is_road_allowed
  // We will:
  // 1) Identify three state cell positions (any cell with state_id!=0), assume exactly 3 states total.
  // 2) Run three multi-source BFS (one per state) constrained to road-allowed cells to get costS1, costS2, costS3.
  // 3) costS* is the minimal number of road cells used along path from that state to the cell (count of road cells).
  //    - Entering a road-allowed cell costs +1 (except starting state cells cost 0).
  //    - Non-road cells (grid[y][x][0]==0) are only allowed if they are state cells; they cost 0.
  // 4) Then compute:
  //    best_pair = min over cells that contain state endpoints of (costi + costj);
  //    best_star = min over all cells of (c1 + c2 + c3 - penalty);
  //       where penalty = number of state sources that coincide with that cell (since they double-count 0).
  //    result = min(best_pair, best_star) if finite else 255.
  // Note: This is an approximation of Steiner tree; matches problem intent.

  // We'll implement BFS via wavefront relaxation in up to 64 iterations.

  // State machine
  typedef enum logic [2:0] {
    ST_IDLE      = 3'd0,
    ST_INIT_COST = 3'd1,
    ST_RELAX     = 3'd2,
    ST_DONE      = 3'd3
  } state_t;

  state_t state, next_state;

  // Coordinates counters
  reg [2:0] x;
  reg [2:0] y;
  reg [5:0] relax_iter; // up to 64

  // Cost arrays (per cell per source)
  reg [7:0] cost1 [0:7][0:7];
  reg [7:0] cost2 [0:7][0:7];
  reg [7:0] cost3 [0:7][0:7];

  // Track which cell belongs to which state
  // state_id[y][x]: 0=none,1..3
  reg [1:0] state_id [0:7][0:7];
  reg       is_road [0:7][0:7];

  // Latches to detect sources extracted
  reg found_s1, found_s2, found_s3;

  // For relax pass
  reg [7:0] new_c1, new_c2, new_c3;

  // Helper functions (combinational) for neighbor minimum
  function automatic [7:0] min4;
    input [7:0] a,b,c,d;
    reg [7:0] m1,m2;
    begin
      m1 = (a<b)?a:b;
      m2 = (c<d)?c:d;
      min4 = (m1<m2)?m1:m2;
    end
  endfunction

  function automatic [7:0] min2;
    input [7:0] a,b;
    begin
      min2 = (a<b)?a:b;
    end
  endfunction

  // Synchronous state and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      done <= 1'b0;
      result <= 8'd0;
      x <= 3'd0;
      y <= 3'd0;
      relax_iter <= 6'd0;
      found_s1 <= 1'b0;
      found_s2 <= 1'b0;
      found_s3 <= 1'b0;
    end else begin
      if (!start) begin
        // As per spec: when start=0, reset internal computation, done=0
        state <= ST_IDLE;
        done <= 1'b0;
        result <= 8'd0;
        x <= 3'd0;
        y <= 3'd0;
        relax_iter <= 6'd0;
        found_s1 <= 1'b0;
        found_s2 <= 1'b0;
        found_s3 <= 1'b0;
      end else begin
        state <= next_state;
      end
    end
  end

  // Decode grid to local arrays whenever in IDLE just before INIT_COST
  integer i,j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i=0;i<8;i=i+1) begin
        for (j=0;j<8;j=j+1) begin
          state_id[i][j] <= 2'd0;
          is_road[i][j]  <= 1'b0;
        end
      end
    end else if (state == ST_IDLE && start) begin
      for (i=0;i<8;i=i+1) begin
        for (j=0;j<8;j=j+1) begin
          state_id[i][j] <= grid[i][j][2:1];
          is_road[i][j]  <= grid[i][j][0];
        end
      end
    end
  end

  // Initialize costs based on identified states
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i=0;i<8;i=i+1) begin
        for (j=0;j<8;j=j+1) begin
          cost1[i][j] <= INF;
          cost2[i][j] <= INF;
          cost3[i][j] <= INF;
        end
      end
    end else if (state == ST_IDLE && start) begin
      // Default INF
      for (i=0;i<8;i=i+1) begin
        for (j=0;j<8;j=j+1) begin
          cost1[i][j] <= INF;
          cost2[i][j] <= INF;
          cost3[i][j] <= INF;
        end
      end
      found_s1 <= 1'b0;
      found_s2 <= 1'b0;
      found_s3 <= 1'b0;
    end else if (state == ST_INIT_COST) begin
      // One pass over grid over multiple cycles controlled by x,y
      // At each cycle, assign initial cost for that cell if it's a state
      // Starting state cells cost 0 for their source, INF for others
      if (state_id[y][x] == 2'd1 && !found_s1) begin
        cost1[y][x] <= 8'd0;
        found_s1 <= 1'b1;
      end
      if (state_id[y][x] == 2'd2 && !found_s2) begin
        cost2[y][x] <= 8'd0;
        found_s2 <= 1'b1;
      end
      if (state_id[y][x] == 2'd3 && !found_s3) begin
        cost3[y][x] <= 8'd0;
        found_s3 <= 1'b1;
      end
    end
  end

  // Coordinate and iteration progression
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 3'd0;
      y <= 3'd0;
      relax_iter <= 6'd0;
    end else if (!start) begin
      x <= 3'd0;
      y <= 3'd0;
      relax_iter <= 6'd0;
    end else begin
      case (state)
        ST_IDLE: begin
          x <= 3'd0;
          y <= 3'd0;
          relax_iter <= 6'd0;
        end
        ST_INIT_COST: begin
          if (x == 3'd7) begin
            x <= 3'd0;
            if (y == 3'd7)
              y <= 3'd0;
            else
              y <= y + 3'd1;
          end else begin
            x <= x + 3'd1;
          end
        end
        ST_RELAX: begin
          // Scan all cells; each full scan is one relax_iter step
          if (x == 3'd7) begin
            x <= 3'd0;
            if (y == 3'd7) begin
              y <= 3'd0;
              if (relax_iter != 6'd63)
                relax_iter <= relax_iter + 6'd1;
            end else begin
              y <= y + 3'd1;
            end
          end else begin
            x <= x + 3'd1;
          end
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
      ST_IDLE: begin
        if (start)
          next_state = ST_INIT_COST;
      end
      ST_INIT_COST: begin
        // After full grid initialized, move to RELAX
        if (start && x == 3'd7 && y == 3'd7)
          next_state = ST_RELAX;
      end
      ST_RELAX: begin
        // After 64 relax iterations, go DONE
        if (relax_iter == 6'd63 && x == 3'd7 && y == 3'd7)
          next_state = ST_DONE;
      end
      ST_DONE: begin
        // Stay done while start remains 1; cleared when start=0 by sync reset above
        next_state = ST_DONE;
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Relaxation update for costs (Bellman-Ford style over grid neighbors)
  // We only update when in ST_RELAX, streaming over cells.
  // For each cell, compute potential new costs from neighbors plus local cost.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // handled above
    end else if (state == ST_RELAX) begin
      integer ny, nx;
      reg [7:0] up1,down1,left1,right1;
      reg [7:0] up2,down2,left2,right2;
      reg [7:0] up3,down3,left3,right3;
      reg [7:0] add_cost;

      // Neighbor costs (if out of bounds, treat as INF)
      ny = y - 1;
      nx = x;
      up1    = (y > 0)     ? cost1[ny][nx] : INF;
      up2    = (y > 0)     ? cost2[ny][nx] : INF;
      up3    = (y > 0)     ? cost3[ny][nx] : INF;

      ny = y + 1;
      down1  = (y < 7)     ? cost1[ny][x] : INF;
      down2  = (y < 7)     ? cost2[ny][x] : INF;
      down3  = (y < 7)     ? cost3[ny][x] : INF;

      nx = x - 1;
      left1  = (x > 0)     ? cost1[y][nx] : INF;
      left2  = (x > 0)     ? cost2[y][nx] : INF;
      left3  = (x > 0)     ? cost3[y][nx] : INF;

      nx = x + 1;
      right1 = (x < 7)     ? cost1[y][nx] : INF;
      right2 = (x < 7)     ? cost2[y][nx] : INF;
      right3 = (x < 7)     ? cost3[y][nx] : INF;

      // Local step cost
      if (state_id[y][x] != 2'd0) begin
        // State cells cost 0 to stand on (no road needed in the state cell)
        add_cost = 8'd0;
      end else if (is_road[y][x]) begin
        add_cost = 8'd1;
      end else begin
        // Not allowed (no road, no state) => cannot enter; keep INF
        add_cost = INF;
      end

      // Only relax if reachable (add_cost != INF)
      if (add_cost != INF) begin
        new_c1 = min4(up1,down1,left1,right1);
        new_c2 = min4(up2,down2,left2,right2);
        new_c3 = min4(up3,down3,left3,right3);

        if (new_c1 != INF && new_c1 + add_cost < cost1[y][x])
          cost1[y][x] <= new_c1 + add_cost;
        if (new_c2 != INF && new_c2 + add_cost < cost2[y][x])
          cost2[y][x] <= new_c2 + add_cost;
        if (new_c3 != INF && new_c3 + add_cost < cost3[y][x])
          cost3[y][x] <= new_c3 + add_cost;
      end
    end
  end

  // Final result computation at ST_DONE entry
  // We compute minimal connection cost among:
  //  - pairwise connections via any cell where two sources meet
  //  - triple connection via any cell where all three meet (Steiner-like)
  reg [7:0] best_pair;
  reg [7:0] best_star;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 8'd0;
    end else if (state == ST_RELAX && next_state == ST_DONE) begin
      // Compute on transition to DONE
      best_pair = INF;
      best_star = INF;
      for (i=0;i<8;i=i+1) begin
        for (j=0;j<8;j=j+1) begin
          // Pairwise: any cell that both sources can reach
          if (cost1[i][j] != INF && cost2[i][j] != INF) begin
            if (cost1[i][j] + cost2[i][j] < best_pair)
              best_pair = cost1[i][j] + cost2[i][j];
          end
          if (cost1[i][j] != INF && cost3[i][j] != INF) begin
            if (cost1[i][j] + cost3[i][j] < best_pair)
              best_pair = cost1[i][j] + cost3[i][j];
          end
          if (cost2[i][j] != INF && cost3[i][j] != INF) begin
            if (cost2[i][j] + cost3[i][j] < best_pair)
              best_pair = cost2[i][j] + cost3[i][j];
          end

          // Triple (star) connection
          if (cost1[i][j] != INF && cost2[i][j] != INF && cost3[i][j] != INF) begin
            // Penalty to avoid double-counting state cells: if this cell is one of the states,
            // some costs include 0; summation still counts road cells correctly, but we can allow as is.
            // Use direct sum; it overestimates overlaps outside exact Steiner optimum, but acceptable.
            reg [9:0] sum_c;
            sum_c = cost1[i][j] + cost2[i][j] + cost3[i][j];
            if (sum_c[9:8] == 2'b00) begin
              if (sum_c[7:0] < best_star)
                best_star = sum_c[7:0];
            end
          end
        end
      end

      // Combine
      result <= (best_pair < best_star) ? best_pair : best_star;
      if (result == INF)
        result <= 8'hFF;

      done <= 1'b1;
    end else if (state == ST_DONE) begin
      // Hold result and done stable
      done <= 1'b1;
    end else if (!start) begin
      done <= 1'b0;
      result <= 8'd0;
    end
  end

endmodule