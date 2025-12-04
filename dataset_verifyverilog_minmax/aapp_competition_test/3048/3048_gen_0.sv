module path_counter (
  input reg [3:0] N, // number of junctions (1..16)
  input reg [255:0] adjacency_matrix_flat, // flattened 16x16 adjacency matrix
  output logic [7:0] count // total number of optimal paths of length 2
);

  // Local 2D view of the adjacency matrix for convenience
  logic [15:0] adj [16];

  // Unpack flattened matrix: bit [16*i + j] corresponds to adj[i][j]
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : unpack_adj
      assign adj[i] = adjacency_matrix_flat[16*i +: 16];
    end
  endgenerate

  // Compute count purely combinatorially
  integer u, v, w;
  logic found;
  always_comb begin
    count = 0;
    for (u = 0; u < 16; u++) begin
      if (u >= N) continue;
      for (v = 0; v < 16; v++) begin
        if (v >= N) continue;
        if (u == v) continue;
        if (adj[u][v]) continue; // direct road exists, not a length-2 path
        found = 1'b0;
        for (w = 0; w < 16; w++) begin
          if (w >= N) continue;
          if (adj[u][w] && adj[w][v]) begin
            found = 1'b1;
            break;
          end
        end
        if (found) count = count + 1;
      end
    end
  end

endmodule