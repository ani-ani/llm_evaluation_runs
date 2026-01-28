module book_circle_min_presentations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_boys,
    input wire [3:0] num_girls,
    input wire [191:0] book_edges,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] POPULATE_MATRIX = 3'd1;
    localparam [2:0] FIND_COMPONENTS = 3'd2;
    localparam [2:0] BFS_TRAVERSE = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state, next_state;

    // Adjacency matrix (16x16)
    reg [15:0] adjacency_matrix [0:15];

    // Visited array
    reg [15:0] visited;

    // BFS queue
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] queue_size;

    // Component counting
    reg [7:0] component_count;
    reg [3:0] current_node;
    reg [3:0] node_counter;
    reg [3:0] edge_counter;

    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Initialize adjacency matrix
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            cycle_count <= 10'd0;

            // Reset adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adjacency_matrix[i] <= 16'd0;
            end

            // Reset visited array
            visited <= 16'd0;

            // Reset queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_size <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                queue[i] <= 4'd0;
            end

            // Reset counters
            component_count <= 8'd0;
            current_node <= 4'd0;
            node_counter <= 4'd0;
            edge_counter <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= POPULATE_MATRIX;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                POPULATE_MATRIX: begin
                    // Populate adjacency matrix from book_edges
                    if (edge_counter < 24) begin
                        // Extract source (boy) and destination (girl)
                        reg [3:0] src = book_edges[edge_counter * 8 + 7 : edge_counter * 8];
                        reg [3:0] dst = book_edges[edge_counter * 8 + 15 : edge_counter * 8 + 8];
                        // Set adjacency matrix (only if within bounds)
                        if (src < num_boys && dst < num_girls) begin
                            adjacency_matrix[src][dst] <= 1'b1;
                            adjacency_matrix[dst + 8'd8][src + 8'd8] <= 1'b1; // Bipartite connection
                        end
                        edge_counter <= edge_counter + 4'd1;
                    end else begin
                        edge_counter <= 4'd0;
                        next_state <= FIND_COMPONENTS;
                    end
                end

                FIND_COMPONENTS: begin
                    // Iterate through all nodes
                    if (node_counter < (num_boys + num_girls)) begin
                        if (!visited[node_counter]) begin
                            // Found new component
                            component_count <= component_count + 8'd1;
                            // Start BFS from this node
                            current_node <= node_counter;
                            next_state <= BFS_TRAVERSE;
                            // Initialize queue
                            queue_head <= 4'd0;
                            queue_tail <= 4'd0;
                            queue_size <= 4'd0;
                            // Mark current node as visited
                            visited[node_counter] <= 1'b1;
                            // Enqueue current node
                            queue[queue_tail] <= node_counter;
                            queue_tail <= queue_tail + 4'd1;
                            queue_size <= queue_size + 4'd1;
                        end else begin
                            node_counter <= node_counter + 4'd1;
                        end
                    end else begin
                        next_state <= FINISHED;
                    end
                end

                BFS_TRAVERSE: begin
                    // Process queue
                    if (queue_size > 4'd0) begin
                        // Dequeue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_size <= queue_size - 4'd1;

                        // Visit all neighbors
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adjacency_matrix[current_node][i] && !visited[i]) begin
                                visited[i] <= 1'b1;
                                // Enqueue
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                                queue_size <= queue_size + 4'd1;
                            end
                        end
                    end else begin
                        // BFS complete, return to FIND_COMPONENTS
                        next_state <= FIND_COMPONENTS;
                        node_counter <= node_counter + 4'd1;
                    end
                end

                FINISHED: begin
                    result <= component_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Cycle counter for safety
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 10'd1;
            end else begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule