module unicyclic_counter(
  input [2:0] V,
  input [2:0] E,
  input [5:0][3:0] edge_list,
  output reg [29:0] cycle_count
);

  always_comb begin
    cycle_count = 0;
    for (int i = 0; i < 64; i++) begin
      if (i < (1 << E)) begin
        logic [5:0] subset = i;
        int edge_count = 0;
        logic invalid_edge = 0;
        
        for (int e = 0; e < E; e++) begin
          if (subset[e]) begin
            logic [3:0] edge_data = edge_list[e];
            logic [1:0] A = edge_data[3:2];
            logic [1:0] B = edge_data[1:0];
            if (A < 1 || A > V || B < 1 || B > V) invalid_edge = 1;
            edge_count++;
          end
        end
        
        if (edge_count == V && !invalid_edge) begin
          logic [3:0][3:0] adj = '0;
          for (int e = 0; e < E; e++) begin
            if (subset[e]) begin
              logic [3:0] edge_data = edge_list[e];
              logic [1:0] A_idx = edge_data[3:2] - 1;
              logic [1:0] B_idx = edge_data[1:0] - 1;
              adj[A_idx][B_idx] = 1'b1;
              adj[B_idx][A_idx] = 1'b1;
            end
          end
          
          logic [3:0] reach = (1 << 0);
          for (int step = 0; step < 3; step++) begin
            logic [3:0] new_reach = reach;
            for (int j = 0; j < 4; j++) begin
              if (reach[j]) new_reach |= adj[j];
            end
            reach = new_reach;
          end
          
          if (reach[V-1:0] == (1 << V) - 1) cycle_count++;
        end
      end
    end
    cycle_count = cycle_count % 30'd1000000007;
  end
endmodule