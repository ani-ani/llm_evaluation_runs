module tree_checker (
  input [3:0] n,
  input [3:0] num_edges,
  input [5:0] edge_u [15:0],
  input [5:0] edge_v [15:0],
  output result
);

  reg [3:0] degree [0:15];
  integer i, j;
  reg has_degree_2;

  // Initialize degrees to 0
  for (i = 0; i < 16; i = i + 1) begin
    degree[i] = 0;
  end

  // Calculate degrees for each node
  for (i = 0; i < num_edges; i = i + 1) begin
    for (j = 0; j < 16; j = j + 1) begin
      if (edge_u[i] == j) begin
        degree[j] = degree[j] + 1;
      end
      if (edge_v[i] == j) begin
        degree[j] = degree[j] + 1;
      end
    end
  end

  // Check for degree 2 nodes
  has_degree_2 = 0;
  for (i = 0; i < n; i = i + 1) begin
    if (degree[i] == 2) begin
      has_degree_2 = 1;
    end
  end

  // Determine result
  assign result = (n == 2) ? 1 : (!has_degree_2);

endmodule