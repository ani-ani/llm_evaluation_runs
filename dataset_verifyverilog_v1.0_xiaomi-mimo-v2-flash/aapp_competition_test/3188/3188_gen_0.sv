module MST_Calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] coord_x [0:7],
    input wire [15:0] coord_y [0:7],
    input wire [15:0] coord_z [0:7],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_EDGES = 3'd1;
    localparam [2:0] SORT       = 3'd2;
    localparam [2:0] KRUN       = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Edge storage: 28 edges max for N=8
    // Packed format: [47:32]=src, [31:16]=dest, [15:0]=weight
    reg [47:0] edge_reg [0:27];
    reg [4:0] num_edges; // Actual number of edges to process
    
    // Edge generation counters
    reg [3:0] node_i;
    reg [3:0] node_j;
    
    // Sorting state
    reg [4:0] sort_i;
    reg [4:0] sort_j;
    reg [47:0] temp_edge;
    
    // Kruskal variables
    reg [4:0] edge_idx;
    reg [3:0] edges_added;
    reg [3:0] find_node;
    reg [3:0] find_root;
    reg [3:0] union_a;
    reg [3:0] union_b;
    reg [3:0] parent [0:7]; // Union-Find parent array
    reg [7:0] path [0:7]; // Path compression temporary storage
    reg [3:0] path_len;
    reg [15:0] weight_to_add;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd2000;
    
    // Helper signals for edge access
    wire [15:0] edge_src = edge_reg[edge_idx][47:32];
    wire [15:0] edge_dest = edge_reg[edge_idx][31:16];
    wire [15:0] edge_weight = edge_reg[edge_idx][15:0];
    
    // Combinational logic for absolute difference
    function automatic [15:0] abs_diff;
        input signed [15:0] a, b;
        reg signed [15:0] diff;
        begin
            diff = a - b;
            if (diff < 0)
                abs_diff = -diff;
            else
                abs_diff = diff;
        end
    endfunction
    
    // Combinational logic for min of 3
    function automatic [15:0] min3;
        input [15:0] a, b, c;
        begin
            if (a < b) begin
                if (a < c)
                    min3 = a;
                else
                    min3 = c;
            end else begin
                if (b < c)
                    min3 = b;
                else
                    min3 = c;
            end
        end
    endfunction

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            num_edges <= 5'd0;
            node_i <= 4'd0;
            node_j <= 4'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            edge_idx <= 5'd0;
            edges_added <= 4'd0;
            find_node <= 4'd0;
            find_root <= 4'd0;
            union_a <= 4'd0;
            union_b <= 4'd0;
            weight_to_add <= 16'd0;
            path_len <= 4'd0;
            temp_edge <= 48'd0;
            // Initialize parent array
            parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3;
            parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7;
            // Initialize edge array (optional, safety)
            integer k;
            for (k = 0; k < 28; k = k + 1) begin
                edge_reg[k] <= 48'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    cycle_count <= 16'd0;
                    num_edges <= 5'd0;
                    node_i <= 4'd0;
                    node_j <= 4'd0;
                    edges_added <= 4'd0;
                    edge_idx <= 5'd0;
                    if (start && n >= 4'd2 && n <= 4'd8) begin
                        // Initialize parent for valid N
                        integer m;
                        for (m = 0; m < 8; m = m + 1) begin
                            if (m < n)
                                parent[m] <= m;
                            else
                                parent[m] <= 4'd0;
                        end
                    end
                end
                
                CALC_EDGES: begin
                    // Generate edge for (node_i, node_j)
                    if (node_j < n) begin
                        // Calculate cost
                        reg [15:0] dx, dy, dz, min_val;
                        dx = abs_diff(coord_x[node_i], coord_x[node_j]);
                        dy = abs_diff(coord_y[node_i], coord_y[node_j]);
                        dz = abs_diff(coord_z[node_i], coord_z[node_j]);
                        min_val = min3(dx, dy, dz);
                        
                        // Store edge (src, dest, weight)
                        edge_reg[num_edges] <= {node_i, node_j, min_val};
                        num_edges <= num_edges + 5'd1;
                        
                        // Increment counters
                        node_j <= node_j + 4'd1;
                    end else begin
                        // Move to next node_i
                        node_i <= node_i + 4'd1;
                        node_j <= node_i + 4'd2;
                        if (node_i >= n - 4'd2) begin
                            // Finished generating all edges
                            sort_i <= 5'd0;
                            sort_j <= 5'd0;
                        end
                    end
                end
                
                SORT: begin
                    // Bubble sort
                    if (sort_i < num_edges - 5'd1) begin
                        if (sort_j < num_edges - sort_i - 5'd1) begin
                            if (edge_reg[sort_j][15:0] > edge_reg[sort_j + 5'd1][15:0]) begin
                                temp_edge <= edge_reg[sort_j];
                                edge_reg[sort_j] <= edge_reg[sort_j + 5'd1];
                                edge_reg[sort_j + 5'd1] <= temp_edge;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_i <= sort_i + 5'd1;
                            sort_j <= 5'd0;
                        end
                    end
                end
                
                KRUN: begin
                    if (edge_idx < num_edges && edges_added < n - 4'd1) begin
                        // Check if nodes are in different sets
                        // Find root of edge_src
                        // Use find_root variable as state machine for find
                        if (find_node == edge_src) begin
                            if (parent[find_node] != find_node) begin
                                // Path compression step (simplified iterative)
                                reg [3:0] p;
                                p = parent[find_node];
                                path[0] <= find_node;
                                path[1] <= p;
                                path_len <= 4'd2;
                                // Continue traversal
                                find_node <= p;
                            end else begin
                                find_root <= find_node;
                                find_node <= edge_dest; // Switch to find dest
                            end
                        end else if (find_node == edge_dest) begin
                            if (parent[find_node] != find_node) begin
                                reg [3:0] p;
                                p = parent[find_node];
                                path[0] <= find_node;
                                path[1] <= p;
                                path_len <= 4'd2;
                                find_node <= p;
                            end else begin
                                // Both roots found: compare and union
                                if (find_root != find_node) begin
                                    // Union: attach smaller index to larger
                                    if (find_root < find_node) begin
                                        parent[find_node] <= find_root;
                                        // Path compression for src path
                                        integer p_idx;
                                        for (p_idx = 0; p_idx < path_len; p_idx = p_idx + 1)
                                            parent[path[p_idx]] <= find_root;
                                    end else begin
                                        parent[find_root] <= find_node;
                                        // Path compression for dest path
                                        integer p_idx;
                                        for (p_idx = 0; p_idx < path_len; p_idx = p_idx + 1)
                                            parent[path[p_idx]] <= find_node;
                                        // Also update the earlier root
                                        if (find_root != edge_src) begin
                                            // If we stored path for src, update it too
                                            // (Assuming find_node was src initially)
                                        end
                                    end
                                    edges_added <= edges_added + 4'd1;
                                    result <= result + {16'd0, edge_weight};
                                end
                                edge_idx <= edge_idx + 5'd1;
                                find_node <= 4'd0; // Reset for next edge
                                path_len <= 4'd0;
                            end
                        end else begin
                            // Traversal logic
                            if (path_len < 8 && parent[find_node] != find_node) begin
                                path[path_len] <= find_node;
                                path_len <= path_len + 4'd1;
                                find_node <= parent[find_node];
                            end else begin
                                // Reached root (or path full)
                                if (find_node == edge_src) begin
                                    find_root <= find_node;
                                    find_node <= edge_dest;
                                end else if (find_node == edge_dest) begin
                                    // Comparison and union logic here (same as above)
                                    if (find_root != find_node) begin
                                        if (find_root < find_node) begin
                                            parent[find_node] <= find_root;
                                        end else begin
                                            parent[find_root] <= find_node;
                                        end
                                        edges_added <= edges_added + 4'd1;
                                        result <= result + {16'd0, edge_weight};
                                    end
                                    edge_idx <= edge_idx + 5'd1;
                                    find_node <= 4'd0;
                                    path_len <= 4'd0;
                                end else begin
                                    // Should not happen in this logic flow
                                end
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Result is already set
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && n >= 4'd2 && n <= 4'd8)
                    next_state = CALC_EDGES;
                else
                    next_state = IDLE;
            end
            
            CALC_EDGES: begin
                // Check completion: when node_i >= n-1 and node_j >= n
                if (node_i >= n - 4'd1 && node_j >= n)
                    next_state = SORT;
                else
                    next_state = CALC_EDGES;
            end
            
            SORT: begin
                if (sort_i >= num_edges - 5'd1)
                    next_state = KRUN;
                else
                    next_state = SORT;
            end
            
            KRUN: begin
                // Check if done adding edges or ran out of edges
                if (edges_added >= n - 4'd1 || edge_idx >= num_edges)
                    next_state = FINISH;
                else
                    next_state = KRUN;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES)
            next_state = FINISH;
    end

endmodule