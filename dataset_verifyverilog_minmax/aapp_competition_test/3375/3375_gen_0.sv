module unicyclic_counter(
  input [2:0] V,               // Number of vertices (3 bits, valid values 1-4)
  input [2:0] E,               // Number of edges (3 bits)
  input [5:0][1:0] edge_list,  // Packed edge list (6 edges * 2 vertices, each vertex 2 bits)
  output reg [29:0] cycle_count // Result modulo 1,000,000,007 (10^9+7)
);

  localparam MOD = 30'd1000000007;

  function automatic bit is_unicyclic_subset(int v, int e, input [5:0][1:0] elist, int mask);
    int parent[4];
    int rank[4];
    bit seen[4];
    int edge_count;
    int cycle_count_local;
    int a, b, ra, rb, i;

    edge_count = 0;
    cycle_count_local = 0;

    for (i = 0; i < 4; i++) begin
      parent[i] = i;
      rank[i] = 0;
      seen[i] = 1'b0;
    end

    for (i = 0; i < e; i++) begin
      if ((mask >> i) & 1) begin
        a = elist[i][1:0];
        b = elist[i][3:2];
        if (a < 0 || a >= v || b < 0 || b >= v) begin
          is_unicyclic_subset = 1'b0;
          return;
        end
        seen[a] = 1'b1;
        seen[b] = 1'b1;
        edge_count++;

        ra = a; while (parent[ra] != ra) ra = parent[ra];
        rb = b; while (parent[rb] != rb) rb = parent[rb];

        if (ra == rb) begin
          cycle_count_local++;
        end else begin
          if (rank[ra] < rank[rb]) begin
            parent[ra] = rb;
          end else if (rank[ra] > rank[rb]) begin
            parent[rb] = ra;
          end else begin
            parent[rb] = ra;
            rank[ra]++;
          end
        end
      end
    end

    if (edge_count != v) begin
      is_unicyclic_subset = 1'b0;
      return;
    end
    if (cycle_count_local != 1) begin
      is_unicyclic_subset = 1'b0;
      return;
    end

    for (i = 0; i < v; i++) begin
      if (!seen[i]) begin
        is_unicyclic_subset = 1'b0;
        return;
      end
    end

    begin
      int comps = 0;
      for (i = 0; i < v; i++) begin
        if (parent[i] == i) comps++;
      end
      if (comps != 1) begin
        is_unicyclic_subset = 1'b0;
        return;
      end
    end

    is_unicyclic_subset = 1'b1;
  endfunction

  function automatic [29:0] count_unicyclic(int v, int e, input [5:0][1:0] elist);
    int mask;
    int total;
    total = 0;
    for (mask = 0; mask < (1 << e); mask++) begin
      if (is_unicyclic_subset(v, e, elist, mask)) total++;
    end
    count_unicyclic = total % MOD;
  endfunction

  always @(*) begin
    cycle_count = 30'd0;
    if (V >= 1 && V <= 4 && E >= 0 && E <= 6) begin
      cycle_count = count_unicyclic(V, E, edge_list);
    end
  end

endmodule
