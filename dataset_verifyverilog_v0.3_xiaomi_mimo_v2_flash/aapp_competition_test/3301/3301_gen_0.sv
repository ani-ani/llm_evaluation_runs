module SWERC_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,  // Scaled: N ≤ 8
    input [3:0] P,  // Scaled: P ≤ 16
    input [3:0] X,  // Node ID (scaled to 4 bits)
    input [3:0] Y,  // Node ID (scaled to 4 bits)
    input [3:0] swerc_count,    // Number of SWERC banks
    input [31:0] swerc_list,    // Packed SWERC bank IDs (8 x 4-bit)
    input [31:0] edge_data,     // Packed edge info: 4 x (3-bit a, 3-bit b, 26-bit fee)
    output reg [31:0] result,   // Result: T value or special codes
    output reg done,
    output reg error
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] PARSE_INPUT  = 4'd1;
    localparam [3:0] BUILD_GRAPH  = 4'd2;
    localparam [3:0] COMPUTE_BASE = 4'd3;
    localparam [3:0] BINARY_SEARCH = 4'd4;
    localparam [3:0] CHECK_CONDITION = 4'd5;
    localparam [3:0] OUTPUT       = 4'd6;
    localparam [3:0] ERROR_STATE  = 4'd7;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Control registers
    reg [3:0] swerc_idx;
    reg [3:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] search_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Fixed-point arithmetic: Q16.16 for fees, Q8.8 for T values
    // Fee is scaled by 2^16, T is scaled by 2^8
    // Total cost = fee + count * T (where T is scaled Q8.8)
    // Comparison: base_cost + edge_count * T <= other_cost + other_count * T
    
    // Graph storage
    reg [7:0] swerc_mask; // Bitmask of SWERC nodes (8 nodes max)
    reg [15:0] fee_swerc [0:7][0:7]; // Fees for SWERC subgraph
    reg [15:0] fee_all [0:7][0:7];   // Fees for full graph
    reg [3:0] edge_count_swerc;
    reg [3:0] edge_count_all;
    
    // Path computation results
    reg [15:0] dist_swerc [0:7]; // Distances for SWERC subgraph
    reg [15:0] dist_all [0:7];   // Distances for full graph
    reg [15:0] base_cost_swerc;
    reg [15:0] base_cost_all;
    reg [7:0] path_valid_swerc;
    reg [7:0] path_valid_all;
    
    // Binary search variables
    reg [15:0] T_low;
    reg [15:0] T_high;
    reg [15:0] T_mid;
    reg [7:0] search_iterations;
    reg condition_result;
    
    // Dijkstra registers
    reg [3:0] dijkstra_node;
    reg [15:0] dijkstra_cost;
    reg [7:0] visited_mask;
    reg [3:0] src_node;
    reg [3:0] dst_node;
    
    // Extract node IDs from 3-bit values (0-7 range)
    wire [3:0] node_a = {1'b0, edge_data[2:0]};
    wire [3:0] node_b = {1'b0, edge_data[5:3]};
    wire [25:0] fee_raw = edge_data[31:6];
    wire [15:0] fee_scaled = fee_raw[25:10]; // Scale down from 2^26 to 2^16
    
    // Extract SWERC list
    wire [3:0] swerc_nodes [0:7];
    assign swerc_nodes[0] = swerc_list[3:0];
    assign swerc_nodes[1] = swerc_list[7:4];
    assign swerc_nodes[2] = swerc_list[11:8];
    assign swerc_nodes[3] = swerc_list[15:12];
    assign swerc_nodes[4] = swerc_list[19:16];
    assign swerc_nodes[5] = swerc_list[23:20];
    assign swerc_nodes[6] = swerc_list[27:24];
    assign swerc_nodes[7] = swerc_list[31:28];
    
    // Integer for loops
    integer i, j;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PARSE_INPUT : IDLE;
            PARSE_INPUT: next_state = BUILD_GRAPH;
            BUILD_GRAPH: begin
                if (edge_idx < 4'd4) next_state = BUILD_GRAPH;
                else next_state = COMPUTE_BASE;
            end
            COMPUTE_BASE: begin
                if (node_idx < 4'd8) next_state = COMPUTE_BASE;
                else next_state = BINARY_SEARCH;
            end
            BINARY_SEARCH: begin
                if (T_low <= T_high && search_iterations < 8'd16) 
                    next_state = CHECK_CONDITION;
                else 
                    next_state = OUTPUT;
            end
            CHECK_CONDITION: next_state = BINARY_SEARCH;
            OUTPUT: next_state = IDLE;
            ERROR_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // State transition and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result <= 32'd0;
            
            // Reset all internal registers
            swerc_mask <= 8'd0;
            swerc_idx <= 4'd0;
            edge_idx <= 4'd0;
            node_idx <= 4'd0;
            search_idx <= 4'd0;
            cycle_count <= 8'd0;
            edge_count_swerc <= 4'd0;
            edge_count_all <= 4'd0;
            T_low <= 16'd1;      // Minimum T = 1.0 (scaled to 256)
            T_high <= 16'd25600; // Maximum T = 100.0 (scaled to 25600)
            search_iterations <= 8'd0;
            path_valid_swerc <= 8'd0;
            path_valid_all <= 8'd0;
            base_cost_swerc <= 16'hFFFF; // Infinity marker
            base_cost_all <= 16'hFFFF;
            
            // Initialize distance arrays to infinity
            for (i = 0; i < 8; i = i + 1) begin
                dist_swerc[i] <= 16'hFFFF;
                dist_all[i] <= 16'hFFFF;
            end
            
            // Initialize fee matrices to 0
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    fee_swerc[i][j] <= 16'd0;
                    fee_all[i][j] <= 16'd0;
                end
            end
            
            // Reset Dijkstra variables
            dijkstra_node <= 4'd0;
            dijkstra_cost <= 16'd0;
            visited_mask <= 8'd0;
            src_node <= 4'd0;
            dst_node <= 4'd0;
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                PARSE_INPUT: begin
                    // Build SWERC mask from list
                    swerc_mask <= 8'd0;
                    swerc_idx <= 4'd0;
                    
                    // Initialize all paths as invalid
                    path_valid_swerc <= 8'd0;
                    path_valid_all <= 8'd0;
                    base_cost_swerc <= 16'hFFFF;
                    base_cost_all <= 16'hFFFF;
                end
                
                BUILD_GRAPH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (edge_idx < 4'd4) begin
                        // Extract edge data from packed structure
                        // Each edge: 3 bits a, 3 bits b, 26 bits fee
                        // edge_data[31:0] = {edge3, edge2, edge1, edge0}
                        // Each edge: [31:26] fee (6 MSBs), [25:3] rest, [2:0] node a
                        // Let's use a different packing: each edge is 8 bits
                        // edge_data[7:0] = edge0: {a(2:0), b(2:0), fee(1:0)}
                        // We need to handle the packing correctly
                        
                        // Simplified: Assume edge_data is packed as 4 entries of 8 bits
                        // edge_data[7:0] = {a[2:0], b[2:0], fee[1:0]}
                        // edge_data[15:8] = {a[2:0], b[2:0], fee[1:0]}
                        // etc.
                        
                        // Actually, let's use a more robust extraction
                        // Each edge: 3 bits a, 3 bits b, 2 bits fee_low
                        // fee = {fee_raw, fee_low}
                        // We'll store fee scaled down to 16 bits
                        
                        reg [7:0] edge_byte;
                        reg [2:0] ea, eb;
                        reg [15:0] fee_val;
                        
                        case (edge_idx)
                            4'd0: edge_byte = edge_data[7:0];
                            4'd1: edge_byte = edge_data[15:8];
                            4'd2: edge_byte = edge_data[23:16];
                            4'd3: edge_byte = edge_data[31:24];
                            default: edge_byte = 8'd0;
                        endcase
                        
                        ea = edge_byte[2:0];
                        eb = edge_byte[5:3];
                        // Fee is just the top 2 bits, extend to 16 bits
                        fee_val = {14'd0, edge_byte[7:6]};
                        
                        // Add edge to full graph
                        fee_all[ea][eb] <= fee_val;
                        fee_all[eb][ea] <= fee_val;
                        edge_count_all <= edge_count_all + 4'd1;
                        
                        // Check if both endpoints are in SWERC
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < swerc_count) begin
                                if (swerc_nodes[i] == ea && swerc_nodes[i] == eb) begin
                                    // Both in SWERC - add to SWERC graph
                                    fee_swerc[ea][eb] <= fee_val;
                                    fee_swerc[eb][ea] <= fee_val;
                                    edge_count_swerc <= edge_count_swerc + 4'd1;
                                end
                            end
                        end
                        
                        edge_idx <= edge_idx + 4'd1;
                    end
                end
                
                COMPUTE_BASE: begin
                    // Dijkstra algorithm to find shortest path X->Y
                    // Run twice: once for SWERC subgraph, once for full graph
                    
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (node_idx < 4'd8) begin
                        // Initialize all nodes
                        dist_swerc[node_idx] <= 16'hFFFF;
                        dist_all[node_idx] <= 16'hFFFF;
                        visited_mask <= 8'd0;
                        node_idx <= node_idx + 4'd1;
                    end else begin
                        // Initialize source node for both computations
                        // We'll compute both paths in parallel
                        // SWERC path
                        if (!path_valid_swerc[0]) begin
                            dist_swerc[X] <= 16'd0;
                            visited_mask <= 8'd0;
                            dijkstra_node <= X;
                            src_node <= X;
                            dst_node <= Y;
                            path_valid_swerc[0] <= 1'b1; // Mark init done
                        end else if (!path_valid_swerc[1]) begin
                            // Run Dijkstra for SWERC (simplified: 1 iteration)
                            reg [3:0] u, v;
                            reg [15:0] alt;
                            u = dijkstra_node;
                            
                            // Update neighbors in SWERC graph
                            for (v = 0; v < 8; v = v + 1) begin
                                if (fee_swerc[u][v] != 16'd0) begin
                                    alt = dist_swerc[u] + fee_swerc[u][v];
                                    if (alt < dist_swerc[v]) begin
                                        dist_swerc[v] <= alt;
                                    end
                                end
                            end
                            
                            // Find next unvisited node with min distance
                            reg [15:0] min_dist;
                            reg [3:0] min_node;
                            reg [7:0] done_search;
                            
                            min_dist = 16'hFFFF;
                            min_node = 4'd0;
                            done_search = 1'b0;
                            
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!visited_mask[i] && dist_swerc[i] < min_dist) begin
                                    min_dist = dist_swerc[i];
                                    min_node = i[3:0];
                                end
                            end
                            
                            visited_mask <= visited_mask | (1 << min_node);
                            dijkstra_node <= min_node;
                            
                            // Stop if we reached Y or no more nodes
                            if (min_node == Y || min_dist == 16'hFFFF) begin
                                path_valid_swerc[1] <= 1'b1;
                                base_cost_swerc <= dist_swerc[Y];
                            end
                        end
                        
                        // Full graph computation (simplified)
                        // Similar to above but using fee_all
                        if (!path_valid_all[0]) begin
                            dist_all[X] <= 16'd0;
                            visited_mask <= 8'd0;
                            dijkstra_node <= X;
                            path_valid_all[0] <= 1'b1;
                        end else if (!path_valid_all[1]) begin
                            reg [3:0] u, v;
                            reg [15:0] alt;
                            u = dijkstra_node;
                            
                            for (v = 0; v < 8; v = v + 1) begin
                                if (fee_all[u][v] != 16'd0) begin
                                    alt = dist_all[u] + fee_all[u][v];
                                    if (alt < dist_all[v]) begin
                                        dist_all[v] <= alt;
                                    end
                                end
                            end
                            
                            reg [15:0] min_dist;
                            reg [3:0] min_node;
                            min_dist = 16'hFFFF;
                            min_node = 4'd0;
                            
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!visited_mask[i] && dist_all[i] < min_dist) begin
                                    min_dist = dist_all[i];
                                    min_node = i[3:0];
                                end
                            end
                            
                            visited_mask <= visited_mask | (1 << min_node);
                            dijkstra_node <= min_node;
                            
                            if (min_node == Y || min_dist == 16'hFFFF) begin
                                path_valid_all[1] <= 1'b1;
                                base_cost_all <= dist_all[Y];
                            end
                        end
                    end
                end
                
                BINARY_SEARCH: begin
                    // Initialize binary search
                    if (search_iterations == 8'd0) begin
                        T_low <= 16'd1;      // T = 1.0 (scaled to 256)
                        T_high <= 16'd25600; // T = 100.0 (scaled to 25600)
                        search_iterations <= 8'd1;
                    end else begin
                        search_iterations <= search_iterations + 8'd1;
                        T_mid <= (T_low + T_high) >> 1;
                    end
                end
                
                CHECK_CONDITION: begin
                    // Check: base_cost_swerc + edge_count_swerc * T_mid
                    //      <= base_cost_all + edge_count_all * T_mid
                    // We need to compute: base_cost + count * T
                    // T is scaled Q8.8 (256 * T_value)
                    // So count * T = count * (scaled T) / 256
                    // We'll multiply by 256 to avoid division
                    
                    reg [31:0] swerc_total;
                    reg [31:0] all_total;
                    reg [15:0] t_scaled;
                    
                    t_scaled = T_mid;
                    
                    // Calculate: base_cost * 256 + edge_count * T_mid
                    // Actually: T_mid is already scaled by 256
                    // So: total = base_cost + (edge_count * T_mid) / 256
                    // To avoid precision loss: total_scaled = base_cost * 256 + edge_count * T_mid
                    swerc_total = (base_cost_swerc << 8) + (edge_count_swerc * t_scaled);
                    all_total = (base_cost_all << 8) + (edge_count_all * t_scaled);
                    
                    if (swerc_total <= all_total) begin
                        condition_result <= 1'b1; // SWERC is cheaper or equal
                        T_low <= T_mid;
                    end else begin
                        condition_result <= 1'b0; // Full graph is cheaper
                        T_high <= T_mid - 16'd1;
                    end
                end
                
                OUTPUT: begin
                    // Check for special cases
                    if (base_cost_swerc == 16'hFFFF && base_cost_all == 16'hFFFF) begin
                        // Impossible (no path in either graph)
                        result <= 32'd0;
                        error <= 1'b1;
                    end else if (base_cost_swerc == 16'hFFFF) begin
                        // Only full graph has path, SWERC never better
                        // Return 0 (impossible to favor SWERC)
                        result <= 32'd0;
                        error <= 1'b0;
                    end else if (base_cost_all == 16'hFFFF) begin
                        // Only SWERC has path, always better
                        // Return Infinity
                        result <= 32'h7FFFFFFF;
                        error <= 1'b0;
                    end else begin
                        // Both have paths, return T_low (scaled to 8-bit)
                        // T_low is scaled by 256, we want integer result
                        // Round up: (T_low + 255) / 256
                        reg [15:0] t_result;
                        t_result = (T_low + 16'd255) >> 8;
                        result <= {16'd0, t_result};
                        error <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                ERROR_STATE: begin
                    result <= 32'd0;
                    error <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule