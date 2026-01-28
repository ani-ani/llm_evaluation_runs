module count_unicyclic_subgraphs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] V,
    input wire [3:0] E,
    input wire [15:0] edge_mask,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'h3B9ACA07;
    localparam [4:0] MAX_V = 5'd8;
    localparam [4:0] MAX_SUBSETS = 5'd16; // 2^16 subsets
    
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_DEG  = 3'd1;
    localparam [2:0] CHECK_CONN = 3'd2;
    localparam [2:0] CHECK_CYCLE = 3'd3;
    localparam [2:0] INCREMENT  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    // Registers
    reg [2:0] state, next_state;
    reg [31:0] count_reg;
    reg [15:0] subset_idx;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'h01000000; // 16M cycles timeout
    
    // Temporary storage for vertex processing
    reg [4:0] vertex_idx; // 0-7
    reg [3:0] edge_idx;   // 0-15
    reg [2:0] active_edges; // count edges in subset
    reg [7:0] degree_sum;   // sum of degrees in subset
    reg [7:0] visited;      // for BFS
    reg [7:0] queue [0:7]; // BFS queue
    reg [3:0] queue_head, queue_tail;
    reg [7:0] neighbors;
    reg [3:0] neighbor_idx;
    
    // Edge to vertex mapping
    // edge 0: (0,1), edge 1: (0,2), edge 2: (1,2), edge 3: (0,3)
    // edge 4: (1,3), edge 5: (2,3), edge 6: (0,4), edge 7: (1,4)
    // edge 8: (2,4), edge 9: (3,4), edge 10: (0,5), edge 11: (1,5)
    // edge 12: (2,5), edge 13: (3,5), edge 14: (4,5), edge 15: (0,6)
    // edge 16: (1,6), edge 17: (2,6), edge 18: (3,6), edge 19: (4,6)
    // edge 20: (5,6), edge 21: (0,7), edge 22: (1,7), edge 23: (2,7)
    // edge 24: (3,7), edge 25: (4,7), edge 26: (5,7), edge 27: (6,7)
    
    // Edge source/destination arrays (only for edges <= 15 in this design)
    reg [2:0] src_edge [0:15];
    reg [2:0] dst_edge [0:15];
    
    // Initialize edge mapping
    always @(*) begin
        src_edge[0] = 3'd0; dst_edge[0] = 3'd1;
        src_edge[1] = 3'd0; dst_edge[1] = 3'd2;
        src_edge[2] = 3'd1; dst_edge[2] = 3'd2;
        src_edge[3] = 3'd0; dst_edge[3] = 3'd3;
        src_edge[4] = 3'd1; dst_edge[4] = 3'd3;
        src_edge[5] = 3'd2; dst_edge[5] = 3'd3;
        src_edge[6] = 3'd0; dst_edge[6] = 3'd4;
        src_edge[7] = 3'd1; dst_edge[7] = 3'd4;
        src_edge[8] = 3'd2; dst_edge[8] = 3'd4;
        src_edge[9] = 3'd3; dst_edge[9] = 3'd4;
        src_edge[10] = 3'd0; dst_edge[10] = 3'd5;
        src_edge[11] = 3'd1; dst_edge[11] = 3'd5;
        src_edge[12] = 3'd2; dst_edge[12] = 3'd5;
        src_edge[13] = 3'd3; dst_edge[13] = 3'd5;
        src_edge[14] = 3'd4; dst_edge[14] = 3'd5;
        src_edge[15] = 3'd0; dst_edge[15] = 3'd6;
    end
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_reg <= 32'd0;
            subset_idx <= 16'd0;
            cycle_count <= 32'd0;
            done <= 1'b0;
            result <= 32'd0;
            vertex_idx <= 5'd0;
            edge_idx <= 4'd0;
            active_edges <= 3'd0;
            degree_sum <= 8'd0;
            visited <= 8'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            neighbors <= 8'd0;
            neighbor_idx <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 32'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count_reg <= 32'd0;
                        subset_idx <= 16'd0;
                        cycle_count <= 32'd0;
                    end
                end
                
                CHECK_DEG: begin
                    if (vertex_idx < V) begin
                        // Calculate degree for this vertex in current subset
                        if (edge_idx < E) begin
                            if (edge_mask[edge_idx]) begin
                                // Check if this edge is in subset
                                if (subset_idx[edge_idx]) begin
                                    // Check if vertex is involved in this edge
                                    if (src_edge[edge_idx] == vertex_idx[2:0] || dst_edge[edge_idx] == vertex_idx[2:0]) begin
                                        degree_sum <= degree_sum + 8'd1;
                                    end
                                end
                            end
                        end
                        edge_idx <= edge_idx + 4'd1;
                        if (edge_idx == E - 4'd1) begin
                            // End of edge check for this vertex
                            if (degree_sum == 8'd0) begin
                                // Vertex isolated - not spanning
                                state <= INCREMENT;
                            end else begin
                                // Vertex has degree > 0, check next vertex
                                vertex_idx <= vertex_idx + 5'd1;
                                edge_idx <= 4'd0;
                                degree_sum <= 8'd0;
                                if (vertex_idx == V - 5'd1) begin
                                    // All vertices checked, now check connectivity
                                    state <= CHECK_CONN;
                                    vertex_idx <= 5'd0;
                                    // Find first vertex with degree > 0 as start for BFS
                                    // We'll just start from vertex 0 (it has degree > 0 if spanning)
                                    visited <= 8'd1; // Start from vertex 0
                                    queue[0] <= 8'd0;
                                    queue_head <= 4'd0;
                                    queue_tail <= 4'd1;
                                end
                            end
                        end
                    end
                end
                
                CHECK_CONN: begin
                    if (queue_head < queue_tail) begin
                        // Dequeue
                        reg [7:0] current_v;
                        current_v = queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        
                        // Find neighbors of current_v
                        neighbor_idx <= 4'd0;
                        // For BFS, we need to check all edges in subset
                        if (neighbor_idx < E) begin
                            if (edge_mask[neighbor_idx] && subset_idx[neighbor_idx]) begin
                                if (src_edge[neighbor_idx] == current_v[2:0]) begin
                                    if (!visited[dst_edge[neighbor_idx]]) begin
                                        visited[dst_edge[neighbor_idx]] <= 1'b1;
                                        queue[queue_tail] <= {5'd0, dst_edge[neighbor_idx]};
                                        queue_tail <= queue_tail + 4'd1;
                                    end
                                end else if (dst_edge[neighbor_idx] == current_v[2:0]) begin
                                    if (!visited[src_edge[neighbor_idx]]) begin
                                        visited[src_edge[neighbor_idx]] <= 1'b1;
                                        queue[queue_tail] <= {5'd0, src_edge[neighbor_idx]};
                                        queue_tail <= queue_tail + 4'd1;
                                    end
                                end
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end
                    end else begin
                        // BFS done, check if all vertices visited
                        // Count set bits in visited (up to V vertices)
                        reg [3:0] visited_count;
                        visited_count = 4'd0;
                        if (visited[0] && 0 < V) visited_count = visited_count + 4'd1;
                        if (visited[1] && 1 < V) visited_count = visited_count + 4'd1;
                        if (visited[2] && 2 < V) visited_count = visited_count + 4'd1;
                        if (visited[3] && 3 < V) visited_count = visited_count + 4'd1;
                        if (visited[4] && 4 < V) visited_count = visited_count + 4'd1;
                        if (visited[5] && 5 < V) visited_count = visited_count + 4'd1;
                        if (visited[6] && 6 < V) visited_count = visited_count + 4'd1;
                        if (visited[7] && 7 < V) visited_count = visited_count + 4'd1;
                        
                        if (visited_count != V) begin
                            // Not connected
                            state <= INCREMENT;
                        end else begin
                            // Connected, now check cycle condition
                            state <= CHECK_CYCLE;
                            active_edges <= 3'd0;
                        end
                    end
                end
                
                CHECK_CYCLE: begin
                    // Count edges in subset
                    if (edge_idx < E) begin
                        if (edge_mask[edge_idx] && subset_idx[edge_idx]) begin
                            active_edges <= active_edges + 3'd1;
                        end
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        // Check if edges == V (unicyclic condition)
                        if (active_edges == V[2:0]) begin
                            // Valid unicyclic subgraph
                            count_reg <= count_reg + 32'd1;
                            if (count_reg >= MOD) begin
                                count_reg <= count_reg - MOD;
                            end
                        end
                        state <= INCREMENT;
                    end
                end
                
                INCREMENT: begin
                    // Reset temporary registers for next subset
                    vertex_idx <= 5'd0;
                    edge_idx <= 4'd0;
                    active_edges <= 3'd0;
                    degree_sum <= 8'd0;
                    visited <= 8'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    neighbors <= 8'd0;
                    neighbor_idx <= 4'd0;
                    
                    // Increment subset index
                    subset_idx <= subset_idx + 16'd1;
                    
                    // Check if done with all subsets
                    // (1 << E) = 2^E subsets
                    if (subset_idx == ((1 << E) - 16'd1)) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= CHECK_DEG;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= count_reg;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
                result <= 32'hDEADBEEF; // Error indication
            end
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_DEG;
            end
            
            CHECK_DEG: begin
                // Handled in sequential logic
            end
            
            CHECK_CONN: begin
                // Handled in sequential logic
            end
            
            CHECK_CYCLE: begin
                // Handled in sequential logic
            end
            
            INCREMENT: begin
                next_state = CHECK_DEG;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule