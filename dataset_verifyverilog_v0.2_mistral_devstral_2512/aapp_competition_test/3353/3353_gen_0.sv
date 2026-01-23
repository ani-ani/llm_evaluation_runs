module river_crossing_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] P,
    input [4:0] num_nodes,
    input [4:0] num_edges,
    input [5:0] edges_src [15:0],
    input [5:0] edges_dst [15:0],
    output reg [15:0] total_time,
    output reg [4:0] people_left,
    output reg done,
    output reg possible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        FIND_PATH,
        UPDATE_GRAPH,
        CHECK_DONE,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] total_time_reg;
    reg [4:0] people_left_reg;
    reg done_reg;
    reg possible_reg;

    // BFS related registers
    reg [5:0] queue [0:7]; // Max 8 nodes
    reg [5:0] queue_head, queue_tail;
    reg [5:0] parent [0:7]; // Parent node for each node
    reg [5:0] path [0:7]; // Current path being processed
    reg [5:0] path_length;
    reg [5:0] current_node;
    reg [5:0] next_node;
    reg [5:0] edge_index;
    reg [5:0] path_index;
    reg [5:0] people_crossed;
    reg [5:0] visited [0:7]; // Visited nodes
    reg [5:0] edge_used [0:15]; // Used edges

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            total_time_reg <= 0;
            people_left_reg <= 0;
            done_reg <= 0;
            possible_reg <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            path_length <= 0;
            current_node <= 0;
            next_node <= 0;
            edge_index <= 0;
            path_index <= 0;
            people_crossed <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                queue[i] <= 0;
                parent[i] <= 0;
                path[i] <= 0;
                visited[i] <= 0;
            end
            for (int i = 0; i < 16; i = i + 1) begin
                edge_used[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                // Initialize BFS structures
                queue_head = 0;
                queue_tail = 0;
                path_length = 0;
                current_node = 0;
                next_node = 0;
                edge_index = 0;
                path_index = 0;
                people_crossed = 0;
                total_time_reg = 0;
                people_left_reg = P;
                done_reg = 0;
                possible_reg = 0;
                for (int i = 0; i < 8; i = i + 1) begin
                    queue[i] = 0;
                    parent[i] = 0;
                    path[i] = 0;
                    visited[i] = 0;
                end
                for (int i = 0; i < 16; i = i + 1) begin
                    edge_used[i] = 0;
                end
                next_state = FIND_PATH;
            end
            FIND_PATH: begin
                // BFS to find shortest path
                if (queue_head == queue_tail) begin
                    // Queue is empty, start BFS from source
                    queue[queue_tail] = 0;
                    queue_tail = queue_tail + 1;
                    visited[0] = 1;
                    parent[0] = 0;
                end else begin
                    current_node = queue[queue_head];
                    queue_head = queue_head + 1;
                    if (current_node == 1) begin
                        // Found path to sink
                        next_state = UPDATE_GRAPH;
                    end else begin
                        // Explore neighbors
                        for (int i = 0; i < num_edges; i = i + 1) begin
                            if (!edge_used[i] && edges_src[i] == current_node) begin
                                next_node = edges_dst[i];
                                if (!visited[next_node]) begin
                                    visited[next_node] = 1;
                                    parent[next_node] = current_node;
                                    queue[queue_tail] = next_node;
                                    queue_tail = queue_tail + 1;
                                end
                            end
                        end
                    end
                end
            end
            UPDATE_GRAPH: begin
                // Reconstruct path and mark edges as used
                path_index = 0;
                current_node = 1;
                while (current_node != 0) begin
                    path[path_index] = current_node;
                    path_index = path_index + 1;
                    current_node = parent[current_node];
                end
                path_length = path_index;
                // Mark edges as used
                for (int i = 0; i < path_length; i = i + 1) begin
                    for (int j = 0; j < num_edges; j = j + 1) begin
                        if (!edge_used[j] && edges_src[j] == path[i+1] && edges_dst[j] == path[i]) begin
                            edge_used[j] = 1;
                        end
                    end
                end
                next_state = CHECK_DONE;
            end
            CHECK_DONE: begin
                people_crossed = people_crossed + 1;
                total_time_reg = total_time_reg + path_length;
                if (people_crossed == P) begin
                    possible_reg = 1;
                    next_state = FINISHED;
                end else begin
                    // Reset BFS structures for next iteration
                    queue_head = 0;
                    queue_tail = 0;
                    for (int i = 0; i < 8; i = i + 1) begin
                        visited[i] = 0;
                        parent[i] = 0;
                    end
                    next_state = FIND_PATH;
                end
            end
            FINISHED: begin
                done_reg = 1;
                people_left_reg = P - people_crossed;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_time <= 0;
            people_left <= 0;
            done <= 0;
            possible <= 0;
        end else begin
            total_time <= total_time_reg;
            people_left <= people_left_reg;
            done <= done_reg;
            possible <= possible_reg;
        end
    end

endmodule