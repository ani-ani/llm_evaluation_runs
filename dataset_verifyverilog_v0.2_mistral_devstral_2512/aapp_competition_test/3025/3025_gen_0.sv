module bandit_gold_max (
    input clk,
    input rst_n,
    input start,
    input [7:0] gold_i,
    input [2:0] gold_idx,
    input [7:0] adj_matrix [8:0][8:0],
    output reg [15:0] max_gold,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        INIT_GOLD,
        BUILD_MATRIX,
        BFS_DIST,
        FIND_PATHS,
        CHECK_RETURN,
        UPDATE_MAX,
        DONE
    } state_t;

    state_t state, next_state;

    // Gold storage for nodes 3-8 (index 1-6 corresponds to node 3-8)
    reg [7:0] gold [8:0];
    reg [2:0] gold_count;

    // Adjacency matrix storage (1-8)
    reg [7:0] adj [8:0][8:0];

    // BFS variables
    reg [2:0] distance [8:0];
    reg [2:0] current_node;
    reg [2:0] queue [8:0];
    reg [2:0] queue_head, queue_tail;
    reg [2:0] shortest_dist;

    // Path tracking
    reg [2:0] path [8:0];
    reg [2:0] path_length;
    reg [2:0] path_index;
    reg [15:0] current_gold;
    reg [2:0] robbed_nodes [8:0];
    reg [2:0] robbed_count;

    // Return path check
    reg [2:0] return_queue [8:0];
    reg [2:0] return_head, return_tail;
    reg [7:0] visited [8:0];
    reg return_found;

    // Control signals
    reg gold_stored;
    reg matrix_built;
    reg bfs_done;
    reg paths_enumerated;
    reg max_updated;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_gold <= 0;
            done <= 0;
            valid <= 0;
            gold_count <= 0;
            gold_stored <= 0;
            matrix_built <= 0;
            bfs_done <= 0;
            paths_enumerated <= 0;
            max_updated <= 0;
            current_node <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            path_length <= 0;
            path_index <= 0;
            current_gold <= 0;
            robbed_count <= 0;
            return_head <= 0;
            return_tail <= 0;
            return_found <= 0;

            // Initialize arrays
            for (int i = 1; i <= 8; i++) begin
                gold[i] <= 0;
                distance[i] <= 8'hFF;
                for (int j = 1; j <= 8; j++) begin
                    adj[i][j] <= 0;
                end
            end

            for (int i = 0; i < 8; i++) begin
                queue[i] <= 0;
                path[i] <= 0;
                robbed_nodes[i] <= 0;
                return_queue[i] <= 0;
                visited[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_GOLD;
                    gold_stored = 0;
                    matrix_built = 0;
                    bfs_done = 0;
                    paths_enumerated = 0;
                    max_updated = 0;
                    done = 0;
                    valid = 0;
                    gold_count = 0;
                end
            end

            INIT_GOLD: begin
                if (gold_count == 6) begin
                    gold_stored = 1;
                    next_state = BUILD_MATRIX;
                end
            end

            BUILD_MATRIX: begin
                if (matrix_built) begin
                    next_state = BFS_DIST;
                end
            end

            BFS_DIST: begin
                if (bfs_done) begin
                    next_state = FIND_PATHS;
                end
            end

            FIND_PATHS: begin
                if (paths_enumerated) begin
                    next_state = CHECK_RETURN;
                end
            end

            CHECK_RETURN: begin
                if (return_found) begin
                    next_state = UPDATE_MAX;
                end else begin
                    next_state = FIND_PATHS;
                end
            end

            UPDATE_MAX: begin
                if (max_updated) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1;
                valid = 1;
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Store gold values
    always @(posedge clk) begin
        if (state == INIT_GOLD && gold_idx != 0) begin
            gold[gold_idx + 2] <= gold_i;
            gold_count <= gold_count + 1;
        end
    end

    // Build adjacency matrix
    always @(posedge clk) begin
        if (state == BUILD_MATRIX && !matrix_built) begin
            for (int i = 1; i <= 8; i++) begin
                for (int j = 1; j <= 8; j++) begin
                    adj[i][j] <= adj_matrix[i][j];
                end
            end
            matrix_built <= 1;
        end
    end

    // BFS to find shortest distance from node 1 to node 2
    always @(posedge clk) begin
        if (state == BFS_DIST && !bfs_done) begin
            // Initialize BFS
            if (queue_head == 0 && queue_tail == 0) begin
                distance[1] <= 0;
                queue[queue_tail] <= 1;
                queue_tail <= queue_tail + 1;
            end

            // Process queue
            if (queue_head < queue_tail) begin
                current_node <= queue[queue_head];
                queue_head <= queue_head + 1;

                // Explore neighbors
                for (int i = 1; i <= 8; i++) begin
                    if (adj[current_node][i] && distance[i] == 8'hFF) begin
                        distance[i] <= distance[current_node] + 1;
                        queue[queue_tail] <= i;
                        queue_tail <= queue_tail + 1;
                    end
                end
            end

            // Check if done
            if (queue_head >= queue_tail) begin
                shortest_dist <= distance[2];
                bfs_done <= 1;
            end
        end
    end

    // Enumerate all shortest paths
    always @(posedge clk) begin
        if (state == FIND_PATHS && !paths_enumerated) begin
            // Initialize path
            if (path_index == 0) begin
                path[0] <= 1;
                path_length <= 1;
                path_index <= 1;
                current_gold <= 0;
                robbed_count <= 0;

                // Add gold from node 1 (none)
                if (path[0] >= 3 && path[0] <= 8) begin
                    current_gold <= current_gold + gold[path[0]];
                    robbed_nodes[robbed_count] <= path[0];
                    robbed_count <= robbed_count + 1;
                end
            end

            // Extend path
            if (path_length < shortest_dist) begin
                for (int i = 1; i <= 8; i++) begin
                    if (adj[path[path_length - 1]][i] && 
                        (path_length == 1 || i != path[path_length - 2])) begin
                        path[path_length] <= i;
                        path_length <= path_length + 1;

                        // Add gold if node is 3-8
                        if (i >= 3 && i <= 8) begin
                            current_gold <= current_gold + gold[i];
                            robbed_nodes[robbed_count] <= i;
                            robbed_count <= robbed_count + 1;
                        end

                        // Check if path is complete
                        if (i == 2 && path_length == shortest_dist) begin
                            paths_enumerated <= 1;
                        end
                    end
                end
            end
        end
    end

    // Check return path
    always @(posedge clk) begin
        if (state == CHECK_RETURN) begin
            // Initialize return BFS
            if (return_head == 0 && return_tail == 0) begin
                return_queue[return_tail] <= 2;
                return_tail <= return_tail + 1;
                visited[2] <= 1;
            end

            // Process return queue
            if (return_head < return_tail) begin
                current_node <= return_queue[return_head];
                return_head <= return_head + 1;

                // Check if reached home
                if (current_node == 1) begin
                    return_found <= 1;
                end

                // Explore neighbors
                for (int i = 1; i <= 8; i++) begin
                    if (adj[current_node][i] && !visited[i] && 
                        (i == 1 || i == 2 || !is_robbed(i, robbed_nodes, robbed_count))) begin
                        visited[i] <= 1;
                        return_queue[return_tail] <= i;
                        return_tail <= return_tail + 1;
                    end
                end
            end

            // Reset if no return path found
            if (return_head >= return_tail && !return_found) begin
                return_head <= 0;
                return_tail <= 0;
                return_found <= 0;
                for (int i = 1; i <= 8; i++) begin
                    visited[i] <= 0;
                end
            end
        end
    end

    // Update maximum gold
    always @(posedge clk) begin
        if (state == UPDATE_MAX && !max_updated) begin
            if (current_gold > max_gold) begin
                max_gold <= current_gold;
            end
            max_updated <= 1;
        end
    end

    // Helper function to check if node is robbed
    function automatic bit is_robbed;
        input [2:0] node;
        input [2:0] robbed [8:0];
        input [2:0] count;
        integer i;
        begin
            is_robbed = 0;
            for (i = 0; i < count; i++) begin
                if (robbed[i] == node) begin
                    is_robbed = 1;
                end
            end
        end
    endfunction

endmodule