module disco_cyber_security (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [4:0] num_edges,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [3:0] num_remove,
    output reg [3:0] remove_indices [0:7],
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CHECK_CYCLE,
        REMOVE_EDGE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] edge_index;
    reg [3:0] remove_count;
    reg [3:0] remove_list [0:7];
    reg [7:0] adjacency [0:7]; // 8x8 adjacency matrix
    reg [3:0] path [0:7]; // For cycle detection
    reg [3:0] path_len;
    reg cycle_detected;

    // Initialize all outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            num_remove <= 0;
            done <= 0;
            edge_index <= 0;
            remove_count <= 0;
            for (int i = 0; i < 8; i++) begin
                remove_indices[i] <= 0;
                remove_list[i] <= 0;
                adjacency[i] <= 0;
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
                    next_state = CHECK_CYCLE;
                    // Initialize adjacency matrix
                    for (int i = 0; i < 8; i++) adjacency[i] = 0;
                    for (int i = 0; i < num_edges; i++) begin
                        if (edge_u[i] > 0 && edge_v[i] > 0) begin
                            adjacency[edge_u[i]-1][edge_v[i]-1] = 1;
                        end
                    end
                    edge_index = 0;
                    remove_count = 0;
                    for (int i = 0; i < 8; i++) remove_list[i] = 0;
                end
            end

            CHECK_CYCLE: begin
                if (edge_index < num_edges) begin
                    // Check if current edge creates a cycle
                    cycle_detected = check_cycle(edge_u[edge_index], edge_v[edge_index]);
                    if (cycle_detected && remove_count < (num_edges >> 1)) begin
                        next_state = REMOVE_EDGE;
                    end else begin
                        edge_index = edge_index + 1;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            REMOVE_EDGE: begin
                // Add current edge to removal list
                remove_list[remove_count] = edge_index + 1;
                remove_count = remove_count + 1;
                // Remove edge from adjacency matrix
                adjacency[edge_u[edge_index]-1][edge_v[edge_index]-1] = 0;
                edge_index = edge_index + 1;
                next_state = CHECK_CYCLE;
            end

            DONE: begin
                // Output results
                num_remove = remove_count;
                for (int i = 0; i < 8; i++) begin
                    if (i < remove_count) begin
                        remove_indices[i] = remove_list[i];
                    end else begin
                        remove_indices[i] = 0;
                    end
                end
                done = 1;
                next_state = IDLE;
            end
        endcase
    end

    // Cycle detection function
    function logic check_cycle(input [3:0] u, input [3:0] v);
        logic has_cycle;
        integer i, j;

        // Check if there's a path from v back to u
        has_cycle = 0;
        for (i = 0; i < 8; i++) path[i] = 0;
        path_len = 0;

        // Start DFS from v
        if (dfs(v, u, 0)) begin
            has_cycle = 1;
        end

        check_cycle = has_cycle;
    endfunction

    // Depth-first search function
    function logic dfs(input [3:0] current, input [3:0] target, input [3:0] depth);
        logic found;
        integer i;

        found = 0;
        if (depth > 7) return 0;

        // Check if we've reached the target
        if (current == target) begin
            found = 1;
            return 1;
        end

        // Mark current node as visited
        path[depth] = current;

        // Explore neighbors
        for (i = 0; i < 8; i++) begin
            if (adjacency[current-1][i] && !is_in_path(i+1, depth)) begin
                if (dfs(i+1, target, depth+1)) begin
                    found = 1;
                    break;
                end
            end
        end

        return found;
    endfunction

    // Check if node is in current path
    function logic is_in_path(input [3:0] node, input [3:0] depth);
        logic in_path;
        integer i;

        in_path = 0;
        for (i = 0; i <= depth; i++) begin
            if (path[i] == node) begin
                in_path = 1;
                break;
            end
        end

        return in_path;
    endfunction

endmodule