module tram_explosion_counter (
  input clk,
  input rst_n,
  input start,
  input [1:0] rows,
  input [1:0] cols,
  input [15:0][1:0] grid,
  output reg [1:0] explosions,
  output reg done
);
  // Constants
  localparam CELLS = 16;
  localparam W = 2; // bits per cell value
  localparam FXP_Q = 16;
  localparam FXP_ONE = 16'h0001; // 1.0 in Q16.16
  localparam MAX_X = 4; // max X per grid (worst-case 16 cells all X but we cap at 4 for state logic)

  // Types
  typedef bit [1:0] cell_t;     // 0=empty,1=X,2=L
  typedef bit [15:0][1:0] grid_t;

  // State machine
  typedef enum bit [2:0] { ST_IDLE, ST_COMPUTE_DIST, ST_FIND_MIN, ST_CHECK_COLLISION, ST_UPDATE_GRID } state_t;
  state_t state, next_state;

  // Round/iteration tracking
  reg [2:0] round_ctr;        // counts up to 4 rounds (max needed to converge)
  reg [1:0] round_x_count;    // number of X in current round
  reg [1:0] round_l_count;    // number of L in current round

  // Work registers for current round
  grid_t round_grid;
  reg [3:0] x_pos [0:3];      // packed cell index per X (0..15)
  reg [3:0] l_pos [0:3];      // packed cell index per L
  reg [3:0] x_idx_map  [0:15]; // 4x slots mapping to cell idx, unused slots 4..15 = 0
  reg [3:0] l_idx_map  [0:15]; // 4x slots mapping to cell idx, unused slots 4..15 = 0
  reg [1:0] x_count, l_count;

  // Per-L minima and tie counts
  reg [31:0] min_dist [0:3];  // Q16.16 per L slot
  reg [1:0]  min_cnt  [0:3];  // number of X achieving min distance per L slot

  // Minimal distance map per X -> each L (distance to L[li])
  reg [31:0] x_min_dist [0:3][0:3]; // [xi][li]
  reg [3:0]  x_min_l    [0:3];      // argmin L for X[xi]
  reg [1:0]  x_min_cnt  [0:3];      // how many L achieve this min for X[xi]

  // Scan indices
  reg [3:0] iX, iL, iD; // up to 4
  reg [1:0] jL, kX;

  // Collision resolution scratch
  reg [3:0] pair_xi [0:3]; // tie X indices (max 3 collisions per round)
  reg [3:0] pair_li [0:3]; // tie L indices (max 3)
  reg [1:0] pair_cnt;
  reg [1:0] unique_assignments;
  reg [1:0] unique_li [0:3]; // L slots to keep (max 3)
  reg [1:0] unique_xn [0:3]; // X slots to keep (max 3)

  // Round change detection
  reg prev_any_removed;
  reg any_removed;

  // Helper functions
  function [31:0] to_fp(input [1:0] v);
    // Convert integer 0..3 to Q16.16 by scaling with 2^16
    return {14'b0, v, 16'b0};
  endfunction

  function [15:0] row_of_idx(input [3:0] idx);
    return idx >> 2; // 0..3
  endfunction

  function [15:0] col_of_idx(input [3:0] idx);
    return idx & 4'b0011; // 0..3
  endfunction

  function [31:0] dist2_fp(input [15:0] dr, input [15:0] dc);
    // dr,dc are 0..3, compute (dr*dr + dc*dc) in Q16.16
    reg [17:0] dr2, dc2; // 6-bit values squared fit in 12 bits, keep headroom
    dr2 = dr * dr;
    dc2 = dc * dc;
    // Scale to Q16.16 by left-shifting 16 bits
    return { (dr2 + dc2), 16'b0 };
  endfunction

  // Update grid in the current round (used at reset and on each round)
  task apply_to_round_grid;
    input [3:0] idx;   // cell index in original grid
    input cell_t val;  // 0,1,2
  begin
    round_grid[idx] = val;
  end
  endtask

  // Reset state machine and working storage
  task reset_state;
    integer k;
    state <= ST_IDLE;
    next_state <= ST_IDLE;
    done <= 1'b0;
    explosions <= 2'b0;
    round_ctr <= 3'b0;
    for (k = 0; k < 4; k++) begin
      x_pos[k] <= 4'b0;
      l_pos[k] <= 4'b0;
      min_dist[k] <= 32'h7fffffff; // +infinity
      min_cnt[k] <= 2'b0;
      x_min_l[k] <= 4'b0;
      x_min_cnt[k] <= 2'b0;
    end
    for (k = 0; k < 16; k++) begin
      x_idx_map[k] <= 4'b0;
      l_idx_map[k] <= 4'b0;
    end
    iX <= 4'b0; iL <= 4'b0; iD <= 4'b0;
    jL <= 2'b0; kX <= 2'b0;
    pair_cnt <= 2'b0;
    unique_assignments <= 2'b0;
    prev_any_removed <= 1'b0;
    any_removed <= 1'b0;
    // Initialize round_grid to all empty
    round_grid <= 16'b0;
  end
  endtask

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) begin
          next_state = ST_COMPUTE_DIST;
        end
      end
      ST_COMPUTE_DIST: begin
        if (iD == 4'd15) begin // finished scanning all X-L pairs
          next_state = ST_FIND_MIN;
        end
      end
      ST_FIND_MIN: begin
        if (kX == round_x_count) begin
          next_state = ST_CHECK_COLLISION;
        end
      end
      ST_CHECK_COLLISION: begin
        if (jL == round_l_count) begin
          next_state = ST_UPDATE_GRID;
        end
      end
      ST_UPDATE_GRID: begin
        next_state = ST_IDLE;
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reset_state;
    end else begin
      done <= 1'b0;
      state <= next_state;
      case (state)
        ST_IDLE: begin
          // Prepare next round when start is asserted
          if (next_state == ST_COMPUTE_DIST) begin
            // Take a snapshot of the input grid for this round
            round_grid <= grid;
            // Build x_pos and l_pos from current grid (respect rows/cols window)
            x_count <= 2'b0;
            l_count <= 2'b0;
            // Clear index maps
            for (integer m = 0; m < 16; m++) begin
              x_idx_map[m] <= 4'b0;
              l_idx_map[m] <= 4'b0;
            end
            for (integer m = 0; m < 4; m++) begin
              x_pos[m] <= 4'b0;
              l_pos[m] <= 4'b0;
            end
            // Scan up to rows*cols cells (max 16)
            for (integer i = 0; i < CELLS; i++) begin
              if (i < (rows * cols)) begin
                case (grid[i])
                  2'b01: begin // X
                    if (x_count < 2'd4) begin
                      x_pos[x_count] <= i[3:0];
                      x_idx_map[x_count] <= i[3:0];
                      x_count <= x_count + 1;
                    end
                  end
                  2'b10: begin // L
                    if (l_count < 2'd4) begin
                      l_pos[l_count] <= i[3:0];
                      l_idx_map[l_count] <= i[3:0];
                      l_count <= l_count + 1;
                    end
                  end
                  default: ; // empty
                endcase
              end
            end
            // Initialize per-L minima and per-X minima
            for (integer li = 0; li < 4; li++) begin
              min_dist[li] <= 32'h7fffffff;
              min_cnt[li] <= 2'b0;
            end
            for (integer xi = 0; xi < 4; xi++) begin
              x_min_l[xi] <= 4'b0;
              x_min_cnt[xi] <= 2'b0;
              for (integer li = 0; li < 4; li++) begin
                x_min_dist[xi][li] <= 32'h7fffffff;
              end
            end
            round_x_count <= x_count;
            round_l_count <= l_count;
            iD <= 4'b0;
            prev_any_removed <= 1'b0;
            any_removed <= 1'b0;
            // Clear scratch collision variables
            pair_cnt <= 2'b0;
            unique_assignments <= 2'b0;
            for (integer t = 0; t < 4; t++) begin
              unique_li[t] <= 2'b0;
              unique_xn[t] <= 2'b0;
              pair_xi[t] <= 4'b0;
              pair_li[t] <= 4'b0;
            end
          end
        end

        ST_COMPUTE_DIST: begin
          // Iterate over all X-L pairs once (iD: 0..15) to fill x_min_dist
          if (iD < 4'd15) begin
            iD <= iD + 4'd1;
          end else begin
            // finished, state will move to FIND_MIN
            iD <= 4'b0;
          end
          // iD = xi*4 + li
          iX <= iD >> 2;  // xi
          iL <= iD & 2'b11; // li
          if ((iD >> 2) < round_x_count && (iD & 2'b11) < round_l_count) begin
            // Compute distance^2 between X[xi] and L[li] in Q16.16
            begin
              reg [15:0] dr, dc;
              reg [31:0] d2;
              dr = row_of_idx(x_pos[iD >> 2]) - row_of_idx(l_pos[iD & 2'b11]);
              dc = col_of_idx(x_pos[iD >> 2]) - col_of_idx(l_pos[iD & 2'b11]);
              d2 = dist2_fp(dr, dc);
              x_min_dist[iD >> 2][iD & 2'b11] <= d2;
            end
          end
        end

        ST_FIND_MIN: begin
          // For each X[xi], find min among L and how many L achieve it
          if (kX < round_x_count) begin
            // Initialize per X
            if (kX == 0) begin
              // First X: set min using L0
              if (round_l_count > 0) begin
                x_min_l[kX] <= 4'd0;
                x_min_cnt[kX] <= 2'd1;
              end else begin
                x_min_l[kX] <= 4'd0;
                x_min_cnt[kX] <= 2'd0;
              end
            end
            // Next L for this X
            if (iL < round_l_count) begin
              // Compare to current min
              if (x_min_cnt[kX] == 0) begin
                // first L for this X
                x_min_l[kX] <= iL;
                x_min_cnt[kX] <= 2'd1;
              end else begin
                if (x_min_dist[kX][iL] < x_min_dist[kX][x_min_l[kX]]) begin
                  x_min_l[kX] <= iL;
                  x_min_cnt[kX] <= 2'd1;
                end else if (x_min_dist[kX][iL] == x_min_dist[kX][x_min_l[kX]]) begin
                  x_min_cnt[kX] <= x_min_cnt[kX] + 2'd1;
                end
              end
              iL <= iL + 2'd1;
            end else begin
              // Done scanning L for this X, move to next X
              kX <= kX + 2'd1;
              iL <= 2'd0;
            end
          end
        end

        ST_CHECK_COLLISION: begin
          if (jL < round_l_count) begin
            // Evaluate collision for L[jL]
            // Gather min distance and which X achieve it
            // Initialize to sentinel
            reg [31:0] best;
            reg [1:0] cnt;
            reg [3:0] first_xi;
            best = 32'h7fffffff;
            cnt = 2'b0;
            first_xi = 4'b0;
            for (iX = 0; iX < round_x_count; iX = iX + 1) begin
              // Consider only X whose argmin includes L[jL] and it is unique to L[jL]
              if (x_min_l[iX] == jL && x_min_cnt[iX] == 2'd1) begin
                if (x_min_dist[iX][jL] < best) begin
                  best = x_min_dist[iX][jL];
                  cnt = 2'd1;
                  first_xi = iX;
                end else if (x_min_dist[iX][jL] == best) begin
                  cnt = cnt + 2'd1;
                end
              end
            end
            // After scanning all X for L[jL]
            if (cnt == 2'd1) begin
              // Unique assignment: L[jL] <-> X[first_xi]
              unique_li[unique_assignments] <= jL;
              unique_xn[unique_assignments] <= first_xi;
              unique_assignments <= unique_assignments + 2'd1;
            end else if (cnt > 2'd1) begin
              // Multiple X equally close to this L: explosion
              explosions <= explosions + 2'd1;
              // Mark collision pairs for later removal (limit to 3)
              if (pair_cnt < 2'd3) begin
                // Record first two X in the tie (record up to 2, more is fine too)
                // For removal, we will also need to know which X were in the tie.
                // Gather again to add to pairs list.
                for (kX = 0; kX < 4; kX = kX + 1) begin
                  if (kX < round_x_count) begin
                    if (x_min_l[kX] == jL && x_min_cnt[kX] == 2'd1 && x_min_dist[kX][jL] == best) begin
                      if (pair_cnt < 2'd3) begin
                        pair_xi[pair_cnt] <= kX;
                        pair_li[pair_cnt] <= jL;
                        pair_cnt <= pair_cnt + 2'd1;
                      end
                    end
                  end
                end
              end
            end
            jL <= jL + 2'd1;
          end
        end

        ST_UPDATE_GRID: begin
          // Remove uniquely assigned X/L
          any_removed <= 1'b0;
          // Remove assigned X first
          for (integer u = 0; u < 4; u = u + 1) begin
            if (u < unique_assignments) begin
              reg [3:0] xi, li;
              xi = unique_xn[u];
              li = unique_li[u];
              if (xi < round_x_count && li < round_l_count) begin
                // Remove X[xi]
                apply_to_round_grid(x_pos[xi], 2'b00);
                // Remove L[li]
                apply_to_round_grid(l_pos[li], 2'b00);
                any_removed <= 1'b1;
              end
            end
          end
          // Remove collision X/L pairs
          for (integer p = 0; p < 4; p = p + 1) begin
            if (p < pair_cnt) begin
              reg [3:0] xi, li;
              xi = pair_xi[p];
              li = pair_li[p];
              if (xi < round_x_count && li < round_l_count) begin
                apply_to_round_grid(x_pos[xi], 2'b00);
                apply_to_round_grid(l_pos[li], 2'b00);
                any_removed <= 1'b1;
              end
            end
          end
          // Decide whether to continue or finish
          if (prev_any_removed || any_removed) begin
            // There was progress; increment round counter up to 4
            if (round_ctr < 3'd4) begin
              round_ctr <= round_ctr + 3'd1;
              // In next cycle, if not yet done, go back to compute
              if (round_ctr < 3'd3) begin
                // Continue next round
                // Setup will happen in IDLE->COMPUTE transition by reading round_grid
                state <= ST_IDLE;
              end else begin
                // Reached max rounds, done
                done <= 1'b1;
                state <= ST_IDLE;
              end
            end else begin
              done <= 1'b1;
              state <= ST_IDLE;
            end
          end else begin
            // No change: finished (either no L or no X or no assignable pairs)
            done <= 1'b1;
            state <= ST_IDLE;
          end
          prev_any_removed <= any_removed;
          // Reset round-local counters for next cycle (if any)
          round_x_count <= 2'b0;
          round_l_count <= 2'b0;
          iD <= 4'b0;
          iL <= 2'b0;
          kX <= 2'b0;
          jL <= 2'b0;
          pair_cnt <= 2'b0;
          unique_assignments <= 2'b0;
        end

        default: begin
          // Stay idle if unknown state
        end
      endcase
    end
  end
endmodule
