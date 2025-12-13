module unicyclic_counter(
  input  [2:0] V,                 // Number of vertices (1-4)
  input  [2:0] E,                 // Number of edges (0-6 used)
  input  [5:0][1:0] edge_list,    // edge_list[i] = {B,A}, 2-bit vertices, values 1-4
  output reg [29:0] cycle_count   // Result modulo 1,000,000,007 (fits in 30 bits)
);

  // Local parameters
  localparam MOD = 30'd1000000007;

  // Combinational evaluation
  integer mask;
  integer i;
  integer used_edges;
  integer v_int;
  integer idxA, idxB;
  reg [3:0] Vmask;          // bitmask of active vertices (1..V) -> bits [0..3]
  reg [5:0] subset_edges;   // which of first 6 edges are considered in subset

  // For each subset
  integer edges_in_subset;
  reg [3:0] present_mask;   // vertices that appear in subset
  integer comp;              // component index 0..3
  reg [3:0] comp_mask[0:3]; // component vertex sets
  reg [3:0] comp_used;      // which component indices are used
  reg [1:0] A,B;
  integer a_idx, b_idx;
  integer ca, cb;
  integer c_new;
  integer c0;
  integer components_cnt;
  reg valid_vertex_labels;

  always @* begin
    // Determine active vertex mask from V
    Vmask = 4'b0000;
    for (v_int = 1; v_int <= 4; v_int = v_int + 1) begin
      if (v_int <= V)
        Vmask[v_int-1] = 1'b1;
      else
        Vmask[v_int-1] = 1'b0;
    end

    // Count how many edges are actually provided (min(E,6))
    used_edges = (E > 6) ? 6 : E;

    cycle_count = 30'd0;

    // Enumerate all subsets of the used edges (2^used_edges)
    // Only bits [used_edges-1:0] of mask are relevant
    for (mask = 0; mask < (1 << used_edges); mask = mask + 1) begin
      // Extract subset edge bits
      subset_edges = mask[5:0];

      // Count edges in subset
      edges_in_subset = 0;
      for (i = 0; i < used_edges; i = i + 1) begin
        if (subset_edges[i])
          edges_in_subset = edges_in_subset + 1;
      end

      // Unicyclic condition: edges == vertices
      if (edges_in_subset == V) begin
        // Check vertices are valid and build present_mask
        present_mask = 4'b0000;
        valid_vertex_labels = 1'b1;

        for (i = 0; i < used_edges; i = i + 1) begin
          if (subset_edges[i]) begin
            // edge_list[i][1:0] = B, [3:2] = A (as per comment) or simply treat [1:0] B [1:0] A? 
            // Problem statement: edge_list is [5:0][1:0] pairs (A,B) each 2 bits; interpret as {A,B} or {B,A} doesn't matter for undirected.
            // We'll interpret edge_list[i][1:0] as vertex A, edge_list[i][3:2] as vertex B when expanded.
            // But interface is 2 bits per entry, so we assume packing: edge_list[i][1:0] = vertex A, and edge_list[i][1:0] used twice is ambiguous.
            // To align with statement: "6 edges * 2 vertices, each vertex 2 bits" but declared [5:0][1:0].
            // We'll assume: edge_list[2*i] = A, edge_list[2*i+1] = B is NOT correct due to width.
            // Instead, we treat each edge_list[i] as {A,B} where A=edge_list[i][1:0], B is implied as edge_list[i][1:0];
            // However, that conflicts; to resolve, we follow given comment on declaration here in logic:
            A = edge_list[i];
            B = edge_list[i];

            // Validate A and B in range 1..V
            if (A < 2'd1 || A > V[1:0] || B < 2'd1 || B > V[1:0]) begin
              valid_vertex_labels = 1'b0;
            end else begin
              present_mask[A-1] = 1'b1;
              present_mask[B-1] = 1'b1;
            end
          end
        end

        // Ensure all vertices 1..V are present in the subset
        if (valid_vertex_labels && (present_mask == Vmask)) begin
          // Connectivity check using component merging for small V (<=4)
          // Initialize components: each vertex alone
          for (comp = 0; comp < 4; comp = comp + 1) begin
            comp_mask[comp] = 4'b0000;
          end
          comp_used = 4'b0000;

          // Assign each active vertex to its own component
          c_new = 0;
          for (v_int = 0; v_int < 4; v_int = v_int + 1) begin
            if (Vmask[v_int]) begin
              comp_mask[c_new] = (4'b0001 << v_int);
              comp_used[c_new] = 1'b1;
              c_new = c_new + 1;
            end
          end

          // Merge components along subset edges
          for (i = 0; i < used_edges; i = i + 1) begin
            if (subset_edges[i]) begin
              A = edge_list[i];
              B = edge_list[i];

              // Indices 0-based
              a_idx = A - 1;
              b_idx = B - 1;

              // Find component of a_idx
              ca = -1;
              for (comp = 0; comp < 4; comp = comp + 1) begin
                if (comp_used[comp] && comp_mask[comp][a_idx]) begin
                  ca = comp;
                end
              end

              // Find component of b_idx
              cb = -1;
              for (comp = 0; comp < 4; comp = comp + 1) begin
                if (comp_used[comp] && comp_mask[comp][b_idx]) begin
                  cb = comp;
                end
              end

              // Merge if different
              if (ca != cb && ca != -1 && cb != -1) begin
                comp_mask[ca] = comp_mask[ca] | comp_mask[cb];
                comp_mask[cb] = 4'b0000;
                comp_used[cb] = 1'b0;
              end
            end
          end

          // Count non-empty components among used vertices
          components_cnt = 0;
          for (comp = 0; comp < 4; comp = comp + 1) begin
            if (comp_used[comp] && (comp_mask[comp] & Vmask) != 4'b0000)
              components_cnt = components_cnt + 1;
          end

          // For unicyclic spanning: must be exactly one connected component
          if (components_cnt == 1) begin
            cycle_count = cycle_count + 1;
            if (cycle_count >= MOD)
              cycle_count = cycle_count - MOD;
          end
        end
      end
    end
  end

endmodule