module tunnel_connector(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_islands,
  input [3:0] n_trees,
  input [15:0] k,
  input [23:0] island_x [0:7],
  input [23:0] island_y [0:7],
  input [23:0] island_r [0:7],
  input [23:0] tree_x   [0:15],
  input [23:0] tree_y   [0:15],
  input [15:0] tree_h   [0:15],
  output reg done,
  output reg impossible,
  output reg [31:0] tunnel_length
);

  // Internal parameters
  localparam IDLE                 = 4'd0;
  localparam INIT                 = 4'd1;
  localparam ASSIGN_TREE_ISLAND   = 4'd2;
  localparam ASSIGN_CHECK         = 4'd3;
  localparam BUILD_CONN_INIT      = 4'd4;
  localparam BUILD_CONN           = 4'd5;
  localparam CHECK_FULLY_CONN     = 4'd6;
  localparam FIND_MIN_TUNNEL_INIT = 4'd7;
  localparam FIND_MIN_TUNNEL      = 4'd8;
  localparam DONE_STATE           = 4'd9;

  // Distance scaling: Q16.8
  localparam integer FP_SHIFT = 8;
  localparam [31:0] BUFFER_CM = 32'd200; // 200 cm buffer
  localparam [31:0] BUFFER_CM_FP = (BUFFER_CM << FP_SHIFT);

  // Internal signals
  reg [3:0] state, next_state;

  // Tree to island mapping; 3 bits enough for 0-7, plus a flag for found
  reg [2:0] tree_island [0:15];
  reg       tree_assigned [0:15];

  // Max throw per tree in Q16.8
  reg [31:0] tree_throw [0:15];

  // Union-Find parent (up to 8 islands)
  reg [2:0] uf_parent [0:7];

  // Loop indices
  reg [3:0] idx_tree;      // 0-15
  reg [2:0] idx_island;    // 0-7
  reg [2:0] idx_island2;   // 0-7

  // For ASSIGN_TREE_ISLAND distance compute
  reg [23:0] cur_tx, cur_ty;
  reg [23:0] cur_ix, cur_iy, cur_ir;
  reg [31:0] dx_abs, dy_abs;
  reg [47:0] dx_sq, dy_sq;
  reg [47:0] dist2;
  reg [47:0] r_sq;

  // For BUILD_CONN and MIN_TUNNEL: reuse distance engine with fixed-point
  reg [31:0] dx_fp_abs, dy_fp_abs;
  reg [47:0] dx_fp_sq, dy_fp_sq;
  reg [47:0] dist2_fp;

  // Comparison helper
  reg inside_flag;

  // Connectivity intermediate
  reg [31:0] throw_i, throw_j;
  reg [31:0] sum_throw;

  // Minimal tunnel length search
  reg [31:0] min_tunnel_fp; // Q16.8
  reg [31:0] cur_tunnel_fp;
  reg        any_unconn_pair;

  integer i;

  // -------------------- Helper tasks/functions --------------------

  // Absolute difference (24-bit to 32-bit)
  function [31:0] abs_diff_24;
    input [23:0] a;
    input [23:0] b;
    begin
      if (a >= b) abs_diff_24 = {8'd0, (a - b)};
      else        abs_diff_24 = {8'd0, (b - a)};
    end
  endfunction

  // 32-bit absolute difference
  function [31:0] abs_diff_32;
    input [31:0] a;
    input [31:0] b;
    begin
      if (a >= b) abs_diff_32 = a - b;
      else        abs_diff_32 = b - a;
    end
  endfunction

  // Square 32-bit to 48-bit (truncated)
  function [47:0] square32_to48;
    input [31:0] v;
    reg [63:0] tmp;
    begin
      tmp = v * v;
      square32_to48 = tmp[47:0];
    end
  endfunction

  // Square 24-bit to 48-bit
  function [47:0] square24_to48;
    input [23:0] v;
    reg [47:0] tmp;
    begin
      tmp = v * v;
      square24_to48 = tmp;
    end
  endfunction

  // Approximate integer sqrt for up to 48-bit input, output 24-bit
  function [23:0] isqrt48;
    input [47:0] op;
    reg [47:0] rem;
    reg [47:0] root;
    reg [47:0] test_div;
    integer j;
    begin
      rem  = 0;
      root = 0;
      for (j = 0; j < 24; j = j + 1) begin
        rem = {rem[45:0], op[47-2*j -: 2]};
        test_div = (root << 1) + 1;
        if (rem >= test_div) begin
          rem  = rem - test_div;
          root = (root >> 1) + (48'h1 << 23);
        end else begin
          root = (root >> 1);
        end
      end
      isqrt48 = root[23:0];
    end
  endfunction

  // Union-Find: find with path compression (combinational style, small N)
  function [2:0] uf_find;
    input [2:0] x;
    reg [2:0] p0, p1;
    begin
      p0 = uf_parent[x];
      if (p0 == x) begin
        uf_find = x;
      end else begin
        p1 = uf_parent[p0];
        if (p1 == p0) begin
          uf_find = p0;
        end else begin
          // simple 2-level compression
          uf_find = uf_parent[p1];
        end
      end
    end
  endfunction

  task uf_union;
    input [2:0] a;
    input [2:0] b;
    reg [2:0] ra, rb;
    begin
      ra = uf_find(a);
      rb = uf_find(b);
      if (ra != rb) begin
        uf_parent[rb] <= ra;
      end
    end
  endtask

  // Determine all islands connected (check if single set)
  function fully_connected;
    input [2:0] n_is;
    reg [2:0] root0;
    reg all_one;
    reg [2:0] i_local;
    begin
      if (n_is <= 1) begin
        fully_connected = 1'b1;
      end else begin
        root0 = uf_find(3'd0);
        all_one = 1'b1;
        for (i_local = 3'd1; i_local < n_is; i_local = i_local + 1) begin
          if (uf_find(i_local) != root0)
            all_one = 1'b0;
        end
        fully_connected = all_one;
      end
    end
  endfunction

  // -------------------- FSM Sequential --------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      tunnel_length <= 32'd0;
      idx_tree <= 4'd0;
      idx_island <= 3'd0;
      idx_island2 <= 3'd0;
      min_tunnel_fp <= 32'hFFFFFFFF;
      any_unconn_pair <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        tree_island[i] <= 3'd0;
        tree_assigned[i] <= 1'b0;
        tree_throw[i] <= 32'd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        uf_parent[i] <= i[2:0];
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            done <= 1'b0;
            impossible <= 1'b0;
            tunnel_length <= 32'd0;
          end
        end

        INIT: begin
          // Initialize data
          for (i = 0; i < 16; i = i + 1) begin
            tree_assigned[i] <= 1'b0;
            tree_island[i] <= 3'd0;
            // compute tree_throw in Q16.8: k * h << 8
            // clamp width to 32 bits
            tree_throw[i] <= ({16'd0, k} * {16'd0, tree_h[i]}) << FP_SHIFT;
          end
          for (i = 0; i < 8; i = i + 1) begin
            uf_parent[i] <= i[2:0];
          end
          idx_tree <= 4'd0;
          idx_island <= 3'd0;
        end

        ASSIGN_TREE_ISLAND: begin
          // For current tree and current island: check if inside
          cur_tx = tree_x[idx_tree];
          cur_ty = tree_y[idx_tree];
          cur_ix = island_x[idx_island];
          cur_iy = island_y[idx_island];
          cur_ir = island_r[idx_island];

          dx_abs = abs_diff_24(cur_tx, cur_ix);
          dy_abs = abs_diff_24(cur_ty, cur_iy);
          dx_sq = square24_to48(dx_abs[23:0]);
          dy_sq = square24_to48(dy_abs[23:0]);
          dist2 = dx_sq + dy_sq;
          r_sq = square24_to48(cur_ir);

          inside_flag = (dist2 <= r_sq);

          if (!tree_assigned[idx_tree] && inside_flag) begin
            tree_assigned[idx_tree] <= 1'b1;
            tree_island[idx_tree] <= idx_island;
          end

          if (idx_island + 1 < n_islands) begin
            idx_island <= idx_island + 1'b1;
          end else begin
            idx_island <= 3'd0;
            if (idx_tree + 1 < n_trees) begin
              idx_tree <= idx_tree + 1'b1;
            end
          end
        end

        ASSIGN_CHECK: begin
          // Check all trees assigned; if any not assigned, impossible
          impossible <= 1'b0;
          for (i = 0; i < n_trees; i = i + 1) begin
            if (!tree_assigned[i]) begin
              impossible <= 1'b1;
            end
          end
          idx_tree <= 4'd0;
          idx_island <= 3'd0;
          idx_island2 <= 3'd0;
          min_tunnel_fp <= 32'hFFFFFFFF;
          any_unconn_pair <= 1'b0;
        end

        BUILD_CONN_INIT: begin
          // reset UF parents again for safety
          for (i = 0; i < n_islands; i = i + 1) begin
            uf_parent[i] <= i[2:0];
          end
          idx_tree <= 4'd0;
        end

        BUILD_CONN: begin
          // Connect islands using throw distances
          // For each pair of trees i,j (i<j): if they belong to different islands
          // and distance <= sum of throws, union those islands.
          // Implement with nested indices encoded in idx_tree and idx_island.

          // We repurpose idx_tree (outer) and idx_island (inner as j)
          if (idx_tree < n_trees) begin
            if (idx_island < n_trees) begin
              if (idx_island > idx_tree) begin
                if (tree_assigned[idx_tree] && tree_assigned[idx_island]) begin
                  if (tree_island[idx_tree] != tree_island[idx_island]) begin
                    // distance between trees in Q16.8
                    dx_fp_abs = abs_diff_24(tree_x[idx_tree], tree_x[idx_island]) << FP_SHIFT;
                    dy_fp_abs = abs_diff_24(tree_y[idx_tree], tree_y[idx_island]) << FP_SHIFT;
                    dx_fp_sq = square32_to48(dx_fp_abs);
                    dy_fp_sq = square32_to48(dy_fp_abs);
                    dist2_fp = dx_fp_sq + dy_fp_sq;

                    // Check (distance)^2 <= (sum_throw)^2 without sqrt
                    throw_i = tree_throw[idx_tree];
                    throw_j = tree_throw[idx_island];
                    sum_throw = throw_i + throw_j;
                    if (sum_throw != 32'd0) begin
                      if (dist2_fp <= square32_to48(sum_throw)) begin
                        uf_union(tree_island[idx_tree], tree_island[idx_island]);
                      end
                    end
                  end
                end
              end
              idx_island <= idx_island + 1'b1;
            end else begin
              idx_island <= 4'd0;
              idx_tree <= idx_tree + 1'b1;
            end
          end
        end

        CHECK_FULLY_CONN: begin
          // Evaluate connectivity
          if (fully_connected(n_islands)) begin
            tunnel_length <= 32'd0;
            done <= 1'b1;
          end
          // prepare indices for min tunnel if needed
          idx_island <= 3'd0;
          idx_island2 <= 3'd1;
          min_tunnel_fp <= 32'hFFFFFFFF;
          any_unconn_pair <= 1'b0;
        end

        FIND_MIN_TUNNEL_INIT: begin
          // no specific sequential logic; indices already set
        end

        FIND_MIN_TUNNEL: begin
          // Evaluate all island pairs (i<j) not already connected
          if (idx_island < n_islands) begin
            if (idx_island2 < n_islands) begin
              if (idx_island2 > idx_island) begin
                if (uf_find(idx_island) != uf_find(idx_island2)) begin
                  // Compute center distance in Q16.8
                  dx_fp_abs = abs_diff_24(island_x[idx_island], island_x[idx_island2]) << FP_SHIFT;
                  dy_fp_abs = abs_diff_24(island_y[idx_island], island_y[idx_island2]) << FP_SHIFT;
                  dx_fp_sq = square32_to48(dx_fp_abs);
                  dy_fp_sq = square32_to48(dy_fp_abs);
                  dist2_fp = dx_fp_sq + dy_fp_sq;

                  // dist centers
                  // Use integer sqrt approximated on 48 bits
                  // Output in Q16.8 because inputs were scaled
                  // But isqrt48 expects non-scaled; here correct because dist2_fp is scaled^2
                  // So sqrt returns scaled distance.
                  begin
                    reg [23:0] d_sqrt;
                    reg [31:0] center_dist_fp;
                    reg [31:0] r_sum_fp;
                    reg [31:0] border_dist_fp;
                    d_sqrt = isqrt48(dist2_fp);
                    center_dist_fp = {8'd0, d_sqrt};
                    r_sum_fp = ({8'd0, island_r[idx_island]} + {8'd0, island_r[idx_island2]}) << FP_SHIFT;
                    if (center_dist_fp > r_sum_fp) begin
                      border_dist_fp = center_dist_fp - r_sum_fp;
                      // Apply 200cm buffer
                      if (border_dist_fp > BUFFER_CM_FP)
                        cur_tunnel_fp = border_dist_fp - BUFFER_CM_FP;
                      else
                        cur_tunnel_fp = 32'd0;

                      any_unconn_pair <= 1'b1;

                      if (cur_tunnel_fp < min_tunnel_fp)
                        min_tunnel_fp <= cur_tunnel_fp;
                    end
                  end
                end
              end
              idx_island2 <= idx_island2 + 1'b1;
            end else begin
              idx_island <= idx_island + 1'b1;
              idx_island2 <= idx_island + 2; // ensure j>i
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // -------------------- FSM Combinational Next State --------------------

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end

      INIT: begin
        next_state = (n_trees == 0 || n_islands == 0) ? DONE_STATE : ASSIGN_TREE_ISLAND;
      end

      ASSIGN_TREE_ISLAND: begin
        // when all combinations processed
        if (idx_tree == (n_trees-1) && idx_island == (n_islands-1)) begin
          next_state = ASSIGN_CHECK;
        end
      end

      ASSIGN_CHECK: begin
        if (impossible) begin
          next_state = DONE_STATE;
        end else begin
          next_state = BUILD_CONN_INIT;
        end
      end

      BUILD_CONN_INIT: begin
        if (n_trees <= 1 || n_islands <= 1) begin
          next_state = CHECK_FULLY_CONN;
        end else begin
          next_state = BUILD_CONN;
        end
      end

      BUILD_CONN: begin
        if (idx_tree == (n_trees-1) && idx_island == (n_trees)) begin
          next_state = CHECK_FULLY_CONN;
        end
      end

      CHECK_FULLY_CONN: begin
        if (tunnel_length == 32'd0 && fully_connected(n_islands)) begin
          next_state = DONE_STATE;
        end else begin
          next_state = FIND_MIN_TUNNEL_INIT;
        end
      end

      FIND_MIN_TUNNEL_INIT: begin
        if (n_islands <= 1) begin
          next_state = DONE_STATE;
        end else begin
          next_state = FIND_MIN_TUNNEL;
        end
      end

      FIND_MIN_TUNNEL: begin
        if (idx_island >= n_islands) begin
          // search finished
          if (!any_unconn_pair || min_tunnel_fp == 32'hFFFFFFFF) begin
            next_state = DONE_STATE;
          end else begin
            next_state = DONE_STATE;
          end
        end
      end

      DONE_STATE: begin
        if (!start) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // -------------------- Output finalization --------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tunnel_length <= 32'd0;
      impossible <= 1'b0;
    end else begin
      // When entering DONE_STATE from FIND_MIN_TUNNEL or others
      if (state == FIND_MIN_TUNNEL && next_state == DONE_STATE) begin
        if (!any_unconn_pair || min_tunnel_fp == 32'hFFFFFFFF) begin
          // No connectable pairs -> impossible
          impossible <= 1'b1;
          tunnel_length <= 32'd0;
        end else begin
          // Convert Q16.8 to integer cm by truncation
          tunnel_length <= min_tunnel_fp[31:FP_SHIFT];
        end
      end
      if (state == CHECK_FULLY_CONN && next_state == DONE_STATE) begin
        // fully connected without tunnels
        tunnel_length <= 32'd0;
        impossible <= 1'b0;
      end
    end
  end

endmodule