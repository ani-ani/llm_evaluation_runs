module stable_graph_max_edges(
    input [7:0] gov_mask,
    input [7:0][7:0] adj_matrix,
    output logic [15:0] max_edges
);

    // Internal variables
    logic [7:0] visited;
    logic [7:0] comp_nodes [0:7]; // Temporary storage for current component nodes
    logic [2:0] comp_size;
    logic comp_has_gov;
    
    logic [15:0] gov_sum;
    logic [15:0] non_gov_pool;
    logic [15:0] max_gov_size;
    
    logic [15:0] total_potential_edges;
    logic [15:0] existing_edges;
    
    integer i, j, k;
    integer q_head, q_tail;
    logic [7:0] temp_neighbors;
    logic [15:0] comb_size;
    logic [15:0] comb_sum;

    // Helper function to calculate n*(n-1)/2
    function automatic logic [15:0] combinations(input logic [15:0] n);
        begin
            combinations = (n * (n - 1)) >> 1;
        end
    endfunction

    always_comb begin
        // Initialization
        visited = 8'b0;
        gov_sum = 16'd0;
        non_gov_pool = 16'd0;
        max_gov_size = 16'd0;
        existing_edges = 16'd0;
        
        // 1. Calculate existing edges
        // Since matrix is symmetric, we can just sum all bits and divide by 2
        // or sum upper triangle. For 8x8, summing all is easy but counts each edge twice.
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                if (adj_matrix[r][c]) existing_edges++;
            end
        end
        existing_edges = existing_edges >> 1;

        // 2. Find Connected Components
        // Iterative BFS approach for each node
        for (int start_node = 0; start_node < 8; start_node++) begin
            if (!visited[start_node]) begin
                // New component found
                comp_size = 0;
                comp_has_gov = 0;
                
                // Start BFS/DFS with this node
                // We use the 'visited' array to ensure we don't process nodes twice
                // We need a list of nodes in the current component.
                // Since N=8, we can use a small array for queue.
                
                // Check start node
                visited[start_node] = 1'b1;
                comp_nodes[comp_size] = start_node;
                comp_size++;
                if (gov_mask[start_node]) comp_has_gov = 1;
                
                // Iterative expansion
                q_head = 0;
                while (q_head < comp_size) begin
                    int u = comp_nodes[q_head];
                    q_head++;
                    
                    // Find neighbors
                    for (int v = 0; v < 8; v++) begin
                        if (adj_matrix[u][v] && !visited[v]) begin
                            visited[v] = 1'b1;
                            comp_nodes[comp_size] = v;
                            comp_size++;
                            if (gov_mask[v]) comp_has_gov = 1;
                        end
                    end
                end
                
                // Process component results
                if (comp_has_gov) begin
                    // Add to gov_sum
                    gov_sum = gov_sum + combinations(comp_size);
                    // Update max_gov_size
                    if (comp_size > max_gov_size) max_gov_size = comp_size;
                end else begin
                    // Add to non_gov_pool
                    non_gov_pool = non_gov_pool + comp_size;
                end
            end
        end
        
        // 3. Final Calculation
        // Formula: gov_sum - C(max_gov) + C(max_gov + non_gov) - existing_edges
        total_potential_edges = gov_sum;
        total_potential_edges = total_potential_edges - combinations(max_gov_size);
        total_potential_edges = total_potential_edges + combinations(max_gov_size + non_gov_pool);
        
        max_edges = total_potential_edges - existing_edges;
    end

endmodule