module tram_explosion_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  [1:0] rows,
  input  [1:0] cols,
  input  [15:0][1:0] grid,
  output reg [1:0] explosions,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE           = 3'd0,
    COMPUTE_DIST   = 3'd1,
    FIND_MIN       = 3'd2,
    CHECK_COLLISION= 3'd3,
    UPDATE_GRID    = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal storage of grid (register copy)
  // 0=empty,1=X,2=L,3=removed (use 3 as internal removed marker)
  reg [1:0] grid_reg [0:15];

  // Track presence counts
  reg [4:0] x_count;
  reg [4:0] l_count;

  // Coordinate lookup (fixed for 4x4)
  // index = 4*y + x, x,y in [0..3]
  function automatic [3:0] fx(input [3:0] idx);
    fx = idx[1:0];
  endfunction

  function automatic [3:0] fy(input [3:0] idx);
    fy = {2'b00, idx[3:2]};
  endfunction

  // Distance table between each X and L: Q16.16 fixed point (here integer squared distance <<16)
  // There are max 16 X and 16 L, but we only care existing ones.
  // We'll map X indices [0..15], L indices [0..15].
  // dist_q16_16[x][l]
  reg [31:0] dist_q16_16 [0:15][0:15];

  // To find relationships we need mapping from seat index to X/L index lists.
  // For simplicity, we iterate over all 16 for both dimensions each round.

  // Per-round temporaries
  reg [3:0] xi;      // iterator over X candidates
  reg [3:0] li;      // iterator over L candidates

  // For each X: track closest L and its distance
  reg [31:0] x_min_dist   [0:15];
  reg [3:0]  x_min_l_idx  [0:15];
  reg        x_has_l      [0:15];

  // For each L: track minimal distance from any X and count of X achieving it
  reg [31:0] l_min_dist   [0:15];
  reg [4:0]  l_min_count  [0:15];

  // Temporary registers
  reg [3:0] idx;
  reg [31:0] dx2, dy2, dist32;

  // Explosion accumulation (can exceed 2 bits internally)
  reg [4:0] explosions_acc;

  // Done pulse tracker
  reg done_next;

  // Helper: check if any X or L remain
  function automatic bit any_x;
    integer i;
    begin
      any_x = 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        if (grid_reg[i] == 2'd1) any_x = 1'b1;
      end
    end
  endfunction

  function automatic bit any_l;
    integer i;
    begin
      any_l = 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        if (grid_reg[i] == 2'd2) any_l = 1'b1;
      end
    end
  endfunction

  // Sequential logic
  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset
      state <= IDLE;
      explosions_acc <= 5'd0;
      explosions <= 2'd0;
      done <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        grid_reg[i] <= 2'd0;
        x_min_dist[i] <= 32'hFFFF_FFFF;
        x_min_l_idx[i] <= 4'd0;
        x_has_l[i] <= 1'b0;
        l_min_dist[i] <= 32'hFFFF_FFFF;
        l_min_count[i] <= 5'd0;
      end
    end else begin
      state <= next_state;
      done <= done_next;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch input grid and initialize
            explosions_acc <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
              grid_reg[i] <= grid[i];
              x_min_dist[i] <= 32'hFFFF_FFFF;
              x_min_l_idx[i] <= 4'd0;
              x_has_l[i] <= 1'b0;
              l_min_dist[i] <= 32'hFFFF_FFFF;
              l_min_count[i] <= 5'd0;
            end
          end
        end

        COMPUTE_DIST: begin
          // Compute distances between all current X and L
          for (i = 0; i < 16; i = i + 1) begin
            // Reset per-X mins for this round
            x_min_dist[i] <= 32'hFFFF_FFFF;
            x_min_l_idx[i] <= 4'd0;
            x_has_l[i] <= 1'b0;
          end
          for (j = 0; j < 16; j = j + 1) begin
            // Reset per-L mins for this round
            l_min_dist[j] <= 32'hFFFF_FFFF;
            l_min_count[j] <= 5'd0;
          end

          for (i = 0; i < 16; i = i + 1) begin
            if (grid_reg[i] == 2'd1) begin // X
              for (j = 0; j < 16; j = j + 1) begin
                if (grid_reg[j] == 2'd2) begin // L
                  // Compute squared Euclidean distance
                  dx2 = (fx(i) > fx(j)) ? (fx(i) - fx(j)) : (fx(j) - fx(i));
                  dy2 = (fy(i) > fy(j)) ? (fy(i) - fy(j)) : (fy(j) - fy(i));
                  dx2 = dx2 * dx2;
                  dy2 = dy2 * dy2;
                  dist32 = (dx2 + dy2) << 16; // Q16.16
                  dist_q16_16[i][j] <= dist32;

                  // Update closest L for this X
                  if (!x_has_l[i] || dist32 < x_min_dist[i]) begin
                    x_min_dist[i] <= dist32;
                    x_min_l_idx[i] <= j[3:0];
                    x_has_l[i] <= 1'b1;
                  end
                  else if (dist32 == x_min_dist[i]) begin
                    // tie: keep existing; collisions handled via L side
                    x_has_l[i] <= 1'b1;
                  end
                end
              end
            end
          end
        end

        FIND_MIN: begin
          // For each L, derive minimal distance and counts from X assignments
          for (j = 0; j < 16; j = j + 1) begin
            l_min_dist[j] <= 32'hFFFF_FFFF;
            l_min_count[j] <= 5'd0;
          end

          for (i = 0; i < 16; i = i + 1) begin
            if (grid_reg[i] == 2'd1 && x_has_l[i]) begin
              li = x_min_l_idx[i];
              if (grid_reg[li] == 2'd2) begin
                // compare X's chosen L distance to current L's min
                if (x_min_dist[i] < l_min_dist[li]) begin
                  l_min_dist[li] <= x_min_dist[i];
                  l_min_count[li] <= 5'd1;
                end else if (x_min_dist[i] == l_min_dist[li]) begin
                  l_min_count[li] <= l_min_count[li] + 5'd1;
                end
              end
            end
          end
        end

        CHECK_COLLISION: begin
          // Count explosions where an L has multiple closest X (min_count > 1)
          for (j = 0; j < 16; j = j + 1) begin
            if (grid_reg[j] == 2'd2) begin
              if (l_min_count[j] > 5'd1) begin
                if (explosions_acc < 5'd7) // safe bound
                  explosions_acc <= explosions_acc + 5'd1;
              end
            end
          end
        end

        UPDATE_GRID: begin
          // Remove involved X and L for next round
          // For each L with min_count >=1, remove that L and all X at its min distance
          for (j = 0; j < 16; j = j + 1) begin
            if (grid_reg[j] == 2'd2 && l_min_count[j] != 5'd0 && l_min_dist[j] != 32'hFFFF_FFFF) begin
              // Remove this L
              grid_reg[j] <= 2'd3; // mark removed
              // Remove all X that are at that min distance to this L
              for (i = 0; i < 16; i = i + 1) begin
                if (grid_reg[i] == 2'd1 && x_has_l[i]) begin
                  if (x_min_l_idx[i] == j[3:0] && x_min_dist[i] == l_min_dist[j]) begin
                    grid_reg[i] <= 2'd3; // removed
                  end
                end
              end
            end
          end
        end

        default: begin
        end
      endcase

      // Latch final explosions and done when leaving UPDATE_GRID and no more pairs
      if (state == UPDATE_GRID) begin
        if (!any_x() || !any_l()) begin
          // finalize result (max 3 in 2 bits)
          if (explosions_acc[1:0] > 2'd3)
            explosions <= 2'd3;
          else
            explosions <= explosions_acc[1:0];
        end
      end
    end
  end

  // Next-state and done logic (5 processing states, done pulses after final count)
  always @(*) begin
    next_state = state;
    done_next = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          if (any_x() && any_l())
            next_state = COMPUTE_DIST;
          else begin
            next_state = IDLE;
            done_next = 1'b1;
          end
        end
      end

      COMPUTE_DIST: begin
        next_state = FIND_MIN;
      end

      FIND_MIN: begin
        next_state = CHECK_COLLISION;
      end

      CHECK_COLLISION: begin
        next_state = UPDATE_GRID;
      end

      UPDATE_GRID: begin
        if (any_x() && any_l()) begin
          // Another round if both remain
          next_state = COMPUTE_DIST;
        end else begin
          // Finished: pulse done once
          next_state = IDLE;
          done_next = 1'b1;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule