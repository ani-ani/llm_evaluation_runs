module train_bus_min_time(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] m_in,
    input [3:0] edge_u,
    input [3:0] edge_v,
    input edge_valid,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_EDGES  = 3'd1;
    localparam [2:0] SETUP_BFS   = 3'd2;
    localparam [2:0] BFS_POP     = 3'd3;
    localparam [2:0] BFS_VISIT   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    reg [2:0] state, next_state;

    // Registers for inputs
    reg [3:0] n_reg;
    reg [3:0] m_reg;
    reg [3:0] m_count;
    
    // Rail adjacency matrix: rail_mat[u][v]
    reg [15:0] rail_mat [15:0];
    integer i, j;

    // BFS registers
    reg [7:0] dist [15:0]; // Distance storage
    reg [3:0] queue [15:0]; // FIFO array
    reg [3:0] q_head, q_tail, q_size;
    reg [3:0] current_node;
    reg [3:0] neighbor_idx;
    reg [7:0] max_dist;
    
    // Graph selection
    reg use_roads; // 0: Railways, 1: Roads
    reg [7:0] final_dist;

    // Helper signals
    wire connect;
    assign connect = use_roads ? ~rail_mat[current_node][neighbor_idx] : rail_mat[current_node][neighbor_idx];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            m_reg <= 4'd0;
            m_count <= 4'd0;
            use_roads <= 1'b0;
            final_dist <= 8'd0;
            // Reset matrix
            for (i = 0; i < 16; i = i + 1) begin
                rail_mat[i] <= 16'd0;
            end
            // Reset BFS vars
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd0;
                queue[i] <= 4'd0;
            end
            q_head <= 4'd0;
            q_tail <= 4'd0;
            q_size <= 4'd0;
            current_node <= 4'd0;
            neighbor_idx <= 4'd0;
            max_dist <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        m_reg <= m_in;
                        m_count <= 4'd0;
                        // Clear matrix for new input size (conceptually, though reset handles all)
                        for (i = 0; i < 16; i = i + 1) begin
                            rail_mat[i] <= 16'd0;
                        end
                        state <= LOAD_EDGES;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_valid && (m_count < m_reg)) begin
                        // Set bidirectional edge (0-indexed)
                        rail_mat[edge_u][edge_v] <= 1'b1;
                        rail_mat[edge_v][edge_u] <= 1'b1;
                        m_count <= m_count + 4'd1;
                    end
                    if (m_count == m_reg) begin
                        state <= SETUP_BFS;
                    end
                end

                SETUP_BFS: begin
                    // Check direct rail connection (0 to n-1)
                    if (rail_mat[0][n_reg - 4'd1]) begin
                        use_roads <= 1'b1;
                    end else begin
                        use_roads <= 1'b0;
                    end
                    
                    // Reset Distances
                    for (i = 0; i < 16; i = i + 1) begin
                        dist[i] <= 8'hFF;
                    end
                    
                    // Initialize Queue
                    q_head <= 4'd0;
                    q_tail <= 4'd0;
                    q_size <= 4'd0;
                    
                    // Push 0
                    queue[0] <= 4'd0;
                    dist[0] <= 8'd0;
                    q_tail <= 4'd1;
                    q_size <= 4'd1;
                    
                    neighbor_idx <= 4'd0;
                    max_dist <= 8'd0;
                    
                    state <= BFS_POP;
                end

                BFS_POP: begin
                    if (q_size > 4'd0) begin
                        // Pop from head
                        current_node <= queue[q_head];
                        q_head <= q_head + 4'd1;
                        q_size <= q_size - 4'd1;
                        neighbor_idx <= 4'd0; // Start checking neighbors
                        state <= BFS_VISIT;
                    end else begin
                        // Queue empty, finished
                        state <= FINISH;
                    end
                end

                BFS_VISIT: begin
                    // If we reached destination n-1, finish
                    if (current_node == (n_reg - 4'd1)) begin
                        state <= FINISH;
                    end else if (neighbor_idx < n_reg) begin
                        // Check if neighbor is valid
                        if (connect) begin
                            if (dist[neighbor_idx] == 8'hFF) begin
                                // Found new path
                                dist[neighbor_idx] <= dist[current_node] + 8'd1;
                                // Push to queue
                                if (q_size < 4'd16) begin
                                    queue[q_tail] <= neighbor_idx;
                                    q_tail <= q_tail + 4'd1;
                                    q_size <= q_size + 4'd1;
                                end
                                if (neighbor_idx == (n_reg - 4'd1)) begin
                                    // Early exit optimization
                                    state <= FINISH;
                                    final_dist <= dist[current_node] + 8'd1;
                                end
                            end
                        end
                        neighbor_idx <= neighbor_idx + 4'd1;
                    end else begin
                        state <= BFS_POP;
                    end
                end

                FINISH: begin
                    if (final_dist == 8'd0 && dist[n_reg - 4'd1] != 8'hFF) begin
                         // If we found it during BFS_POP or uninitialized final_dist, use dist array
                         result <= dist[n_reg - 4'd1];
                    end else if (final_dist != 8'd0) begin
                         // Early exit value
                         result <= final_dist;
                    end else begin
                         // Unreachable
                         result <= 8'hFF;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule