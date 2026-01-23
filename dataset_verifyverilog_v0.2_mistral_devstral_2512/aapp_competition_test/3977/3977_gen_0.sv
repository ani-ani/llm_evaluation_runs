module stable_graph_max_edges(
    input [7:0] gov_mask,
    input [7:0][7:0] adj_matrix,
    output [15:0] max_edges
);

    reg [7:0] visited = 8'b0;
    reg [3:0] comp_size = 4'b0;
    reg has_gov = 1'b0;
    reg [15:0] gov_sum = 16'b0;
    reg [3:0] max_gov_size = 4'b0;
    reg [3:0] non_gov_pool = 4'b0;
    reg [3:0] m = 4'b0;
    integer i, j, k;

    // Calculate existing edges (m)
    for (i = 0; i < 8; i = i + 1) begin
        for (j = i + 1; j < 8; j = j + 1) begin
            m = m + adj_matrix[i][j];
        end
    end

    // Find connected components
    for (i = 0; i < 8; i = i + 1) begin
        if (!visited[i]) begin
            // Reset component properties
            comp_size = 0;
            has_gov = 1'b0;

            // BFS-like traversal using a queue (unrolled for 8 nodes)
            reg [7:0] queue = 8'b0;
            reg [3:0] q_ptr = 0;
            reg [3:0] q_size = 0;

            // Initialize queue with current node
            queue[0] = i;
            q_size = 1;
            visited[i] = 1'b1;

            // Process queue
            for (k = 0; k < 8; k = k + 1) begin
                if (q_ptr < q_size) begin
                    reg [3:0] u = queue[q_ptr];
                    q_ptr = q_ptr + 1;
                    comp_size = comp_size + 1;

                    // Check if node is government
                    if (gov_mask[u]) begin
                        has_gov = 1'b1;
                    end

                    // Add unvisited neighbors to queue
                    for (j = 0; j < 8; j = j + 1) begin
                        if (adj_matrix[u][j] && !visited[j]) begin
                            visited[j] = 1'b1;
                            queue[q_size] = j;
                            q_size = q_size + 1;
                        end
                    end
                end
            end

            // Update component statistics
            if (has_gov) begin
                reg [15:0] c_size = comp_size * (comp_size - 1) / 2;
                gov_sum = gov_sum + c_size;
                if (comp_size > max_gov_size) begin
                    max_gov_size = comp_size;
                end
            end else begin
                non_gov_pool = non_gov_pool + comp_size;
            end
        end
    end

    // Calculate total potential edges
    reg [15:0] total_potential = gov_sum;
    reg [15:0] c_max = max_gov_size * (max_gov_size - 1) / 2;
    reg [15:0] c_new = (max_gov_size + non_gov_pool) * (max_gov_size + non_gov_pool - 1) / 2;
    total_potential = total_potential - c_max + c_new;

    // Calculate edges to add
    assign max_edges = total_potential - m;

endmodule