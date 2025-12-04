module tunnel_connector(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_islands,
  input [3:0] n_trees,
  input [15:0] k,
  input [23:0] island_x[0:7],
  input [23:0] island_y[0:7],
  input [23:0] island_r[0:7],
  input [23:0] tree_x[0:15],
  input [23:0] tree_y[0:15],
  input [15:0] tree_h[0:15],
  output reg done,
  output reg impossible,
  output reg [31:0] tunnel_length
);

  // Q16.8 fixed-point: 16-bit integer, 8-bit fractional
  localparam QF = 8;
  localparam ONE = 256; // 1.0 in Q16.8
  localparam HALF = 128; // 0.5 in Q16.8
  localparam MAX_ISLANDS = 8;
  localparam MAX_TREES = 16;
  localparam BUFFER_CM = 200; // 200 cm buffer
  localparam BUF_Q = BUFFER_CM * ONE; // Q16.8 buffer

  // State machine
  typedef enum logic [3:0] {
    S_IDLE = 4'd0,
    S_PREP = 4'd1,
    S_COMP_THROW = 4'd2,
    S_BUILD_GRAPH = 4'd3,
    S_UNION_PREP = 4'd4,
    S_UNION = 4'd5,
    S_CHECK_CONNECTED = 4'd6,
    S_TUNNEL_LOOP = 4'd7,
    S_DONE = 4'd8
  } state_t;
  state_t state, next_state;

  // Iteration/control counters
  reg [9:0] cycle_cnt; // up to 1024 cycles
  reg [3:0] i, j, t, ii, jj, ui, uj;
  reg [4:0] n_active_islands, n_active_trees;
  reg [7:0] active_island_idx [0:7];
  reg [7:0] active_tree_idx [0:15];
  reg [7:0] tree_island_of [0:15];

  // Derived values (Q16.8)
  reg [31:0] island_x_q [0:7];
  reg [31:0] island_y_q [0:7];
  reg [31:0] island_r_q [0:7];
  reg [31:0] tree_x_q [0:15];
  reg [31:0] tree_y_q [0:15];
  reg [31:0] throw_max_q [0:15];
  reg [31:0] island_k_q [0:7];
  reg [31:0] island_pair_dist_q [0:27]; // max 28 pairs (C(8,2))
  reg island_pair_valid [0:27];
  reg [7:0] pair_i [0:27];
  reg [7:0] pair_j [0:27];
  reg [4:0] n_pairs;

  // Union-Find
  reg [2:0] parent [0:7];
  reg [2:0] rank_u [0:7];
  reg [2:0] root_u [0:7];
  reg [2:0] n_components;

  // Minimal tunnel
  reg [31:0] min_tunnel_q; // Q16.8
  reg found_tunnel;
  reg [2:0] min_ti, min_tj;

  // Temporary/computation variables
  reg [31:0] dx, dy, dist_raw_q, sqrt_in_q, sqrt_out_q;
  reg [31:0] tmp32, tmp32b;
  reg [15:0] thr16;
  reg has_solution;
  reg all_connected;
  reg pair_found_next;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      tunnel_length <= 32'd0;
      cycle_cnt <= 10'd0;
    end else begin
      state <= next_state;
      // cycle counter and done flag
      if (state == S_IDLE) begin
        cycle_cnt <= 10'd0;
        done <= 1'b0;
        impossible <= 1'b0;
      end else begin
        if (next_state != state) begin
          // entering new state
          cycle_cnt <= cycle_cnt + 10'd1;
        end else begin
          cycle_cnt <= cycle_cnt + 10'd1;
        end
        if (next_state == S_DONE) begin
          done <= 1'b1;
        end
      end
    end
  end

  // Next-state logic and datapath
  always @(*) begin
    // defaults to avoid latches
    next_state = state;
    // setup default computations per state
    case (state)
      S_IDLE: begin
        if (start) next_state = S_PREP;
      end

      S_PREP: begin
        // Copy input arrays to Q16.8 (24-bit integer cm => 24<<8)
        // For islands 0..7 and trees 0..15
        // Prepare active lists
        n_active_islands = 5'd0;
        n_active_trees = 5'd0;
        for (i = 0; i < 8; i = i + 1) begin
          island_x_q[i] = {island_x[i], 8'b0};
          island_y_q[i] = {island_y[i], 8'b0};
          island_r_q[i] = {island_r[i], 8'b0};
          if (i < n_islands) begin
            active_island_idx[n_active_islands] = i[7:0];
            n_active_islands = n_active_islands + 5'd1;
          end
        end
        for (t = 0; t < 16; t = t + 1) begin
          tree_x_q[t] = {tree_x[t], 8'b0};
          tree_y_q[t] = {tree_y[t], 8'b0};
          if (t < n_trees) begin
            active_tree_idx[n_active_trees] = t[7:0];
            n_active_trees = n_active_trees + 5'd1;
          end
        end
        next_state = S_COMP_THROW;
      end

      S_COMP_THROW: begin
        // For each active tree, find its island (point-in-circle)
        // and compute throw_max_q = k * tree_h (Q16.16 -> Q16.8)
        // We also compute island_k_q as max throw among its trees.
        for (t = 0; t < 16; t = t + 1) tree_island_of[t] = 8'hFF;
        for (ii = 0; ii < 8; ii = ii + 1) island_k_q[ii] = 32'd0;

        for (t = 0; t < MAX_TREES; t = t + 1) begin
          if (t < n_active_trees) begin
            // Multiplication k * tree_h (Q16.8 * 16-bit integer) => Q16.16, then >> 16 to Q16.8
            tmp32 = k * tree_h[t]; // 32-bit result, top 16 bits are integer part
            throw_max_q[t] = tmp32[31:16]; // Q16.8
            // Find island
            for (ii = 0; ii < MAX_ISLANDS; ii = ii + 1) begin
              if (ii < n_active_islands) begin
                dx = (tree_x_q[t] - island_x_q[ii]);
                dy = (tree_y_q[t] - island_y_q[ii]);
                // dist^2 = dx^2 + dy^2, both in Q16.8 => Q16.16
                tmp32 = dx * dx;
                tmp32b = dy * dy;
                dist_raw_q = tmp32 + tmp32b; // Q16.16
                // r^2 in Q16.16: (r<<8)*(r<<8) = r*r << 16
                tmp32 = island_r_q[ii][31:8] * island_r_q[ii][31:8]; // r^2 in integer cm^2
                tmp32b = tmp32 << 16; // shift to Q16.16 alignment
                if (dist_raw_q <= tmp32b) begin
                  tree_island_of[t] = ii[7:0];
                  // island_k_q[ii] = max(island_k_q[ii], throw_max_q[t])
                  if (throw_max_q[t] > island_k_q[ii]) island_k_q[ii] = throw_max_q[t];
                end
              end
            end
          end else begin
            throw_max_q[t] = 32'd0;
          end
        end
        next_state = S_BUILD_GRAPH;
      end

      S_BUILD_GRAPH: begin
        // Build island pair connectivity: connected if distance(centers) <= sum(throws) + r_i + r_j
        // Compute pair list (i<j among active islands) and store distance.
        n_pairs = 5'd0;
        for (ii = 0; ii < MAX_ISLANDS; ii = ii + 1) begin
          if (ii < n_active_islands) begin
            for (jj = ii + 1; jj < MAX_ISLANDS; jj = jj + 1) begin
              if (jj < n_active_islands) begin
                // Euclidean distance between centers in Q16.8 (integer cm to Q16.8)
                dx = (island_x_q[jj] - island_x_q[ii]);
                dy = (island_y_q[jj] - island_y_q[ii]);
                // dist_raw_q in Q16.16
                tmp32 = dx * dx;
                tmp32b = dy * dy;
                dist_raw_q = tmp32 + tmp32b;
                // sqrt to Q16.8
                sqrt_in_q = dist_raw_q; // Q16.16
                sqrt_out_q = q16_16_to_q16_8_sqrt(sqrt_in_q);
                // Check connectivity threshold
                // sumThrows = island_k_q[ii] + island_k_q[jj]
                tmp32 = island_k_q[ii] + island_k_q[jj];
                // Add radii: (r_i + r_j) in Q16.8
                tmp32b = island_r_q[ii][31:8] + island_r_q[jj][31:8];
                // threshold = sumThrows + r_i + r_j  (Q16.8)
                if (sqrt_out_q <= (tmp32 + tmp32b)) begin
                  island_pair_valid[n_pairs] = 1'b1;
                end else begin
                  island_pair_valid[n_pairs] = 1'b0;
                end
                island_pair_dist_q[n_pairs] = sqrt_out_q;
                pair_i[n_pairs] = ii[7:0];
                pair_j[n_pairs] = jj[7:0];
                n_pairs = n_pairs + 5'd1;
              end
            end
          end
        end
        next_state = S_UNION_PREP;
      end

      S_UNION_PREP: begin
        // Initialize Union-Find for active islands
        for (ii = 0; ii < MAX_ISLANDS; ii = ii + 1) begin
          parent[ii] = ii[2:0];
          rank_u[ii] = 3'd0;
        end
        n_components = n_active_islands[2:0];
        ui = 3'd0;
        next_state = S_UNION;
      end

      S_UNION: begin
        // Process each valid pair to union their components
        if (ui < n_pairs) begin
          if (island_pair_valid[ui]) begin
            // union(pair_i[ui], pair_j[ui])
            uf_union(.a(pair_i[ui]), .b(pair_j[ui]), .parent_arr(parent), .rank_arr(rank_u), .ncomp(n_components));
          end
          ui = ui + 3'd1;
          next_state = S_UNION;
        end else begin
          next_state = S_CHECK_CONNECTED;
        end
      end

      S_CHECK_CONNECTED: begin
        // Determine all_connected
        all_connected = (n_components == 3'd1);
        min_tunnel_q = 32'h7FFFFFFF; // big positive
        min_ti = 3'd0;
        min_tj = 3'd0;
        found_tunnel = 1'b0;
        if (all_connected) begin
          next_state = S_DONE;
        end else begin
          next_state = S_TUNNEL_LOOP;
        end
      end

      S_TUNNEL_LOOP: begin
        // Search over all active island pairs not in the same component
        // Compute min_tunnel_q = min(distance(centers) - r_i - r_j - BUF_Q)
        pair_found_next = 1'b0;
        // Refresh roots per loop to support sequential find
        for (ii = 0; ii < MAX_ISLANDS; ii = ii + 1) begin
          root_u[ii] = uf_find(.a(ii[2:0]), .parent_arr(parent));
        end
        // Search
        for (ii = 0; ii < MAX_ISLANDS; ii = ii + 1) begin
          if (ii < n_active_islands) begin
            for (jj = ii + 1; jj < MAX_ISLANDS; jj = jj + 1) begin
              if (jj < n_active_islands) begin
                if (root_u[ii] != root_u[jj]) begin
                  // compute distance
                  dx = (island_x_q[jj] - island_x_q[ii]);
                  dy = (island_y_q[jj] - island_y_q[ii]);
                  tmp32 = dx * dx;
                  tmp32b = dy * dy;
                  dist_raw_q = tmp32 + tmp32b;
                  sqrt_out_q = q16_16_to_q16_8_sqrt(dist_raw_q);
                  // subtract radii and buffer
                  tmp32 = island_r_q[ii][31:8] + island_r_q[jj][31:8] + BUF_Q; // Q16.8
                  // if distance >= radii+buffer, tunnel length candidate
                  if (sqrt_out_q >= tmp32) begin
                    tmp32b = sqrt_out_q - tmp32; // Q16.8
                    if (tmp32b < min_tunnel_q) begin
                      min_tunnel_q = tmp32b;
                      min_ti = ii[2:0];
                      min_tj = jj[2:0];
                      found_tunnel = 1'b1;
                    end
                  end
                end
              end
            end
          end
        end
        // After one full scan, we are done with min_tunnel_q
        if (found_tunnel) begin
          has_solution = 1'b1;
        end else begin
          has_solution = 1'b0;
        end
        next_state = S_DONE;
      end

      S_DONE: begin
        // finalize outputs
        if (all_connected) begin
          tunnel_length = 32'd0;
          impossible = 1'b0;
        end else begin
          if (has_solution) begin
            // Convert Q16.8 to integer centimeters with rounding
            // tunnel_length = (min_tunnel_q + 0.5) in integer cm
            // min_tunnel_q is Q16.8, add 0.5 = +128
            tmp32 = min_tunnel_q + 32'd128;
            tunnel_length = tmp32[31:8]; // integer cm
            impossible = 1'b0;
          end else begin
            tunnel_length = 32'd0;
            impossible = 1'b1;
          end
        end
        // remain in DONE until start deasserted
        if (!start) next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Utility functions
  // Q16.16 sqrt => Q16.8 (integer sqrt of (Q16.16 >> 8) then << 8)
  function [31:0] q16_16_to_q16_8_sqrt;
    input [31:0] x; // Q16.16
    reg [31:0] x_int;
    reg [15:0] g;
    begin
      // x >= 0 assumed
      // Shift right by 8 to get Q16.8 integer part (floor)
      x_int = x >> 8; // 24-bit-ish integer
      // integer sqrt via Newton-Raphson
      g = 16'd256; // initial guess ~ sqrt(x_int)
      // 8 iterations for 16-bit value is enough
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      g = (g + (x_int / g)) >> 1;
      // shift left by 8 to convert back to Q16.8
      q16_16_to_q16_8_sqrt = {g, 8'b0};
    end
  endfunction

  // Union-Find find with path compression (3-bit indices)
  function [2:0] uf_find;
    input [2:0] a;
    input [2:0] parent_arr [0:7];
    reg [2:0] p;
    begin
      p = a;
      while (p != parent_arr[p]) begin
        p = parent_arr[p];
      end
      // compress
      uf_find = p;
    end
  endfunction

  // Union with union-by-rank, updates component count
  task uf_union;
    input [2:0] a;
    input [2:0] b;
    inout [2:0] parent_arr [0:7];
    inout [2:0] rank_arr [0:7];
    inout [2:0] ncomp;
    reg [2:0] ra, rb;
    begin
      ra = uf_find(a, parent_arr);
      rb = uf_find(b, parent_arr);
      if (ra != rb) begin
        if (rank_arr[ra] < rank_arr[rb]) begin
          parent_arr[ra] = rb;
        end else if (rank_arr[ra] > rank_arr[rb]) begin
          parent_arr[rb] = ra;
        end else begin
          parent_arr[rb] = ra;
          rank_arr[ra] = rank_arr[ra] + 3'd1;
        end
        ncomp = ncomp - 3'd1;
      end
    end
  endtask

endmodule