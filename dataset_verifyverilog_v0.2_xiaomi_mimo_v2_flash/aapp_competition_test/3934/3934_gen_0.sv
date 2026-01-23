module tree_checker (
    input [3:0] n,
    input [3:0] num_edges,
    input [5:0] edge_u [15:0],
    input [5:0] edge_v [15:0],
    output result
);

    // Internal signals for degree calculation
    // Degrees array: 16 entries of 4 bits each (max degree 15 for 16 nodes)
    reg [3:0] degrees [15:0];
    
    // Initialize degrees to 0
    integer i;
    
    // Combinational logic block
    always @(*) begin
        // Initialize degrees to 0
        for (i = 0; i < 16; i = i + 1) begin
            degrees[i] = 4'b0000;
        end
        
        // Count degrees based on number of edges provided
        for (i = 0; i < 16; i = i + 1) begin
            // Only process edges that exist (i < num_edges)
            // Since n <= 16, num_edges <= 15, so checking i < num_edges covers all valid edges
            if (i < num_edges) begin
                // Increment degree for u[i] if it's a valid node index (< n)
                if (edge_u[i] < n) begin
                    degrees[edge_u[i]] = degrees[edge_u[i]] + 1;
                end
                // Increment degree for v[i] if it's a valid node index (< n)
                if (edge_v[i] < n) begin
                    degrees[edge_v[i]] = degrees[edge_v[i]] + 1;
                end
            end
        end
    end
    
    // Check for any node with degree == 2
    reg has_degree_2;
    
    always @(*) begin
        has_degree_2 = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n) begin
                if (degrees[i] == 4'b0010) begin
                    has_degree_2 = 1'b1;
                end
            end
        end
    end
    
    // Output logic: result is 1 if (n == 2) OR (n > 2 AND no degree 2)
    // That is: result = 1 when n == 2 OR has_degree_2 == 0
    // Using bitwise logic to avoid behavioral if statements for synthesis
    wire n_is_2;
    wire n_gt_2;
    wire no_degree_2;
    
    assign n_is_2 = (n == 4'b0010);
    assign n_gt_2 = (n > 4'b0010);
    assign no_degree_2 = ~has_degree_2;
    
    // Result is YES if: n == 2 OR (n > 2 AND no degree 2)
    assign result = n_is_2 | (n_gt_2 & no_degree_2);

endmodule