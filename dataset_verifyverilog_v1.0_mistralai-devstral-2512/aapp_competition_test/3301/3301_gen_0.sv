module TaxPathfinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] edges_src [0:31],
    input wire [3:0] edges_dst [0:31],
    input wire [31:0] edges_wt [0:31],
    input wire [0:15] swerc_nodes,
    input wire [3:0] num_nodes,
    input wire [5:0] num_edges,
    input wire [3:0] src_node,
    input wire [3:0] dst_node,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] DIJKSTRA_NON_SWERC = 3'd1;
    localparam [2:0] DIJKSTRA_SWERC = 3'd2;
    localparam [2:0] BINARY_SEARCH = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [31:0] low, high, best_T;
    reg [63:0] min_non_swerc_cost;
    reg [63:0] min_swerc_cost;
    reg swerc_path_exists;
    reg non_swerc_path_exists;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Dijkstra internal signals
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [63:0] dist [0:15];
    reg [63:0] temp_dist [0:15];
    reg [0:15] visited;
    reg [31:0] current_T;
    reg [3:0] edge_index;
    reg [3:0] node_index;
    reg [3:0] min_node;
    reg [63:0] min_dist;
    reg [3:0] src_node_reg, dst_node_reg;
    reg [5:0] num_edges_reg;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low <= 32'd0;
            high <= 32'd1073741824; // 2^30
            best_T <= 32'd0;
            min_non_swerc_cost <= 64'd0;
            min_swerc_cost <= 64'd0;
            swerc_path_exists <= 1'b0;
            non_swerc_path_exists <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 32'd0;
            
            // Initialize Dijkstra registers
            current_node <= 4'd0;
            next_node <= 4'd0;
            for (node_index = 0; node_index < 16; node_index = node_index + 1) begin
                dist[node_index] <= 64'd10000000000000000000;
                temp_dist[node_index] <= 64'd10000000000000000000;
                visited[node_index] <= 1'b0;
            end
            edge_index <= 6'd0;
            min_node <= 4'd0;
            min_dist <= 64'd10000000000000000000;
            src_node_reg <= 4'd0;
            dst_node_reg <= 4'd0;
            num_edges_reg <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= DIJKSTRA_NON_SWERC;
                        src_node_reg <= src_node;
                        dst_node_reg <= dst_node;
                        num_edges_reg <= num_edges;
                    end
                end

                DIJKSTRA_NON_SWERC: begin
                    // Initialize distances
                    for (node_index = 0; node_index < 16; node_index = node_index + 1) begin
                        dist[node_index] <= 64'd10000000000000000000;
                        visited[node_index] <= 1'b0;
                    end
                    dist[src_node_reg] <= 64'd0;
                    current_node <= src_node_reg;
                    edge_index <= 6'd0;
                    min_node <= 4'd0;
                    min_dist <= 64'd10000000000000000000;
                    
                    state <= DIJKSTRA_NON_SWERC + 1'b1;
                end

                DIJKSTRA_NON_SWERC + 1'b1: begin
                    // Dijkstra algorithm for non-SWERC path
                    // Find unvisited node with minimum distance
                    min_dist <= 64'd10000000000000000000;
                    min_node <= 4'd0;
                    for (node_index = 0; node_index < num_nodes; node_index = node_index + 1) begin
                        if (!visited[node_index] && dist[node_index] < min_dist) begin
                            min_dist <= dist[node_index];
                            min_node <= node_index;
                        end
                    end
                    
                    if (min_dist == 64'd10000000000000000000) begin
                        // No path exists
                        non_swerc_path_exists <= 1'b0;
                        min_non_swerc_cost <= 64'd10000000000000000000;
                        state <= DIJKSTRA_SWERC;
                    end else begin
                        current_node <= min_node;
                        visited[current_node] <= 1'b1;
                        
                        if (current_node == dst_node_reg) begin
                            non_swerc_path_exists <= 1'b1;
                            min_non_swerc_cost <= dist[current_node];
                            state <= DIJKSTRA_SWERC;
                        end else begin
                            state <= DIJKSTRA_NON_SWERC + 2'b1;
                        end
                    end
                end

                DIJKSTRA_NON_SWERC + 2'b1: begin
                    // Relax edges
                    for (edge_index = 0; edge_index < num_edges_reg; edge_index = edge_index + 1) begin
                        if (edges_src[edge_index] == current_node) begin
                            next_node <= edges_dst[edge_index];
                            if (!visited[next_node]) begin
                                if (dist[current_node] + edges_wt[edge_index] < dist[next_node]) begin
                                    dist[next_node] <= dist[current_node] + edges_wt[edge_index];
                                end
                            end
                        end
                    end
                    state <= DIJKSTRA_NON_SWERC + 1'b1;
                end

                DIJKSTRA_SWERC: begin
                    // Initialize distances for SWERC path
                    for (node_index = 0; node_index < 16; node_index = node_index + 1) begin
                        dist[node_index] <= 64'd10000000000000000000;
                        visited[node_index] <= 1'b0;
                    end
                    dist[src_node_reg] <= 64'd0;
                    current_node <= src_node_reg;
                    edge_index <= 6'd0;
                    min_node <= 4'd0;
                    min_dist <= 64'd10000000000000000000;
                    
                    state <= DIJKSTRA_SWERC + 1'b1;
                end

                DIJKSTRA_SWERC + 1'b1: begin
                    // Dijkstra algorithm for SWERC path
                    // Find unvisited node with minimum distance
                    min_dist <= 64'd10000000000000000000;
                    min_node <= 4'd0;
                    for (node_index = 0; node_index < num_nodes; node_index = node_index + 1) begin
                        if (!visited[node_index] && dist[node_index] < min_dist) begin
                            min_dist <= dist[node_index];
                            min_node <= node_index;
                        end
                    end
                    
                    if (min_dist == 64'd10000000000000000000) begin
                        // No path exists
                        swerc_path_exists <= 1'b0;
                        min_swerc_cost <= 64'd10000000000000000000;
                        state <= BINARY_SEARCH;
                    end else begin
                        current_node <= min_node;
                        visited[current_node] <= 1'b1;
                        
                        if (current_node == dst_node_reg) begin
                            swerc_path_exists <= 1'b1;
                            min_swerc_cost <= dist[current_node];
                            state <= BINARY_SEARCH;
                        end else begin
                            state <= DIJKSTRA_SWERC + 2'b1;
                        end
                    end
                end

                DIJKSTRA_SWERC + 2'b1: begin
                    // Relax edges for SWERC path
                    for (edge_index = 0; edge_index < num_edges_reg; edge_index = edge_index + 1) begin
                        if (edges_src[edge_index] == current_node && swerc_nodes[edges_dst[edge_index]]) begin
                            next_node <= edges_dst[edge_index];
                            if (!visited[next_node]) begin
                                if (dist[current_node] + edges_wt[edge_index] < dist[next_node]) begin
                                    dist[next_node] <= dist[current_node] + edges_wt[edge_index];
                                end
                            end
                        end
                    end
                    state <= DIJKSTRA_SWERC + 1'b1;
                end

                BINARY_SEARCH: begin
                    // Binary search for maximum T
                    if (low > high) begin
                        if (best_T == 32'd0) begin
                            // No valid T found
                            if (!swerc_path_exists) begin
                                result <= 32'hFFFFFFFE; // Impossible
                            end else if (!non_swerc_path_exists) begin
                                result <= 32'hFFFFFFFF; // Infinity
                            end else begin
                                result <= 32'hFFFFFFFE; // Impossible
                            end
                        end else begin
                            result <= best_T;
                        end
                        state <= OUTPUT;
                    end else begin
                        current_T <= (low + high) / 2'b1;
                        state <= BINARY_SEARCH + 1'b1;
                    end
                end

                BINARY_SEARCH + 1'b1: begin
                    // Compute SWERC path cost with current T
                    // Initialize distances
                    for (node_index = 0; node_index < 16; node_index = node_index + 1) begin
                        temp_dist[node_index] <= 64'd10000000000000000000;
                        visited[node_index] <= 1'b0;
                    end
                    temp_dist[src_node_reg] <= 64'd0;
                    current_node <= src_node_reg;
                    edge_index <= 6'd0;
                    min_node <= 4'd0;
                    min_dist <= 64'd10000000000000000000;
                    
                    state <= BINARY_SEARCH + 2'b1;
                end

                BINARY_SEARCH + 2'b1: begin
                    // Dijkstra for SWERC path with T
                    min_dist <= 64'd10000000000000000000;
                    min_node <= 4'd0;
                    for (node_index = 0; node_index < num_nodes; node_index = node_index + 1) begin
                        if (!visited[node_index] && temp_dist[node_index] < min_dist) begin
                            min_dist <= temp_dist[node_index];
                            min_node <= node_index;
                        end
                    end
                    
                    if (min_dist == 64'd10000000000000000000) begin
                        // No path exists
                        state <= BINARY_SEARCH + 4'b1;
                    end else begin
                        current_node <= min_node;
                        visited[current_node] <= 1'b1;
                        
                        if (current_node == dst_node_reg) begin
                            state <= BINARY_SEARCH + 3'b1;
                        end else begin
                            state <= BINARY_SEARCH + 4'b1;
                        end
                    end
                end

                BINARY_SEARCH + 3'b1: begin
                    // Check if SWERC path is cheaper
                    if (temp_dist[current_node] < min_non_swerc_cost) begin
                        best_T <= current_T;
                        low <= current_T + 32'd1;
                    end else begin
                        high <= current_T - 32'd1;
                    end
                    state <= BINARY_SEARCH;
                end

                BINARY_SEARCH + 4'b1: begin
                    // Relax edges for SWERC path with T
                    for (edge_index = 0; edge_index < num_edges_reg; edge_index = edge_index + 1) begin
                        if (edges_src[edge_index] == current_node && swerc_nodes[edges_dst[edge_index]]) begin
                            next_node <= edges_dst[edge_index];
                            if (!visited[next_node]) begin
                                if (temp_dist[current_node] + edges_wt[edge_index] + current_T < temp_dist[next_node]) begin
                                    temp_dist[next_node] <= temp_dist[current_node] + edges_wt[edge_index] + current_T;
                                end
                            end
                        end
                    end
                    state <= BINARY_SEARCH + 2'b1;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Cycle counter to prevent infinite loops
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 32'hFFFFFFFE; // Impossible
            end
        end
    end
endmodule