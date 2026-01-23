module graph_orientability (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_nodes,
    input [3:0] n_edges,
    input [2:0] edge_u [0:5],
    input [2:0] edge_v [0:5],
    output reg possible,
    output reg [2:0] out_u [0:5],
    output reg [2:0] out_v [0:5],
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        BUILD,
        CHECK_EDGE,
        CONNECTIVITY,
        ANALYZE,
        COMPLETE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [2:0] current_edge;
    reg [2:0] dfs_stack [0:7];
    reg [7:0] stack_ptr;
    reg [3:0] visited;
    reg [3:0] current_node;
    reg [3:0] adj_matrix [0:3];
    reg [3:0] temp_adj_matrix [0:3];
    reg [3:0] node_count;
    reg [3:0] edge_count;
    reg [3:0] reachable_count;
    reg bridge_found;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 0;
            valid <= 0;
            done <= 0;
            current_edge <= 0;
            stack_ptr <= 0;
            visited <= 0;
            current_node <= 0;
            node_count <= 0;
            edge_count <= 0;
            reachable_count <= 0;
            bridge_found <= 0;
            for (int i = 0; i < 4; i++) adj_matrix[i] <= 0;
            for (int i = 0; i < 4; i++) temp_adj_matrix[i] <= 0;
            for (int i = 0; i < 8; i++) dfs_stack[i] <= 0;
            for (int i = 0; i < 6; i++) begin
                out_u[i] <= 0;
                out_v[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = BUILD;
                    node_count = n_nodes;
                    edge_count = n_edges;
                    bridge_found = 0;
                    current_edge = 0;
                end
            end

            BUILD: begin
                // Build adjacency matrix
                for (int i = 0; i < 4; i++) adj_matrix[i] = 0;
                for (int i = 0; i < edge_count; i++) begin
                    int u = edge_u[i] - 1;
                    int v = edge_v[i] - 1;
                    adj_matrix[u] = adj_matrix[u] | (1 << v);
                    adj_matrix[v] = adj_matrix[v] | (1 << u);
                end
                next_state = CHECK_EDGE;
            end

            CHECK_EDGE: begin
                if (current_edge < edge_count) begin
                    // Copy adjacency matrix to temp
                    for (int i = 0; i < 4; i++) temp_adj_matrix[i] = adj_matrix[i];
                    // Remove current edge
                    int u = edge_u[current_edge] - 1;
                    int v = edge_v[current_edge] - 1;
                    temp_adj_matrix[u] = temp_adj_matrix[u] & ~(1 << v);
                    temp_adj_matrix[v] = temp_adj_matrix[v] & ~(1 << u);
                    next_state = CONNECTIVITY;
                end else begin
                    next_state = COMPLETE;
                end
            end

            CONNECTIVITY: begin
                // Initialize DFS
                stack_ptr = 0;
                visited = 0;
                current_node = 0;
                reachable_count = 0;
                dfs_stack[0] = 0;
                next_state = ANALYZE;
            end

            ANALYZE: begin
                // Run DFS
                if (stack_ptr > 0) begin
                    current_node = dfs_stack[stack_ptr - 1];
                    stack_ptr = stack_ptr - 1;
                    if (!(visited & (1 << current_node))) begin
                        visited = visited | (1 << current_node);
                        reachable_count = reachable_count + 1;
                        // Push neighbors
                        for (int i = 0; i < node_count; i++) begin
                            if ((temp_adj_matrix[current_node] & (1 << i)) && !(visited & (1 << i))) begin
                                dfs_stack[stack_ptr] = i;
                                stack_ptr = stack_ptr + 1;
                            end
                        end
                    end
                end else begin
                    // Check if all nodes reachable
                    if (reachable_count != node_count) begin
                        bridge_found = 1;
                    end
                    current_edge = current_edge + 1;
                    next_state = CHECK_EDGE;
                end
            end

            COMPLETE: begin
                possible = !bridge_found;
                valid = 1;
                done = 1;
                // Output original edges if possible
                if (possible) begin
                    for (int i = 0; i < edge_count; i++) begin
                        out_u[i] = edge_u[i];
                        out_v[i] = edge_v[i];
                    end
                end
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule