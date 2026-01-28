module euler_animal_check(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [15:0][3:0] src,
    input [15:0][3:0] dst,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_EDGES = 3'd1;
    localparam [2:0] CHECK_DEGREES = 3'd2;
    localparam [2:0] CHECK_CONNECTIVITY = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Degree registers (4-bit each, 0..15)
    reg [3:0] indegree [0:7];
    reg [3:0] outdegree [0:7];

    // Adjacency matrix (8x8)
    reg adjacency [0:7][0:7];

    // BFS variables
    reg [2:0] bfs_queue [0:7];
    reg [2:0] queue_head, queue_tail;
    reg [2:0] current_node;
    reg [2:0] visited [0:7];
    reg [2:0] node_counter;
    reg [2:0] edge_counter;
    reg [2:0] start_count, end_count;
    reg [2:0] non_zero_degree_count;
    reg [2:0] reachable_count;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize degrees
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                indegree[i] <= 4'd0;
                outdegree[i] <= 4'd0;
            end

            // Initialize adjacency matrix
            integer j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adjacency[i][j] <= 1'b0;
                end
            end

            // Initialize BFS variables
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            current_node <= 3'd0;
            node_counter <= 3'd0;
            edge_counter <= 3'd0;
            start_count <= 3'd0;
            end_count <= 3'd0;
            non_zero_degree_count <= 3'd0;
            reachable_count <= 3'd0;

            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 1'b0;
                bfs_queue[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS_EDGES;
                        edge_counter <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS_EDGES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (edge_counter < m) begin
                        // Process current edge
                        reg [3:0] s = src[edge_counter];
                        reg [3:0] d = dst[edge_counter];
                        
                        // Update degrees
                        outdegree[s] <= outdegree[s] + 4'd1;
                        indegree[d] <= indegree[d] + 4'd1;
                        
                        // Update adjacency matrix (undirected)
                        adjacency[s][d] <= 1'b1;
                        adjacency[d][s] <= 1'b1;
                        
                        edge_counter <= edge_counter + 3'd1;
                        next_state <= PROCESS_EDGES;
                    end else begin
                        next_state <= CHECK_DEGREES;
                        node_counter <= 3'd0;
                        start_count <= 3'd0;
                        end_count <= 3'd0;
                        non_zero_degree_count <= 3'd0;
                    end
                end

                CHECK_DEGREES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (node_counter < n) begin
                        reg [3:0] diff = outdegree[node_counter] - indegree[node_counter];
                        
                        if (diff == 4'd1) begin
                            start_count <= start_count + 3'd1;
                        end else if (diff == 4'd255) begin // -1 in 4-bit two's complement
                            end_count <= end_count + 3'd1;
                        end else if (diff != 4'd0) begin
                            // Invalid degree difference
                            result <= 2'd2; // IMPOSSIBLE
                            next_state <= DONE_STATE;
                        end
                        
                        if (outdegree[node_counter] != 4'd0 || indegree[node_counter] != 4'd0) begin
                            non_zero_degree_count <= non_zero_degree_count + 3'd1;
                        end
                        
                        node_counter <= node_counter + 3'd1;
                        next_state <= CHECK_DEGREES;
                    end else begin
                        // Check degree conditions
                        if ((start_count > 3'd1) || (end_count > 3'd1)) begin
                            result <= 2'd2; // IMPOSSIBLE
                            next_state <= DONE_STATE;
                        end else if (m == 5'd0) begin
                            result <= 2'd0; // FALSE ALARM
                            next_state <= DONE_STATE;
                        end else begin
                            // Initialize BFS
                            node_counter <= 3'd0;
                            queue_head <= 3'd0;
                            queue_tail <= 3'd0;
                            reachable_count <= 3'd0;
                            
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                visited[i] <= 1'b0;
                            end
                            
                            next_state <= CHECK_CONNECTIVITY;
                        end
                    end
                end

                CHECK_CONNECTIVITY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find first node with non-zero degree to start BFS
                    if (node_counter < n) begin
                        if ((outdegree[node_counter] != 4'd0 || indegree[node_counter] != 4'd0) && !visited[node_counter]) begin
                            // Initialize BFS queue
                            bfs_queue[queue_tail] <= node_counter;
                            queue_tail <= queue_tail + 3'd1;
                            visited[node_counter] <= 1'b1;
                            reachable_count <= reachable_count + 3'd1;
                            next_state <= CHECK_CONNECTIVITY;
                        end else begin
                            node_counter <= node_counter + 3'd1;
                            next_state <= CHECK_CONNECTIVITY;
                        end
                    end else if (queue_head < queue_tail) begin
                        // Process BFS queue
                        current_node <= bfs_queue[queue_head];
                        queue_head <= queue_head + 3'd1;
                        
                        // Visit all neighbors
                        integer i;
                        for (i = 0; i < n; i = i + 1) begin
                            if (adjacency[current_node][i] && !visited[i]) begin
                                bfs_queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 3'd1;
                                visited[i] <= 1'b1;
                                reachable_count <= reachable_count + 3'd1;
                            end
                        end
                        
                        next_state <= CHECK_CONNECTIVITY;
                    end else begin
                        // Check if all non-zero degree nodes are reachable
                        if (reachable_count == non_zero_degree_count) begin
                            result <= 2'd1; // POSSIBLE
                        end else begin
                            result <= 2'd2; // IMPOSSIBLE
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule