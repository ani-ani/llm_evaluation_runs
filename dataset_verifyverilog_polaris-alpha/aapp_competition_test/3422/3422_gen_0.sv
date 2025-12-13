module treasure_map_solver(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  num_pieces,
  input       [3:0]  piece_w [0:7],
  input       [3:0]  piece_h [0:7],
  input       [3:0]  piece_data [0:7][0:3][0:3],
  output reg  [2:0]  map_w,
  output reg  [2:0]  map_h,
  output reg  [3:0]  solution_grid [0:7][0:7],
  output reg  [2:0]  piece_grid [0:7][0:7],
  output reg         done
);

  // Overview:
  // This is a sequential backtracking search engine exploring:
  // - Permutations of pieces
  // - 4 rotations per piece
  // - Placements on 8x8 grid (no overlap, within bounds)
  // For each complete tiling, it checks the treasure condition:
  //   Find a cell T such that for all its orthogonal neighbors P,
  //   (dist(T,P) % 10) == map_value(P); here dist is manhattan distance.
  // The search terminates on first valid solution or exhaustion.

  // ------------------------------------------------------------
  // Parameters / types
  // ------------------------------------------------------------
  localparam MAXN      = 8;
  localparam GRID_W    = 8;
  localparam GRID_H    = 8;
  localparam MAX_ROT   = 4;

  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_INIT      = 4'd1,
    S_NEXT_TRY  = 4'd2,
    S_CHECK_FIT = 4'd3,
    S_PLACE     = 4'd4,
    S_BACKTRACK = 4'd5,
    S_CHECK_TRE = 4'd6,
    S_DONE_OK   = 4'd7,
    S_DONE_FAIL = 4'd8
  } state_t;

  state_t state, state_n;

  // ------------------------------------------------------------
  // Internal registers
  // ------------------------------------------------------------

  // Current depth in search (how many pieces placed so far)
  reg [3:0] depth;          // 0..8
  reg [3:0] depth_n;

  // Track whether each piece is used
  reg used [0:7];
  reg used_n [0:7];

  // Search candidates at current depth
  reg [2:0] cur_piece_idx;      // candidate piece index
  reg [1:0] cur_rot;            // 0..3
  reg [2:0] cur_x;              // 0..7
  reg [2:0] cur_y;              // 0..7

  reg [2:0] cur_piece_idx_n;
  reg [1:0] cur_rot_n;
  reg [2:0] cur_x_n;
  reg [2:0] cur_y_n;

  // Record for each depth: placed piece / rotation / x / y
  reg [2:0] place_piece   [0:7];
  reg [1:0] place_rot     [0:7];
  reg [2:0] place_x       [0:7];
  reg [2:0] place_y       [0:7];

  reg [2:0] place_piece_n [0:7];
  reg [1:0] place_rot_n   [0:7];
  reg [2:0] place_x_n     [0:7];
  reg [2:0] place_y_n     [0:7];

  // Working grids during search
  reg [3:0] grid_val      [0:7][0:7];
  reg [2:0] grid_pid      [0:7][0:7];

  reg [3:0] grid_val_n    [0:7][0:7];
  reg [2:0] grid_pid_n    [0:7][0:7];

  // Current map bounding box (min/max of occupied cells)
  reg [2:0] min_x, max_x, min_y, max_y;
  reg [2:0] min_x_n, max_x_n, min_y_n, max_y_n;

  // Flag when all combinations exhausted
  reg       search_exhausted;
  reg       search_exhausted_n;

  // Temporary wires/regs for fit checking and placement
  integer i, j, d;

  // ------------------------------------------------------------
  // Utility function: get rotated cell from piece_data
  // rot = 0: (r,c)
  // rot = 1: (c, w-1-r)
  // rot = 2: (h-1-r, w-1-c)
  // rot = 3: (h-1-c, r)
  // Note: piece_w/h are <=4; we index 0..3 safely
  // ------------------------------------------------------------
  function automatic [3:0] get_piece_cell;
    input [2:0] pidx;
    input [1:0] rot;
    input [1:0] r;
    input [1:0] c;
    reg   [3:0] w;
    reg   [3:0] h;
    reg   [1:0] rr, cc;
  begin
    w = piece_w[pidx];
    h = piece_h[pidx];
    case (rot)
      2'd0: begin rr = r;         cc = c;         end
      2'd1: begin rr = c;         cc = (w[1:0] - 1'b1) - r; end
      2'd2: begin rr = (h[1:0]-1'b1) - r; cc = (w[1:0]-1'b1) - c; end
      2'd3: begin rr = (h[1:0]-1'b1) - c; cc = r;         end
      default: begin rr = r; cc = c; end
    endcase
    get_piece_cell = piece_data[pidx][rr][cc];
  end
  endfunction

  // ------------------------------------------------------------
  // Utility: compute rotated width/height
  // ------------------------------------------------------------
  function automatic [3:0] rot_w;
    input [2:0] pidx;
    input [1:0] rot;
    reg [3:0] w, h;
  begin
    w = piece_w[pidx];
    h = piece_h[pidx];
    rot_w = (rot[0] == 1'b1) ? h : w; // rot 1 or 3 -> swap
  end
  endfunction

  function automatic [3:0] rot_h;
    input [2:0] pidx;
    input [1:0] rot;
    reg [3:0] w, h;
  begin
    w = piece_w[pidx];
    h = piece_h[pidx];
    rot_h = (rot[0] == 1'b1) ? w : h;
  end
  endfunction

  // ------------------------------------------------------------
  // Check if current (cur_piece_idx,cur_rot,cur_x,cur_y) fits
  //   - inside 8x8
  //   - no overlap (grid_pid==7'h7 used as empty marker via reset)
  // This is evaluated combinationally per state.
  // ------------------------------------------------------------
  reg fit_ok;
  always @(*) begin
    fit_ok = 1'b0;
    if (cur_piece_idx < num_pieces) begin
      // piece must be unused
      if (!used[cur_piece_idx]) begin
        // size
        automatic [3:0] w = rot_w(cur_piece_idx, cur_rot);
        automatic [3:0] h = rot_h(cur_piece_idx, cur_rot);
        if (cur_x + w <= GRID_W && cur_y + h <= GRID_H) begin
          fit_ok = 1'b1;
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              if (i < h && j < w) begin
                automatic [3:0] cell = get_piece_cell(cur_piece_idx, cur_rot, i[1:0], j[1:0]);
                if (cell != 4'd0) begin
                  if (grid_pid[cur_y + i][cur_x + j] != 3'd7 && grid_val[cur_y + i][cur_x + j] != 4'd0) begin
                    fit_ok = 1'b0;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Treasure condition check (after all pieces placed)
  // We search entire used area for a cell T where for every
  // 4-neighbor P inside map: (|dx|+|dy|) % 10 == grid_val[P].
  // If found, solution is accepted.
  // ------------------------------------------------------------
  reg treasure_ok;
  always @(*) begin
    treasure_ok = 1'b0;
    // scan all cells in bounding box
    for (i = min_y; i <= max_y; i = i + 1) begin
      for (j = min_x; j <= max_x; j = j + 1) begin
        if (grid_val[i][j] != 4'd0) begin
          // treat (j,i) as candidate treasure
          automatic bit all_match = 1'b1;
          // neighbors: up,down,left,right
          automatic integer ny, nx;
          // up
          ny = i - 1;
          nx = j;
          if (ny >= min_y && grid_val[ny][nx] != 4'd0) begin
            automatic integer dist = (i>ny)?(i-ny):(ny-i) + (j>nx)?(j-nx):(nx-j);
            if ((dist % 10) != grid_val[ny][nx]) all_match = 1'b0;
          end
          // down
          ny = i + 1;
          nx = j;
          if (ny <= max_y && grid_val[ny][nx] != 4'd0) begin
            automatic integer dist = (i>ny)?(i-ny):(ny-i) + (j>nx)?(j-nx):(nx-j);
            if ((dist % 10) != grid_val[ny][nx]) all_match = 1'b0;
          end
          // left
          ny = i;
          nx = j - 1;
          if (nx >= min_x && grid_val[ny][nx] != 4'd0) begin
            automatic integer dist = (i>ny)?(i-ny):(ny-i) + (j>nx)?(j-nx):(nx-j);
            if ((dist % 10) != grid_val[ny][nx]) all_match = 1'b0;
          end
          // right
          ny = i;
          nx = j + 1;
          if (nx <= max_x && grid_val[ny][nx] != 4'd0) begin
            automatic integer dist = (i>ny)?(i-ny):(ny-i) + (j>nx)?(j-nx):(nx-j);
            if ((dist % 10) != grid_val[ny][nx]) all_match = 1'b0;
          end

          if (all_match) begin
            treasure_ok = 1'b1;
          end
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Next-state logic (coarse; some operations in loops)
  // ------------------------------------------------------------
  always @(*) begin
    // Defaults: hold state
    state_n            = state;
    depth_n            = depth;
    cur_piece_idx_n    = cur_piece_idx;
    cur_rot_n          = cur_rot;
    cur_x_n            = cur_x;
    cur_y_n            = cur_y;
    search_exhausted_n = search_exhausted;

    // Copy arrays as default
    for (d = 0; d < MAXN; d = d + 1) begin
      used_n[d]         = used[d];
      place_piece_n[d]  = place_piece[d];
      place_rot_n[d]    = place_rot[d];
      place_x_n[d]      = place_x[d];
      place_y_n[d]      = place_y[d];
    end

    for (i = 0; i < GRID_H; i = i + 1) begin
      for (j = 0; j < GRID_W; j = j + 1) begin
        grid_val_n[i][j] = grid_val[i][j];
        grid_pid_n[i][j] = grid_pid[i][j];
      end
    end

    min_x_n = min_x;
    max_x_n = max_x;
    min_y_n = min_y;
    max_y_n = max_y;

    case (state)
      S_IDLE: begin
        if (start) begin
          state_n = S_INIT;
        end
      end

      S_INIT: begin
        // Initialize search state
        for (d = 0; d < MAXN; d = d + 1) begin
          used_n[d]        = 1'b0;
          place_piece_n[d] = 3'd0;
          place_rot_n[d]   = 2'd0;
          place_x_n[d]     = 3'd0;
          place_y_n[d]     = 3'd0;
        end
        for (i = 0; i < GRID_H; i = i + 1) begin
          for (j = 0; j < GRID_W; j = j + 1) begin
            grid_val_n[i][j] = 4'd0;
            grid_pid_n[i][j] = 3'd7; // 7 used as empty marker
          end
        end
        depth_n            = 4'd0;
        cur_piece_idx_n    = 3'd0;
        cur_rot_n          = 2'd0;
        cur_x_n            = 3'd0;
        cur_y_n            = 3'd0;
        search_exhausted_n = 1'b0;
        // Start bounding box undefined; set to max / min
        min_x_n            = 3'd7;
        min_y_n            = 3'd7;
        max_x_n            = 3'd0;
        max_y_n            = 3'd0;
        state_n            = S_NEXT_TRY;
      end

      S_NEXT_TRY: begin
        if (depth == num_pieces) begin
          // All placed, check treasure
          state_n = S_CHECK_TRE;
        end else if (search_exhausted) begin
          state_n = S_DONE_FAIL;
        end else begin
          // Explore configurations at this depth
          if (cur_piece_idx >= num_pieces) begin
            // No more pieces; backtrack
            state_n = S_BACKTRACK;
          end else if (used[cur_piece_idx]) begin
            // Skip used piece
            cur_piece_idx_n = cur_piece_idx + 3'd1;
          end else begin
            // Try current combination in S_CHECK_FIT
            state_n = S_CHECK_FIT;
          end
        end
      end

      S_CHECK_FIT: begin
        if (fit_ok) begin
          state_n = S_PLACE;
        end else begin
          // Advance search coordinates
          // Move to next (x,y,rot,piece)
          cur_x_n = cur_x;
          cur_y_n = cur_y;
          cur_rot_n = cur_rot;
          cur_piece_idx_n = cur_piece_idx;

          if (cur_x + 1 < GRID_W) begin
            cur_x_n = cur_x + 3'd1;
          end else begin
            cur_x_n = 3'd0;
            if (cur_y + 1 < GRID_H) begin
              cur_y_n = cur_y + 3'd1;
            end else begin
              cur_y_n = 3'd0;
              if (cur_rot + 1 < MAX_ROT[1:0]) begin
                cur_rot_n = cur_rot + 2'd1;
              end else begin
                cur_rot_n = 2'd0;
                cur_piece_idx_n = cur_piece_idx + 3'd1;
              end
            end
          end
          state_n = S_NEXT_TRY;
        end
      end

      S_PLACE: begin
        // Place the piece into grid
        automatic [3:0] w = rot_w(cur_piece_idx, cur_rot);
        automatic [3:0] h = rot_h(cur_piece_idx, cur_rot);
        for (i = 0; i < 4; i = i + 1) begin
          for (j = 0; j < 4; j = j + 1) begin
            if (i < h && j < w) begin
              automatic [3:0] cell = get_piece_cell(cur_piece_idx, cur_rot, i[1:0], j[1:0]);
              if (cell != 4'd0) begin
                grid_val_n[cur_y + i][cur_x + j] = cell;
                grid_pid_n[cur_y + i][cur_x + j] = cur_piece_idx;
              end
            end
          end
        end
        // Update used and placement records
        used_n[cur_piece_idx] = 1'b1;
        place_piece_n[depth]  = cur_piece_idx;
        place_rot_n[depth]    = cur_rot;
        place_x_n[depth]      = cur_x;
        place_y_n[depth]      = cur_y;

        // Update bounding box
        if (cur_x < min_x) min_x_n = cur_x;
        if (cur_y < min_y) min_y_n = cur_y;
        if (cur_x + w - 1 > max_x) max_x_n = cur_x + w - 1;
        if (cur_y + h - 1 > max_y) max_y_n = cur_y + h - 1;

        // Advance depth and reset candidate explorer
        depth_n         = depth + 4'd1;
        cur_piece_idx_n = 3'd0;
        cur_rot_n       = 2'd0;
        cur_x_n         = 3'd0;
        cur_y_n         = 3'd0;
        state_n         = S_NEXT_TRY;
      end

      S_BACKTRACK: begin
        if (depth == 0) begin
          search_exhausted_n = 1'b1;
          state_n            = S_DONE_FAIL;
        end else begin
          // Remove piece at depth-1
          automatic [3:0] w_rm;
          automatic [3:0] h_rm;
          automatic [2:0] px;
          automatic [2:0] py;
          automatic [2:0] pid;
          automatic [1:0] prot;

          px   = place_x[depth-1];
          py   = place_y[depth-1];
          pid  = place_piece[depth-1];
          prot = place_rot[depth-1];

          w_rm = rot_w(pid, prot);
          h_rm = rot_h(pid, prot);

          for (i = 0; i < h_rm; i = i + 1) begin
            for (j = 0; j < w_rm; j = j + 1) begin
              if (grid_pid[py + i][px + j] == pid) begin
                grid_val_n[py + i][px + j] = 4'd0;
                grid_pid_n[py + i][px + j] = 3'd7;
              end
            end
          end

          used_n[pid] = 1'b0;

          // Recompute bounding box (conservative: scan entire grid)
          min_x_n = 3'd7;
          min_y_n = 3'd7;
          max_x_n = 3'd0;
          max_y_n = 3'd0;
          for (i = 0; i < GRID_H; i = i + 1) begin
            for (j = 0; j < GRID_W; j = j + 1) begin
              if (grid_val_n[i][j] != 4'd0) begin
                if (j < min_x_n) min_x_n = j[2:0];
                if (i < min_y_n) min_y_n = i[2:0];
                if (j > max_x_n) max_x_n = j[2:0];
                if (i > max_y_n) max_y_n = i[2:0];
              end
            end
          end

          // Move to previous depth and advance search from last choice
          depth_n = depth - 4'd1;

          // Resume from next config after the one we just tried
          cur_piece_idx_n = pid;
          cur_rot_n       = prot;
          cur_x_n         = px;
          cur_y_n         = py;

          // Advance coordinates similar to failure step
          if (cur_x_n + 1 < GRID_W) begin
            cur_x_n = cur_x_n + 3'd1;
          end else begin
            cur_x_n = 3'd0;
            if (cur_y_n + 1 < GRID_H) begin
              cur_y_n = cur_y_n + 3'd1;
            end else begin
              cur_y_n = 3'd0;
              if (cur_rot_n + 1 < MAX_ROT[1:0]) begin
                cur_rot_n = cur_rot_n + 2'd1;
              end else begin
                cur_rot_n = 2'd0;
                cur_piece_idx_n = cur_piece_idx_n + 3'd1;
              end
            end
          end

          state_n = S_NEXT_TRY;
        end
      end

      S_CHECK_TRE: begin
        if (treasure_ok) begin
          state_n = S_DONE_OK;
        end else begin
          // If this full tiling fails treasure condition, backtrack
          state_n = S_BACKTRACK;
        end
      end

      S_DONE_OK: begin
        // Stay here until next start/reset; done asserted in seq block
        state_n = S_DONE_OK;
      end

      S_DONE_FAIL: begin
        // Stay here until next start/reset
        state_n = S_DONE_FAIL;
      end

      default: begin
        state_n = S_IDLE;
      end
    endcase
  end

  // ------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------
  integer yi, xi;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      depth <= 4'd0;
      cur_piece_idx <= 3'd0;
      cur_rot <= 2'd0;
      cur_x <= 3'd0;
      cur_y <= 3'd0;
      search_exhausted <= 1'b0;
      min_x <= 3'd0;
      min_y <= 3'd0;
      max_x <= 3'd0;
      max_y <= 3'd0;

      map_w <= 3'd0;
      map_h <= 3'd0;
      done  <= 1'b0;

      for (d = 0; d < MAXN; d = d + 1) begin
        used[d]        <= 1'b0;
        place_piece[d] <= 3'd0;
        place_rot[d]   <= 2'd0;
        place_x[d]     <= 3'd0;
        place_y[d]     <= 3'd0;
      end
      for (yi = 0; yi < GRID_H; yi = yi + 1) begin
        for (xi = 0; xi < GRID_W; xi = xi + 1) begin
          grid_val[yi][xi]      <= 4'd0;
          grid_pid[yi][xi]      <= 3'd7;
          solution_grid[yi][xi] <= 4'd0;
          piece_grid[yi][xi]    <= 3'd0;
        end
      end
    end else begin
      state            <= state_n;
      depth            <= depth_n;
      cur_piece_idx    <= cur_piece_idx_n;
      cur_rot          <= cur_rot_n;
      cur_x            <= cur_x_n;
      cur_y            <= cur_y_n;
      search_exhausted <= search_exhausted_n;
      min_x            <= min_x_n;
      min_y            <= min_y_n;
      max_x            <= max_x_n;
      max_y            <= max_y_n;

      for (d = 0; d < MAXN; d = d + 1) begin
        used[d]        <= used_n[d];
        place_piece[d] <= place_piece_n[d];
        place_rot[d]   <= place_rot_n[d];
        place_x[d]     <= place_x_n[d];
        place_y[d]     <= place_y_n[d];
      end
      for (yi = 0; yi < GRID_H; yi = yi + 1) begin
        for (xi = 0; xi < GRID_W; xi = xi + 1) begin
          grid_val[yi][xi] <= grid_val_n[yi][xi];
          grid_pid[yi][xi] <= grid_pid_n[yi][xi];
        end
      end

      // Handle outputs and done flag
      case (state_n)
        S_DONE_OK: begin
          // Latch solution grids and dimensions
          map_w <= (max_x_n >= min_x_n) ? (max_x_n - min_x_n + 3'd1) : 3'd0;
          map_h <= (max_y_n >= min_y_n) ? (max_y_n - min_y_n + 3'd1) : 3'd0;
          for (yi = 0; yi < GRID_H; yi = yi + 1) begin
            for (xi = 0; xi < GRID_W; xi = xi + 1) begin
              solution_grid[yi][xi] <= grid_val_n[yi][xi];
              piece_grid[yi][xi]    <= (grid_pid_n[yi][xi] == 3'd7) ? 3'd0 : grid_pid_n[yi][xi];
            end
          end
          done <= 1'b1;
        end
        S_DONE_FAIL: begin
          map_w <= 3'd0;
          map_h <= 3'd0;
          for (yi = 0; yi < GRID_H; yi = yi + 1) begin
            for (xi = 0; xi < GRID_W; xi = xi + 1) begin
              solution_grid[yi][xi] <= 4'd0;
              piece_grid[yi][xi]    <= 3'd0;
            end
          end
          done <= 1'b1;
        end
        default: begin
          // While searching, done is low
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule