module packman_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] game_field, // 2-bit per cell: 01='*', 10='P', 00='.'
  output reg [5:0] min_time, // 6-bit output (max time 32)
  output reg done // high when computation completes
);
  // Grid positions mapping: idx = y*4 + x, where y,x in [0:3]
  function [3:0] idx_to_x(input [3:0] idx);
    idx_to_x = idx[1:0];
  endfunction
  function [3:0] idx_to_y(input [3:0] idx);
    idx_to_y = idx[3:2];
  endfunction
  function [3:0] xy_to_idx(input [1:0] x, input [1:0] y);
    xy_to_idx = {y, x};
  endfunction
  function [1:0] field2(input [15:0] gf, input [3:0] i);
    field2 = gf[i*2 +: 2];
  endfunction

  // BFS queue utilities
  function [3:0] pop_front(input [7:0] head, input [7:0] tail, input [7:0] q0, input [7:0] q1);
    if (head < 4)      pop_front = q0[head*4 +: 4];
    else if (head < 8) pop_front = q1[(head-4)*4 +: 4];
    else               pop_front = 4'b0;
  endfunction
  function push_back_ready(input [3:0] in, input [7:0] head, input [7:0] tail, input [7:0] q0, input [7:0] q1);
    push_back_ready = 1'b0; // dummy to satisfy simulators
  endfunction

  // Parse positions (combinational)
  logic [3:0] pack_idx [5]; // up to 6 packmen, 5th dummy to align with SystemVerilog fixed-size arrays
  logic [3:0] star_idx  [15];
  logic [3:0] pack_cnt, star_cnt;
  logic [3:0] p0, p1, p2, p3, p4, p5;
  logic [3:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15;
  integer i, pi, si;
  initial begin
    pack_idx[0] = 4'd0; pack_idx[1] = 4'd0; pack_idx[2] = 4'd0; pack_idx[3] = 4'd0; pack_idx[4] = 4'd0; pack_idx[5] = 4'd0;
    star_idx[0] = 4'd0; star_idx[1] = 4'd0; star_idx[2] = 4'd0; star_idx[3] = 4'd0; star_idx[4] = 4'd0; star_idx[5] = 4'd0; star_idx[6] = 4'd0; star_idx[7] = 4'd0;
    star_idx[8] = 4'd0; star_idx[9] = 4'd0; star_idx[10] = 4'd0; star_idx[11] = 4'd0; star_idx[12] = 4'd0; star_idx[13] = 4'd0; star_idx[14] = 4'd0; star_idx[15] = 4'd0;
  end
  always @(*) begin
    pack_cnt = 4'd0; star_cnt = 4'd0;
    for (i = 0; i < 16; i = i + 1) begin
      case (field2(game_field, i))
        2'b10: begin // 'P'
          if (pack_cnt < 6) begin
            pack_idx[pack_cnt] = i[3:0];
            pack_cnt = pack_cnt + 1;
          end
        end
        2'b01: begin // '*'
          if (star_cnt < 16) begin
            star_idx[star_cnt] = i[3:0];
            star_cnt = star_cnt + 1;
          end
        end
        default: ;
      endcase
    end
    p0 = pack_idx[0]; p1 = pack_idx[1]; p2 = pack_idx[2]; p3 = pack_idx[3]; p4 = pack_idx[4]; p5 = pack_idx[5];
    s0 = star_idx[0];  s1 = star_idx[1];  s2 = star_idx[2];  s3 = star_idx[3];  s4 = star_idx[4];  s5 = star_idx[5];  s6 = star_idx[6];  s7 = star_idx[7];
    s8 = star_idx[8];  s9 = star_idx[9];  s10 = star_idx[10]; s11 = star_idx[11]; s12 = star_idx[12]; s13 = star_idx[13]; s14 = star_idx[14]; s15 = star_idx[15];
  end

  // BFS state for up to 6 packmen (max 16 cells, we use depth 6)
  reg [3:0] bfs_p [6];     // packman base idx per BFS stream
  reg [1:0] bfs_depth;     // current BFS expansion depth (0..6)
  reg [7:0] head, tail;    // queue pointers
  reg [15:0] dist [6];     // distance bitmasks (bit j set if cell j reachable at current depth for that packman)
  reg [15:0] frontier [6]; // frontier masks per packman per depth
  reg [15:0] visited [6];  // visited masks per packman per depth
  reg bfs_done;
  reg [3:0] pid; // current packman index for BFS
  integer d, c, k;
  logic [15:0] neighbors;
  logic [3:0] cur, nx, ny;

  // Binary search bounds and midpoint evaluation (sequential)
  reg [5:0] l, r, m;
  reg [5:0] l_next, r_next;
  reg start_q, run_q, run_q2, run_q3, run_q4, run_q5;
  logic coverage_at_m; // comb coverage check at current 'm'

  // Registers to carry minimal time in-progress
  reg [5:0] min_time_inprog;

  // Helper: coverage check for current 'm'
  logic p0_can, p1_can, p2_can, p3_can, p4_can, p5_can;
  // Bitmask of cells reachable by each packman within m steps
  logic [15:0] reach_mask [6];
  // Stars reachability masks per packman within m
  logic [15:0] star_mask_reachable [6];
  // Combined reach of all packmen
  logic [15:0] union_reach;

  function [15:0] manhattan_ball_mask(input [3:0] center, input [3:0] maxd);
    integer dx, dy, d, x0, y0, x, y;
    logic [15:0] mask;
    mask = 16'd0;
    x0 = idx_to_x(center);
    y0 = idx_to_y(center);
    for (x = 0; x < 4; x = x + 1) begin
      for (y = 0; y < 4; y = y + 1) begin
        dx = (x0 > x) ? (x0 - x) : (x - x0);
        dy = (y0 > y) ? (y0 - y) : (y - y0);
        d = dx + dy;
        if (d <= maxd) mask[xy_to_idx(x[1:0], y[1:0])] = 1'b1;
      end
    end
    manhattan_ball_mask = mask;
  endfunction

  genvar gi;
  generate
    for (gi = 0; gi < 6; gi = gi + 1) begin : reach_masks_gen
      assign reach_mask[gi] = manhattan_ball_mask(bfs_p[gi], m);
    end
  endgenerate

  function [15:0] mask_for_stars(input [15:0] star_mask);
    // star_mask: 16-bit with 1 where stars exist
    mask_for_stars = star_mask; // pass-through for readability
  endfunction
  logic [15:0] star_cells_mask;
  always @(*) begin
    star_cells_mask = 16'd0;
    for (c = 0; c < 16; c = c + 1)
      if (field2(game_field, c) == 2'b01) star_cells_mask[c] = 1'b1;
  end

  // Per-packman reachability to stars within time m
  assign star_mask_reachable[0] = reach_mask[0] & star_cells_mask;
  assign star_mask_reachable[1] = reach_mask[1] & star_cells_mask;
  assign star_mask_reachable[2] = reach_mask[2] & star_cells_mask;
  assign star_mask_reachable[3] = reach_mask[3] & star_cells_mask;
  assign star_mask_reachable[4] = reach_mask[4] & star_cells_mask;
  assign star_mask_reachable[5] = reach_mask[5] & star_cells_mask;

  // Union of all packmen reach
  assign union_reach = star_mask_reachable[0] |
                       star_mask_reachable[1] |
                       star_mask_reachable[2] |
                       star_mask_reachable[3] |
                       star_mask_reachable[4] |
                       star_mask_reachable[5];
  assign coverage_at_m = (union_reach == star_cells_mask);

  // Sequential control
  reg [2:0] cyc; // 0..5 after start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      min_time <= 6'd0;
      min_time_inprog <= 6'd0;
      l <= 6'd0; r <= 6'd32; m <= 6'd16;
      bfs_done <= 1'b0;
      cyc <= 3'd0;
      start_q <= 1'b0; run_q <= 1'b0; run_q2 <= 1'b0; run_q3 <= 1'b0; run_q4 <= 1'b0; run_q5 <= 1'b0;
      for (k = 0; k < 6; k = k + 1) begin
        bfs_p[k] <= 4'd0;
        dist[k] <= 16'd0;
        frontier[k] <= 16'd0;
        visited[k] <= 16'd0;
      end
    end else begin
      // 1-cycle input pipeline for start
      start_q <= start;
      run_q <= start_q;
      run_q2 <= run_q;
      run_q3 <= run_q2;
      run_q4 <= run_q3;
      run_q5 <= run_q4;

      if (!start && !start_q) begin
        // idle reset of state when not started
        done <= 1'b0;
        l <= 6'd0; r <= 6'd32; m <= 6'd16;
        bfs_done <= 1'b0;
        cyc <= 3'd0;
        for (k = 0; k < 6; k = k + 1) begin
          bfs_p[k] <= 4'd0;
          dist[k] <= 16'd0;
          frontier[k] <= 16'd0;
          visited[k] <= 16'd0;
        end
        min_time_inprog <= 6'd0;
      end

      if (run_q && !run_q2) begin
        // Start: cycle 0
        l <= 6'd0;
        r <= 6'd32;
        m <= 6'd16;
        l_next <= 6'd0; r_next <= 6'd32;
        bfs_depth <= 2'd0;
        bfs_done <= 1'b0;
        cyc <= 3'd0;
        min_time_inprog <= 6'd0;
        // seed BFS with packmen
        for (k = 0; k < 6; k = k + 1) begin
          bfs_p[k] <= (k < pack_cnt) ? pack_idx[k] : 4'd0;
          dist[k] <= 16'd0;
          frontier[k] <= 16'd0;
          visited[k] <= 16'd0;
        end
        done <= 1'b0;
      end else if (run_q2 && !run_q3) begin
        // Cycle 1: BFS 0th layer initialization
        bfs_depth <= 2'd0;
        for (k = 0; k < 6; k = k + 1) begin
          if (k < pack_cnt) begin
            frontier[k][bfs_p[k]] <= 1'b1;
            visited[k][bfs_p[k]] <= 1'b1;
            dist[k][bfs_p[k]] <= 1'b1;
          end else begin
            frontier[k] <= 16'd0;
            visited[k] <= 16'd0;
            dist[k] <= 16'd0;
          end
        end
        // Prepare binary search first midpoint and bounds
        m <= 6'd16;
        l <= 6'd0;
        r <= 6'd32;
      end else if (run_q3 && !run_q4) begin
        // Cycle 2: BFS expansion depths 0->1 and 1->2 (pipelined)
        bfs_depth <= 2'd2; // processed depths 0 and 1; frontier currently at depth 2
        for (k = 0; k < 6; k = k + 1) begin
          if (k < pack_cnt) begin
            logic [15:0] new_frontier, new_visited;
            new_frontier = 16'd0;
            new_visited = visited[k];
            for (c = 0; c < 16; c = c + 1) begin
              if (frontier[k][c]) begin
                // expand to neighbors in 4-neighborhood
                nx = idx_to_x(c);
                ny = idx_to_y(c);
                if (nx > 2'd0) begin
                  d = xy_to_idx(nx-2'd1, ny);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (nx < 2'd3) begin
                  d = xy_to_idx(nx+2'd1, ny);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (ny > 2'd0) begin
                  d = xy_to_idx(nx, ny-2'd1);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (ny < 2'd3) begin
                  d = xy_to_idx(nx, ny+2'd1);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
              end
            end
            frontier[k] <= new_frontier;
            visited[k] <= new_visited;
            dist[k] <= (dist[k] | (new_frontier));
          end else begin
            frontier[k] <= 16'd0;
            visited[k] <= visited[k]; // unchanged
            dist[k] <= dist[k];
          end
        end
        // Binary search step 1 (m=16) using computed dist up to depth 2
        m <= 6'd8;
        if (coverage_at_m) r <= 6'd16; else l <= 6'd16;
      end else if (run_q4 && !run_q5) begin
        // Cycle 3: BFS expansion depths 2->3 and 3->4
        bfs_depth <= 2'd4;
        for (k = 0; k < 6; k = k + 1) begin
          if (k < pack_cnt) begin
            logic [15:0] new_frontier, new_visited;
            new_frontier = 16'd0;
            new_visited = visited[k];
            for (c = 0; c < 16; c = c + 1) begin
              if (frontier[k][c]) begin
                nx = idx_to_x(c);
                ny = idx_to_y(c);
                if (nx > 2'd0) begin
                  d = xy_to_idx(nx-2'd1, ny);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (nx < 2'd3) begin
                  d = xy_to_idx(nx+2'd1, ny);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (ny > 2'd0) begin
                  d = xy_to_idx(nx, ny-2'd1);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
                if (ny < 2'd3) begin
                  d = xy_to_idx(nx, ny+2'd1);
                  if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                end
              end
            end
            frontier[k] <= new_frontier;
            visited[k] <= new_visited;
            dist[k] <= (dist[k] | (new_frontier));
          end else begin
            frontier[k] <= 16'd0;
            visited[k] <= visited[k];
            dist[k] <= dist[k];
          end
        end
        // Binary search step 2 (m=8 or m=24) using computed dist up to depth 4
        if ((r - l) > 6'd1) begin
          m <= (l + r) >> 1;
          if (coverage_at_m) r <= (l + r) >> 1; else l <= (l + r) >> 1;
        end
        bfs_done <= 1'b1;
      end else if (run_q5) begin
        // Cycle 4+: Complete binary search if needed; we have distances up to depth 4+ (ensure full coverage)
        // Continue BFS two more expansions to depth 6 for safety (max needed time is <= 6 on 4x4 grid)
        if (bfs_depth < 2'd6) begin
          bfs_depth <= bfs_depth + 2'd1;
          for (k = 0; k < 6; k = k + 1) begin
            if (k < pack_cnt) begin
              logic [15:0] new_frontier, new_visited;
              new_frontier = 16'd0;
              new_visited = visited[k];
              for (c = 0; c < 16; c = c + 1) begin
                if (frontier[k][c]) begin
                  nx = idx_to_x(c);
                  ny = idx_to_y(c);
                  if (nx > 2'd0) begin
                    d = xy_to_idx(nx-2'd1, ny);
                    if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                  end
                  if (nx < 2'd3) begin
                    d = xy_to_idx(nx+2'd1, ny);
                    if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                  end
                  if (ny > 2'd0) begin
                    d = xy_to_idx(nx, ny-2'd1);
                    if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                  end
                  if (ny < 2'd3) begin
                    d = xy_to_idx(nx, ny+2'd1);
                    if (!new_visited[d]) begin new_frontier[d] = 1'b1; new_visited[d] = 1'b1; end
                  end
                end
              end
              frontier[k] <= new_frontier;
              visited[k] <= new_visited;
              dist[k] <= (dist[k] | (new_frontier));
            end
          end
        end
        // Continue binary search until r-l>1; evaluate coverage_at_m with current 'm'
        if ((r - l) > 6'd1) begin
          m <= (l + r) >> 1;
          if (coverage_at_m) r <= (l + r) >> 1; else l <= (l + r) >> 1;
        end else begin
          done <= 1'b1;
          min_time <= r;        // minimal feasible time
          min_time_inprog <= r; // keep stable for later if needed
        end
      end
    end
  end

endmodule