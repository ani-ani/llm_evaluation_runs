module path_counter(
  input [3:0] N,
  input [255:0] adjacency_matrix_flat,
  output [7:0] count
);
  
  logic [15:0] adj_matrix [0:15];
  logic [15:0][15:0] pair_valid;
  logic [7:0] count_int;
  
  always_comb begin
    // Reshape adjacency matrix
    for (int i = 0; i < 16; i++) begin
      for (int j = 0; j < 16; j++) begin
        adj_matrix[i][j] = adjacency_matrix_flat[16*i + j];
      end
    end
    
    // Calculate valid pairs
    count_int = 0;
    for (int u = 0; u < 16; u++) begin
      for (int v = 0; v < 16; v++) begin
        if (u < N && v < N && u != v) begin
          bit direct_edge = adj_matrix[u][v];
          bit exists_w = 1'b0;
          for (int w = 0; w < 16; w++) begin
            if (w < N) begin
              exists_w = exists_w | (adj_matrix[u][w] && adj_matrix[w][v]);
            end
          end
          pair_valid[u][v] = !direct_edge && exists_w;
        end else begin
          pair_valid[u][v] = 1'b0;
        end
        count_int = count_int + pair_valid[u][v];
      end
    end
  end
  
  assign count = count_int;
endmodule