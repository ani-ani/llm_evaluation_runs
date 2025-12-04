module manhattan_mst(
  input clk,                   // clock
  input rst_n,                 // active-low reset
  input start,                 // pulse high to start computation
  input [3:0] num_points,      // number of points (1-8)
  input [9:0] x[0:7],          // x coordinates (10-bit each)
  input [9:0] y[0:7],          // y coordinates (10-bit each)
  output reg [13:0] mst_weight, // MST weight output (14-bit)
  output reg done               // high when computation completes
);
  // Parameters
  localparam NUM_POINTS = 8;
  localparam MAX_EDGES  = 28; // C(8,2)

  // Types
  typedef struct packed {
    logic [3:0] u;
    logic [3:0] v;
    logic [9:0] w;
  } edge_t;

  // State machine
  typedef enum logic [2:0] {
    S_IDLE    = 3'b000,
    S_GEN     = 3'b001,
    S_SORT    = 3'b010,
    S_KRUSKAL = 3'b011,
    S_DONE    = 3'b100
  } state_t;

  state_t state;

  // Edge storage
  edge_t edges_d, edges_q [MAX_EDGES];
  logic [5:0] edge_count_d, edge_count_q;

  // Sort control
  logic [5:0] i_d, i_q;      // outer loop
  logic [5:0] j_d, j_q;      // inner loop
  logic swapped_d, swapped_q;

  // Kruskal control
  logic [5:0] k_d, k_q;                 // edge index
  logic [3:0] selected_d, selected_q;   // number of selected edges so far
  logic [7:0] parent_d, parent_q;       // union-find parent (8 bits for 0..7)
  logic [13:0] acc_d, acc_q;            // accumulated MST weight
  logic uf_root_u, uf_root_v;
  logic [3:0] find_u, find_v;

  // Edge generation indices
  logic [3:0] ii_d, ii_q; // i index for point a
  logic [3:0] jj_d, jj_q; // j index for point b (within inner loop)
  logic [2:0] sp_d, sp_q; // stage for compute per pair

  // Registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      done         <= 1'b0;
      edge_count_q <= 6'd0;
      for (int e = 0; e < MAX_EDGES; e++) edges_q[e] <= '0;
      i_q          <= 6'd0;
      j_q          <= 6'd0;
      swapped_q    <= 1'b0;
      k_q          <= 6'd0;
      selected_q   <= 4'd0;
      parent_q     <= 8'd0;
      acc_q        <= 14'd0;
      mst_weight   <= 14'd0;
      ii_q         <= 4'd0;
      jj_q         <= 4'd0;
      sp_q         <= 3'd0;
    end else begin
      state        <= state_d;
      done         <= done_d;
      edge_count_q <= edge_count_d;
      edges_q      <= edges_d_arr;
      i_q          <= i_d;
      j_q          <= j_d;
      swapped_q    <= swapped_d;
      k_q          <= k_d;
      selected_q   <= selected_d;
      parent_q     <= parent_d;
      acc_q        <= acc_d;
      mst_weight   <= mst_weight_d;
      ii_q         <= ii_d;
      jj_q         <= jj_d;
      sp_q         <= sp_d;
    end
  end

  // Next-state/combinational signals
  state_t state_d;
  logic done_d;
  logic [5:0] edge_count_d;
  edge_t edges_d_arr [MAX_EDGES];
  logic [5:0] i_d, j_d;
  logic swapped_d;
  logic [5:0] k_d;
  logic [3:0] selected_d;
  logic [7:0] parent_d;
  logic [13:0] acc_d, mst_weight_d;
  logic [3:0] ii_d, jj_d;
  logic [2:0] sp_d;

  // Default assignments
  begin
    state_d     = state;
    done_d      = done;
    edge_count_d = edge_count_q;
    edges_d_arr = edges_q;
    i_d         = i_q;
    j_d         = j_q;
    swapped_d   = swapped_q;
    k_d         = k_q;
    selected_d  = selected_q;
    parent_d    = parent_q;
    acc_d       = acc_q;
    mst_weight_d = mst_weight;
    ii_d        = ii_q;
    jj_d        = jj_q;
    sp_d        = sp_q;
  end

  // Handle start pulse in IDLE
  always_comb begin
    if (state == S_IDLE) begin
      if (start) begin
        state_d = S_GEN;
        done_d  = 1'b0;
      end else begin
        state_d = S_IDLE;
        done_d  = 1'b0;
      end
    end
  end

  // Stage S_GEN: generate all Manhattan edges
  always_comb begin
    if (state == S_GEN) begin
      // Defaults for this state
      state_d = S_GEN;
      edge_count_d = edge_count_q;
      edges_d_arr  = edges_q;
      ii_d = ii_q;
      jj_d = jj_q;
      sp_d = sp_q;

      // Initialize on entry
      if (sp_q == 3'd0 && edge_count_q == 6'd0 && ii_q == 4'd0 && jj_q == 4'd0) begin
        ii_d = 4'd0;
        jj_d = 4'd1;
        sp_d = 3'd1;
        edge_count_d = 6'd0;
      end else begin
        // 3-stage pipeline per edge: wait, compute, write
        case (sp_q)
          3'd1: begin
            // wait for inputs to stabilize (already stable, but keep 1-cycle for timing)
            sp_d = 3'd2;
            ii_d = ii_q;
            jj_d = jj_q;
          end
          3'd2: begin
            // compute weight
            edge_t tmp = edges_q[edge_count_q];
            tmp.u = ii_q;
            tmp.v = jj_q;
            // Manhattan distance
            logic [10:0] dx, dy;
            dx = (x[ii_q] > x[jj_q]) ? (x[ii_q] - x[jj_q]) : (x[jj_q] - x[ii_q]);
            dy = (y[ii_q] > y[jj_q]) ? (y[ii_q] - y[jj_q]) : (y[jj_q] - y[ii_q]);
            tmp.w = dx + dy;
            edges_d_arr[edge_count_q] = tmp;
            sp_d = 3'd3;
          end
          3'd3: begin
            // write and move to next pair
            edge_count_d = edge_count_q + 1;
            sp_d = 3'd1;
            // advance indices (i, j)
            if (jj_q + 1 == num_points) begin
              // end of inner loop for this i
              if (ii_q + 1 == num_points - 1) begin
                // finished all pairs
                ii_d = 4'd0;
                jj_d = 4'd1;
                sp_d = 3'd0;
                state_d = S_SORT;
                // initialize sort variables
                i_d = 6'd0;
                j_d = 6'd1;
                swapped_d = 1'b0;
              end else begin
                ii_d = ii_q + 1;
                jj_d = ii_q + 2; // next j after new i
              end
            end else begin
              ii_d = ii_q;
              jj_d = jj_q + 1;
            end
          end
          default: begin
            sp_d = 3'd1;
          end
        endcase
      end
    end
  end

  // Stage S_SORT: simple bubble sort for up to 28 edges
  always_comb begin
    if (state == S_SORT) begin
      state_d = S_SORT;
      edges_d_arr = edges_q;
      i_d = i_q;
      j_d = j_q;
      swapped_d = swapped_q;

      if (edge_count_q <= 1) begin
        // Nothing to sort
        state_d = S_KRUSKAL;
        k_d = 6'd0;
        selected_d = 4'd0;
        acc_d = 14'd0;
        mst_weight_d = 14'd0;
        for (int p = 0; p < 8; p++) parent_d[p] = p[0]; // parent[i] = i
      end else begin
        // Bubble sort: single pass per cycle, swap if out of order
        if (i_q < edge_count_q) begin
          if (j_q < edge_count_q) begin
            if (j_q > i_q) begin
              if (edges_q[j_q-1].w > edges_q[j_q].w) begin
                // swap edges[j-1] and edges[j]
                edge_t tmp = edges_q[j_q-1];
                edges_d_arr[j_q-1] = edges_q[j_q];
                edges_d_arr[j_q] = tmp;
                swapped_d = 1'b1;
              end
            end
            j_d = j_q + 1;
          end else begin
            // End of inner loop for this i
            if (~swapped_q) begin
              // Early exit: already sorted
              state_d = S_KRUSKAL;
              k_d = 6'd0;
              selected_d = 4'd0;
              acc_d = 14'd0;
              mst_weight_d = 14'd0;
              for (int p = 0; p < 8; p++) parent_d[p] = p[0];
            end else begin
              j_d = 6'd1; // reset j to 1
              i_d = i_q + 1;
              swapped_d = 1'b0; // reset for next pass
            end
          end
        end else begin
          // Completed passes
          state_d = S_KRUSKAL;
          k_d = 6'd0;
          selected_d = 4'd0;
          acc_d = 14'd0;
          mst_weight_d = 14'd0;
          for (int p = 0; p < 8; p++) parent_d[p] = p[0];
        end
      end
    end
  end

  // Helper function for Union-Find find with path compression (combinational)
  function [3:0] find_root(input [3:0] node, input [7:0] parent);
    logic [3:0] cur;
    logic [7:0] p;
    cur = node;
    p = parent;
    while (p[cur]) begin
      // parent[cur] = find(parent[cur])
      p[cur] = p[cur]; // silence工具警告
      if (p[cur] == cur) break;
      cur = p[cur];
    end
    return cur;
  endfunction

  // Stage S_KRUSKAL: process sorted edges
  always_comb begin
    if (state == S_KRUSKAL) begin
      state_d = S_KRUSKAL;
      k_d = k_q;
      selected_d = selected_q;
      acc_d = acc_q;
      mst_weight_d = mst_weight_q; // not used, keep consistency
      parent_d = parent_q;

      if (k_q < edge_count_q && selected_q < (num_points - 1)) begin
        edge_t e = edges_q[k_q];
        // find roots
        find_u = find_root(e.u, parent_q);
        find_v = find_root(e.v, parent_q);
        uf_root_u = find_u;
        uf_root_v = find_v;

        if (uf_root_u != uf_root_v) begin
          // union
          parent_d[uf_root_u] = uf_root_v; // simple union (no rank optimization)
          acc_d = acc_q + e.w;
          selected_d = selected_q + 1;
        end
        k_d = k_q + 1;
        if (k_q + 1 == edge_count_q || selected_q + (uf_root_u != uf_root_v) == (num_points - 1)) begin
          state_d = S_DONE;
          done_d = 1'b1;
          mst_weight_d = (selected_q + (uf_root_u != uf_root_v) == (num_points - 1)) ? (acc_d + ((uf_root_u != uf_root_v) ? e.w : 14'd0)) : acc_q;
        end
      end else begin
        // finished
        state_d = S_DONE;
        done_d = 1'b1;
        mst_weight_d = acc_q;
      end
    end
  end

  // Stage S_DONE: hold until start is deasserted or reset
  always_comb begin
    if (state == S_DONE) begin
      state_d = S_DONE;
      done_d  = 1'b1;
      if (start) begin
        // keep done=1 until start deasserted
        state_d = S_DONE;
      end else begin
        // go back to idle on next cycle
        state_d = S_IDLE;
        done_d  = 1'b0;
      end
    end
  end

  // Internal q for mst_weight to avoid overwrite in S_KRUSKAL always_comb
  logic [13:0] mst_weight_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mst_weight_q <= 14'd0;
    end else begin
      mst_weight_q <= mst_weight_d;
    end
  end

endmodule
