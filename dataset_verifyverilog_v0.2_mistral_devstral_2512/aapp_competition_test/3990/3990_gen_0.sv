module shortest_path_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] num_edges,
    input [23:0] edge_data,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        BUILD_GRAPH,
        BFS_INIT,
        BFS_PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Adjacency matrix (8x8)
    reg [7:0] adj_matrix [0:7];

    // BFS variables
    reg [7:0] visited;
    reg [2:0] queue [0:7];
    reg [2:0] queue_head, queue_tail;
    reg [3:0] current_distance;
    reg [2:0] current_node;
    reg [2:0] target_node;
    reg use_complement;

    // Edge parsing
    reg [2:0] edge_list_u [0:3];
    reg [2:0] edge_list_v [0:3];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
            end
            BUILD_GRAPH: next_state = BFS_INIT;
            BFS_INIT: next_state = BFS_PROCESSING;
            BFS_PROCESSING: begin
                if (queue_head == queue_tail) begin
                    if (visited[target_node]) begin
                        next_state = DONE;
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            DONE: begin
                if (start) next_state = BUILD_GRAPH;
            end
            default: next_state = IDLE;
        endcase
    end

    // Build graph from edge data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset adjacency matrix
            for (int i = 0; i < 8; i++) begin
                adj_matrix[i] <= 0;
            end
            // Reset edge list
            for (int i = 0; i < 4; i++) begin
                edge_list_u[i] <= 0;
                edge_list_v[i] <= 0;
            end
        end else if (current_state == BUILD_GRAPH) begin
            // Parse edge data
            for (int i = 0; i < 4; i++) begin
                edge_list_u[i] <= edge_data[3*i+2:3*i];
                edge_list_v[i] <= edge_data[3*i+5:3*i+3];
            end
            // Build adjacency matrix
            for (int i = 0; i < 8; i++) begin
                adj_matrix[i] <= 0;
            end
            for (int i = 0; i < num_edges; i++) begin
                reg [2:0] u = edge_list_u[i];
                reg [2:0] v = edge_list_v[i];
                adj_matrix[u][v] <= 1;
                adj_matrix[v][u] <= 1;
            end
            // Check direct connection between town 1 (0) and town n (n-1)
            use_complement <= (adj_matrix[0][n-1] == 0);
        end
    end

    // BFS initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            visited <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            current_distance <= 0;
            current_node <= 0;
            target_node <= n-1;
        end else if (current_state == BFS_INIT) begin
            visited <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            current_distance <= 0;
            current_node <= 0;
            target_node <= n-1;
            // Initialize queue with starting node
            queue[0] <= 0;
            queue_tail <= 1;
            visited[0] <= 1;
        end
    end

    // BFS processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset result
            result <= 0;
        end else if (current_state == BFS_PROCESSING) begin
            if (queue_head != queue_tail) begin
                current_node <= queue[queue_head];
                queue_head <= queue_head + 1;
                
                // Check if current node is target
                if (current_node == target_node) begin
                    result <= current_distance;
                end else begin
                    // Explore neighbors
                    for (int i = 0; i < n; i++) begin
                        reg should_visit;
                        if (use_complement) begin
                            // Use complement graph (roads)
                            should_visit = (adj_matrix[current_node][i] == 0) && (current_node != i);
                        end else begin
                            // Use original graph (railways)
                            should_visit = adj_matrix[current_node][i];
                        end
                        
                        if (should_visit && !visited[i]) begin
                            visited[i] <= 1;
                            queue[queue_tail] <= i;
                            queue_tail <= queue_tail + 1;
                        end
                    end
                    current_distance <= current_distance + 1;
                end
            end else begin
                // Queue is empty, check if target was reached
                if (!visited[target_node]) begin
                    result <= 15; // Unreachable
                end
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else if (start) begin
            done <= 0;
        end
    end

endmodule